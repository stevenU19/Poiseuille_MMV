#include <cuda_runtime.h>
#include <cstdio>
#include <vector>
#include <cmath>
#include "params.hpp"
#include "timer.hpp"
#include "sph_kernels.hpp"

#ifndef BLOCK_SIZE
#define BLOCK_SIZE 256
#endif
#ifndef YBINS
#define YBINS 64
#endif
#ifndef WRITE_PROFILE
#define WRITE_PROFILE 1
#endif

// SoA
struct Particles {
  float *x, *y, *vx, *vy, *ax, *ay, *rho, *P;
  int   *cellHead, *next;
  int    N, nxCells, nyCells;
  float  cellSize, h, rho0, cs, nu, gx, gy, Lx, Ly, dt, dp;
};

// --- Linked list ---
__global__ void kResetHeads(int *head, int n){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i<n) head[i]=-1;
}
__global__ void kBuildLinked(const float* x,const float* y,int* next,int* head,
                             int N,float cellSize,int nx,int ny){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=N) return;
  int cx = int(floorf(x[i]/cellSize)); cx = clampi(cx,0,nx-1);
  int cy = int(floorf(y[i]/cellSize)); cy = clampi(cy,0,ny-1);
  int c  = cellId(cx,cy,nx);
  next[i] = atomicExch(&head[c], i);
}

// --- Densidad y presión ---
__global__ void kDensityPressure(Particles p){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;

  float xi=p.x[i], yi=p.y[i];
  int cx=int(floorf(xi/p.cellSize)); cx=clampi(cx,0,p.nxCells-1);
  int cy=int(floorf(yi/p.cellSize)); cy=clampi(cy,0,p.nyCells-1);

  float rhoi = 0.0f;
  #pragma unroll
  for(int oy=-1; oy<=1; ++oy){
    #pragma unroll
    for(int ox=-1; ox<=1; ++ox){
      int ncx = clampi(cx+ox,0,p.nxCells-1);
      int ncy = clampi(cy+oy,0,p.nyCells-1);
      int c   = cellId(ncx,ncy,p.nxCells);
      int j = p.cellHead[c];
      while(j!=-1){
        float dx = xi - p.x[j];
        float dy = yi - p.y[j];
        float r  = sqrtf(dx*dx + dy*dy);
        rhoi += W_wendland2D(r, p.h);  // masa=1 (MVP)
        j = p.next[j];
      }
    }
  }
  p.rho[i] = fmaxf(rhoi, 0.1f*p.rho0);
  p.P[i]   = p.cs*p.cs * (p.rho[i] - p.rho0);
}

// --- Fuerzas ---
__global__ void kForces(Particles p){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;

  float xi=p.x[i], yi=p.y[i];
  float axi = p.gx, ayi = p.gy;

  int cx=int(floorf(xi/p.cellSize)); cx=clampi(cx,0,p.nxCells-1);
  int cy=int(floorf(yi/p.cellSize)); cy=clampi(cy,0,p.nyCells-1);

  #pragma unroll
  for(int oy=-1; oy<=1; ++oy){
    #pragma unroll
    for(int ox=-1; ox<=1; ++ox){
      int ncx = clampi(cx+ox,0,p.nxCells-1);
      int ncy = clampi(cy+oy,0,p.nyCells-1);
      int c   = cellId(ncx,ncy,p.nxCells);
      int j = p.cellHead[c];
      while(j!=-1){
        if(j!=i){
          float dx = xi - p.x[j];
          float dy = yi - p.y[j];
          float r2 = dx*dx + dy*dy;
          float r  = sqrtf(r2) + 1e-12f;
          if(r < p.h){
            float grad = dW_wendland2D(r, p.h);
            float pij  = (p.P[i]/(p.rho[i]*p.rho[i]) + p.P[j]/(p.rho[j]*p.rho[j]));
            float invr = 1.0f/r;
            axi += -pij * grad * dx * invr;
            ayi += -pij * grad * dy * invr;

            // Viscosidad simple
            float dvx = p.vx[j]-p.vx[i];
            float dvy = p.vy[j]-p.vy[i];
            axi += p.nu * dvx;
            ayi += p.nu * dvy;
          }
        }
        j = p.next[j];
      }
    }
  }

  // Paredes no deslizantes simples
  float wall_d = 2.0f*p.dp;
  if(yi < wall_d || (p.Ly-yi) < wall_d){
    axi -= 5.0f*p.vx[i];
    ayi -= 5.0f*p.vy[i];
  }

  p.ax[i]=axi; p.ay[i]=ayi;
}

