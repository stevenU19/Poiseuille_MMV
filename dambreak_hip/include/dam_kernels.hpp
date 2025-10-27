#pragma once
#include <cstdint>
#include <hip/hip_runtime.h>
#include "hip_compat_constants.h"

namespace dsph::dambreak {

struct Domain {
  std::uint32_t n;
  float dt, h, gamma, rho0, cs;
  float gx, gy, gz;
};

void taitPressure(const Domain& dom,
                  const float* __restrict__ rho,
                  float* __restrict__ p,
                  hipStream_t stream = nullptr);

void addGravity(const Domain& dom,
                float* __restrict__ vx,
                float* __restrict__ vy,
                float* __restrict__ vz,
                hipStream_t stream = nullptr);

void integrateEuler(const Domain& dom,
                    float* __restrict__ x,
                    float* __restrict__ y,
                    float* __restrict__ z,
                    const float* __restrict__ vx,
                    const float* __restrict__ vy,
                    const float* __restrict__ vz,
                    hipStream_t stream = nullptr);

void runStep(const Domain& dom,
             const float* __restrict__ rho,
             float* __restrict__ p,
             float* __restrict__ x,
             float* __restrict__ y,
             float* __restrict__ z,
             float* __restrict__ vx,
             float* __restrict__ vy,
             float* __restrict__ vz,
             hipStream_t stream = nullptr);

} // namespace dsph::dambreak

