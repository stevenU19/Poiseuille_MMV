#pragma once
#include <hip/hip_runtime.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
__device__ inline float W_wendland2D(float r, float h){
  if(r>=h) return 0.0f;
  float q = r / h;
  float a = 7.0f / (4.0f * float(M_PI) * h*h);
  float t = (1.0f - 0.5f*q);
  return a * t*t*t * (2.0f*q + 1.0f);
}
__device__ inline float dW_wendland2D(float r, float h){
  if(r<=0.0f || r>=h) return 0.0f;
  float q = r / h;
  float a = 7.0f / (4.0f * float(M_PI) * h*h);
  float t = (1.0f - 0.5f*q);
  float d_dq = -1.5f*t*t*(2.0f*q+1.0f) + t*t*t*2.0f;
  return a * d_dq * (1.0f/h);
}
__device__ __forceinline__ int clampi(int v,int lo,int hi){ return v<lo?lo:(v>hi?hi:v); }
__device__ __forceinline__ int cellId(int cx,int cy,int nx){ return cy*nx + cx; }
