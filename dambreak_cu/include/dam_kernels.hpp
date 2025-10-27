#pragma once
#include <cstdint>
#include <cuda_runtime.h>
#include <math_constants.h> // usamos constantes CUDA (CUDART_*)

namespace dsph { namespace dambreak {

struct Domain {
  std::uint32_t n;
  float dt, h, gamma, rho0, cs;
  float gx, gy, gz;
};

void taitPressure(const Domain& dom,
                  const float* __restrict__ rho,
                  float* __restrict__ p,
                  cudaStream_t stream = 0);

void addGravity(const Domain& dom,
                float* __restrict__ vx,
                float* __restrict__ vy,
                float* __restrict__ vz,
                cudaStream_t stream = 0);

void integrateEuler(const Domain& dom,
                    float* __restrict__ x,
                    float* __restrict__ y,
                    float* __restrict__ z,
                    const float* __restrict__ vx,
                    const float* __restrict__ vy,
                    const float* __restrict__ vz,
                    cudaStream_t stream = 0);

void runStep(const Domain& dom,
             const float* __restrict__ rho,
             float* __restrict__ p,
             float* __restrict__ x,
             float* __restrict__ y,
             float* __restrict__ z,
             float* __restrict__ vx,
             float* __restrict__ vy,
             float* __restrict__ vz,
             cudaStream_t stream = 0);

}} // namespace dsph::dambreak