// --- Integración Verlet ---
__global__ void kVerlet_halfkick(Particles p){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;
  p.vx[i] += 0.5f * p.dt * p.ax[i];
  p.vy[i] += 0.5f * p.dt * p.ay[i];
}
__global__ void kVerlet_drift(Particles p){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;
  p.x[i]  += p.dt * p.vx[i];
  p.y[i]  += p.dt * p.vy[i];

  if(p.x[i] < 0.0f)  p.x[i] += p.Lx;
  if(p.x[i] >= p.Lx) p.x[i] -= p.Lx;
  if(p.y[i] < 0.0f){ p.y[i]=0.0f;  p.vy[i]=0.0f; }
  if(p.y[i] >  p.Ly){ p.y[i]=p.Ly;  p.vy[i]=0.0f; }
}
__global__ void kVerlet_halfkick_end(Particles p){
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;
  p.vx[i] += 0.5f * p.dt * p.ax[i];
  p.vy[i] += 0.5f * p.dt * p.ay[i];
}

// --- Perfil u(y) ---
__global__ void kProfileUy(const Particles p, float *acc_u, int *acc_c){
#if WRITE_PROFILE
  int i=blockIdx.x*blockDim.x+threadIdx.x; if(i>=p.N) return;
  int bin = int((p.y[i]/p.Ly) * YBINS);
  if(bin<0) bin=0; else if(bin>=YBINS) bin=YBINS-1;
  atomicAdd(&acc_u[bin], p.vx[i]);
  atomicAdd(&acc_c[bin], 1);
#endif
}

// Inicialización
void init_particles(std::vector<float>& x,std::vector<float>& y,
                    std::vector<float>& vx,std::vector<float>& vy,
                    int& N, const SimParams& sp)
{
  std::vector<float> px, py;
  for(float yy=sp.dp*1.0f; yy<=sp.Ly-sp.dp*1.0f; yy+=sp.dp){
    for(float xx=0.0f; xx<=sp.Lx-sp.dp; xx+=sp.dp){
      px.push_back(xx + 0.5f*sp.dp);
      py.push_back(yy);
    }
  }
  N = (int)px.size();
  x.resize(N); y.resize(N); vx.assign(N,0.0f); vy.assign(N,0.0f);
  for(int i=0;i<N;++i){ x[i]=px[i]; y[i]=py[i]; }
}

int main(){
  SimParams sp; sp.finalize();

  // Host
  int N=0; std::vector<float> hx,hy,hvx,hvy; init_particles(hx,hy,hvx,hvy,N,sp);
  size_t nBytes = size_t(N)*sizeof(float);

  // Device alloc
  Particles p{};
  p.N=N; p.nxCells=sp.nxCells; p.nyCells=sp.nyCells;
  p.cellSize=sp.cellSize; p.h=sp.h; p.rho0=sp.rho0; p.cs=sp.cs; p.nu=sp.nu;
  p.gx=sp.gx; p.gy=sp.gy; p.Lx=sp.Lx; p.Ly=sp.Ly; p.dt=sp.dt; p.dp=sp.dp;

  CUDA_CHECK(cudaMalloc(&p.x, nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.y, nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.vx,nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.vy,nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.ax,nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.ay,nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.rho,nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.P,  nBytes), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.next, N*sizeof(int)), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&p.cellHead, sp.nxCells*sp.nyCells*sizeof(int)), "cudaMalloc");

  CUDA_CHECK(cudaMemcpy(p.x, hx.data(), nBytes, cudaMemcpyHostToDevice), "cudaMemcpy");
  CUDA_CHECK(cudaMemcpy(p.y, hy.data(), nBytes, cudaMemcpyHostToDevice), "cudaMemcpy");
  CUDA_CHECK(cudaMemcpy(p.vx,hvx.data(), nBytes, cudaMemcpyHostToDevice), "cudaMemcpy");
  CUDA_CHECK(cudaMemcpy(p.vy,hvy.data(), nBytes, cudaMemcpyHostToDevice), "cudaMemcpy");

  dim3 block(BLOCK_SIZE);
  dim3 gridP((N+block.x-1)/block.x);
  dim3 gridHead((sp.nxCells*sp.nyCells + block.x -1)/block.x);

  // Buffers de perfil
  float *d_prof_u=nullptr; int *d_prof_c=nullptr;
