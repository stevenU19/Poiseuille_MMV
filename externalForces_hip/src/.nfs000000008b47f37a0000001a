#include <cstdio>
#include <cstdlib>
#include <algorithm>
#include <memory>
#include <type_traits>
#include <random>
#include <vector>
#include <numeric>
#include <hip/hip_runtime.h>
#include "sph_utils.hpp"

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

struct Scale { float s; float operator()(float x) const { return s*x; } };

int main(){
  const int   N      = NPART;
  const int   STEPS_ = STEPS;
  const float dt     = 5e-4f;

  std::unique_ptr<float> legacy_ptr(new float(1.0f));
  using result_t = std::invoke_result_t<Scale, float>; (void)sizeof(result_t);

  std::vector<int> ids(N);
  std::iota(ids.begin(), ids.end(), 0);
  std::mt19937 rng(12345);
  std::shuffle(ids.begin(), ids.end(), rng);

  std::vector<float2> hpos(N), hvel(N);
  for(int i=0;i<N;i++){ hpos[i] = make_float2(0.f, 0.f); hvel[i] = make_float2(0.f, 0.f); }

  float2 *dpos=nullptr, *dvel=nullptr;
  hipMalloc(&dpos, N*sizeof(float2));
  hipMalloc(&dvel, N*sizeof(float2));
  hipMemcpy(dpos, hpos.data(), N*sizeof(float2), hipMemcpyHostToDevice);
  hipMemcpy(dvel, hvel.data(), N*sizeof(float2), hipMemcpyHostToDevice);

  const dim3 BS(BLOCK_SIZE);
  const dim3 GS((N + BS.x - 1)/BS.x);

  ForceParams fp; fp.fx0 = 0.0f; fp.fy0 = 0.0f; fp.amp = 2.0f; fp.w = 2.0f*3.1415926535f;

  hipEvent_t e0,e1;
  hipEventCreate(&e0); hipEventCreate(&e1);
  hipDeviceSynchronize();
  hipEventRecord(e0);

  float t = 0.f;
  for(int s=0;s<STEPS_;++s){
    hipLaunchKernelGGL(integrate, GS, BS, 0, 0, dpos, dvel, N, dt, t, fp);
    t += 4*dt;
  }

  hipEventRecord(e1);
  hipEventSynchronize(e1);
  float ms=0.f; hipEventElapsedTime(&ms, e0, e1);

  hipMemcpy(hpos.data(), dpos, N*sizeof(float2), hipMemcpyDeviceToHost);
  hipMemcpy(hvel.data(), dvel, N*sizeof(float2), hipMemcpyDeviceToHost);

  hipFree(dpos); hipFree(dvel);
  hipEventDestroy(e0); hipEventDestroy(e1);

  const double mpups = (double(N)*double(STEPS_)) / (ms/1000.0) * 1e-6;
  std::printf("HIP(FIXED) N=%d steps=%d Time=%.3f ms MPUPS=%.3f (block=%d)\n",
              N, STEPS_, ms, mpups, BLOCK_SIZE);
  return 0;
}

