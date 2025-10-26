#pragma once
#include <cmath>

struct ForceParams {
  float fx0 = 0.0f;
  float fy0 = 0.0f;
  float amp = 1.0f;
  float w   = 2.0f * 3.1415926535f; // 1 Hz
};

__device__ __forceinline__ float2 make_fext(float t, const ForceParams& p){
  return make_float2(p.fx0 + p.amp * sinf(p.w * t), p.fy0);
}
