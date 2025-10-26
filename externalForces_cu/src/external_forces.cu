#include <cstdio>
#include <cstdlib>
#include <algorithm>      // std::random_shuffle (C++11)
#include <memory>         // std::auto_ptr (eliminado en C++17)
#include <type_traits>    // std::result_of (eliminado en C++20 / reemplazado)
#include <vector>
#include <numeric>
#include <curand_kernel.h>
#include "sph_utils.hpp"

// Kernel simple: integra velocidad y posición con fuerza externa periódica
__global__ void integrate(float2* pos, float2* vel, int n, float dt, float t0, ForceParams fp){
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if(i>=n) return;
  float t = t0;
  #pragma unroll 4
  for(int k=0;k<4;k++){
    float2 f = make_fext(t, fp);
    vel[i].x += f.x * dt;
    vel[i].y += f.y * dt;
    pos[i].x += vel[i].x * dt;
    pos[i].y += vel[i].y * dt;
    t += dt;
  }
}

// Utilidad host para “provocar” dependencia de estándar
struct Scale { float s; float operator()(float x) const { return s*x; } };

int main(){
  const int    N   = NPART;
  const int    STEPS_ = STEPS;
  const float  dt  = 5e-4f;

  // --- (1) Uso intencional de std::auto_ptr (DEPRECADO en C++11, ELIMINADO en C++17)
  std::auto_ptr<float> legacy_ptr(new float(1.0f)); // <- al portar a HIP con C++17: error

  // --- (2) Uso de std::result_of (OBSOLETO / reemplazar por std::invoke_result_t en C++17)
  typedef std::result_of<Scale(float)>::type result_t; // <- fallará en toolchains modernos
  (void)sizeof(result_t);

  // --- (3) Uso de std::random_shuffle (ELIMINADO en C++17; reemplazo -> std::shuffle)
  std::vector<int> ids(N);
  std::iota(ids.begin(), ids.end(), 0);
  std::random_shuffle(ids.begin(), ids.end()); // <- al portar a HIP: error de símbolo eliminado

  // Memoria host
  std::vector<float2> hpos(N), hvel(N);
  for(int i=0;i<N;i++){ hpos[i] = make_float2(0.f, 0.f); hvel[i] = make_float2(0.f, 0.f); }

  // Memoria device
  float2 *dpos=nullptr, *dvel=nullptr;
  cudaMalloc(&dpos, N*sizeof(float2));
  cudaMalloc(&dvel, N*sizeof(float2));
  cudaMemcpy(dpos, hpos.data(), N*sizeof(float2), cudaMemcpyHostToDevice);
  cudaMemcpy(dvel, hvel.data(), N*sizeof(float2), cudaMemcpyHostToDevice);

  const dim3 BS(BLOCK_SIZE);
  const dim3 GS((N + BS.x - 1)/BS.x);

  ForceParams fp; fp.fx0 = 0.0f; fp.fy0 = 0.0f; fp.amp = 2.0f; fp.w = 2.0f*3.1415926535f;

  cudaEvent_t e0,e1;
  cudaEventCreate(&e0); cudaEventCreate(&e1);
  cudaDeviceSynchronize();
  cudaEventRecord(e0);

  float t = 0.f;
  for(int s=0;s<STEPS_;++s){
    integrate<<<GS,BS>>>(dpos, dvel, N, dt, t, fp);
    t += 4*dt;
  }

  cudaEventRecord(e1);
  cudaEventSynchronize(e1);
  float ms=0.f; cudaEventElapsedTime(&ms, e0, e1);

  cudaMemcpy(hpos.data(), dpos, N*sizeof(float2), cudaMemcpyDeviceToHost);
  cudaMemcpy(hvel.data(), dvel, N*sizeof(float2), cudaMemcpyDeviceToHost);

  cudaFree(dpos); cudaFree(dvel);
  cudaEventDestroy(e0); cudaEventDestroy(e1);

  const double mpups = (double(N)*double(STEPS_)) / (ms/1000.0) * 1e-6;
  std::printf("B1 ExternalForces CUDA  N=%d steps=%d  Time=%.3f ms  MPUPS=%.3f  (block=%d)\n",
              N, STEPS_, ms, mpups, BLOCK_SIZE);
  return 0;
}
