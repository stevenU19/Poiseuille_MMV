#pragma once
#include <hip/hip_runtime.h>
struct GpuTimer {
  hipEvent_t a{}, b{};
  GpuTimer() { hipEventCreate(&a); hipEventCreate(&b); }
  ~GpuTimer(){ hipEventDestroy(a); hipEventDestroy(b); }
  void tic() { hipEventRecord(a, 0); }
  float toc(){
    hipEventRecord(b, 0); hipEventSynchronize(b);
    float ms=0; hipEventElapsedTime(&ms, a, b); return ms;
  }
};