#if WRITE_PROFILE
  CUDA_CHECK(cudaMalloc(&d_prof_u, YBINS*sizeof(float)), "cudaMalloc");
  CUDA_CHECK(cudaMalloc(&d_prof_c, YBINS*sizeof(int)),   "cudaMalloc");
  CUDA_CHECK(cudaMemset(d_prof_u, 0, YBINS*sizeof(float)), "cudaMemset");
  CUDA_CHECK(cudaMemset(d_prof_c, 0, YBINS*sizeof(int)),   "cudaMemset");
#endif

  // Bucle de tiempo
  GpuTimer Tall; Tall.tic();
  for(int s=0; s<sp.steps; ++s){
    kVerlet_halfkick<<<gridP, block>>>(p);

    kResetHeads<<<gridHead, block>>>(p.cellHead, sp.nxCells*sp.nyCells);
    kBuildLinked<<<gridP, block>>>(p.x,p.y,p.next,p.cellHead,p.N, p.cellSize, p.nxCells, p.nyCells);
    kDensityPressure<<<gridP, block>>>(p);
    kForces<<<gridP, block>>>(p);

    kVerlet_drift<<<gridP, block>>>(p);

    kResetHeads<<<gridHead, block>>>(p.cellHead, sp.nxCells*sp.nyCells);
    kBuildLinked<<<gridP, block>>>(p.x,p.y,p.next,p.cellHead,p.N, p.cellSize, p.nxCells, p.nyCells);
    kDensityPressure<<<gridP, block>>>(p);
    kForces<<<gridP, block>>>(p);

    kVerlet_halfkick_end<<<gridP, block>>>(p);
  }
  cudaDeviceSynchronize();
  float ms_total = Tall.toc();

  double updates = double(N) * double(sp.steps);
  double mpups   = updates / (ms_total*1e3);
  std::printf("N=%d steps=%d  Time=%.1f ms  MPUPS=%.2f  (block=%d)\n",
              N, sp.steps, ms_total, mpups, BLOCK_SIZE);

#if WRITE_PROFILE
  kProfileUy<<<gridP, block>>>(p, d_prof_u, d_prof_c);
  std::vector<float> hpu(YBINS,0.0f); std::vector<int> hpc(YBINS,0);
  CUDA_CHECK(cudaMemcpy(hpu.data(), d_prof_u, YBINS*sizeof(float), cudaMemcpyDeviceToHost), "cudaMemcpy");
  CUDA_CHECK(cudaMemcpy(hpc.data(), d_prof_c, YBINS*sizeof(int),   cudaMemcpyDeviceToHost), "cudaMemcpy");

  FILE* f = std::fopen("profile_uy_cuda.csv","w");
  if(f){
    std::fprintf(f,"bin,y,u_mean\n");
    for(int b=0;b<YBINS;++b){
      float y = ( (b+0.5f)/float(YBINS) ) * sp.Ly;
      float u = (hpc[b]>0) ? (hpu[b]/float(hpc[b])) : 0.0f;
      std::fprintf(f,"%d,%.7f,%.7f\n", b, y, u);
    }
    std::fclose(f);
    std::printf("Perfil u(y) guardado: profile_uy_cuda.csv (YBINS=%d)\n", YBINS);
  }
  cudaFreeChecked(d_prof_u);
  cudaFreeChecked(d_prof_c);
#endif

  cudaFreeChecked(p.x); cudaFreeChecked(p.y);
  cudaFreeChecked(p.vx); cudaFreeChecked(p.vy);
  cudaFreeChecked(p.ax); cudaFreeChecked(p.ay);
  cudaFreeChecked(p.rho); cudaFreeChecked(p.P);
  cudaFreeChecked(p.next); cudaFreeChecked(p.cellHead);
  return 0;
}
