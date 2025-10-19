#pragma once
#include <cuda_runtime.h>
#include <cstdio>

struct GpuTimer {
  cudaEvent_t a{}, b{};
  GpuTimer(){ cudaEventCreate(&a); cudaEventCreate(&b); }
  ~GpuTimer(){ cudaEventDestroy(a); cudaEventDestroy(b); }
  void tic(){ cudaEventRecord(a, 0); }
  float toc(){
    cudaEventRecord(b, 0); cudaEventSynchronize(b);
    float ms=0; cudaEventElapsedTime(&ms, a, b); return ms;
  }
};

inline void CUDA_CHECK(cudaError_t e, const char* what){
  if(e != cudaSuccess){
    std::fprintf(stderr, "[CUDA] %s failed: %s\n", what, cudaGetErrorString(e));
  }
}

template <typename T>
inline void cudaFreeChecked(T*& ptr){
  if(ptr){ CUDA_CHECK(cudaFree(reinterpret_cast<void*>(ptr)), "cudaFree"); ptr=nullptr; }
}

