#include <cuda_runtime.h>
#include <math.h>
#include <math_constants.h> // mantenemos las constantes CUDA
#include <cfloat>           // FLT_EPSILON (CUDA 8 no tiene CUDART_EPSILON)
#include "dam_kernels.hpp"

namespace dsph { namespace dambreak {

__global__ void k_taitPressure(std::uint32_t n, float rho0, float cs, float gamma,
                               const float* __restrict__ rho,
                               float* __restrict__ p) {
  const std::uint32_t i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  // Evita dividir por cero: CUDA 8.0 no define CUDART_EPSILON; usa FLT_EPSILON
  const float rr = fmaxf(rho[i], FLT_EPSILON) / rho0;
  const float term = powf(rr, gamma) - 1.0f;
  // p = (rho0 * cs^2 / gamma) * ( (rho/rho0)^gamma - 1 )
  p[i] = (rho0 * cs * cs / gamma) * term;
}

__global__ void k_addGravity(std::uint32_t n, float dt, float gx, float gy, float gz,
                             float* __restrict__ vx,
                             float* __restrict__ vy,
                             float* __restrict__ vz) {
  const std::uint32_t i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  vx[i] += dt * gx;
  vy[i] += dt * gy;
  vz[i] += dt * gz;
}

__global__ void k_integrateEuler(std::uint32_t n, float dt,
                                 float* __restrict__ x,
                                 float* __restrict__ y,
                                 float* __restrict__ z,
                                 const float* __restrict__ vx,
                                 const float* __restrict__ vy,
                                 const float* __restrict__ vz) {
  const std::uint32_t i = blockIdx.x * blockDim.x + threadIdx.x;
  if (i >= n) return;
  x[i] += dt * vx[i];
  y[i] += dt * vy[i];
  z[i] += dt * vz[i];
}

static inline dim3 blocks(std::uint32_t n, std::uint32_t bs) {
  return dim3((n + bs - 1u) / bs);
}

void taitPressure(const Domain& dom,
                  const float* __restrict__ rho,
                  float* __restrict__ p,
                  cudaStream_t stream) {
  const std::uint32_t bs = 256u;
  k_taitPressure<<<blocks(dom.n, bs), dim3(bs), 0, stream>>>(
      dom.n, dom.rho0, dom.cs, dom.gamma, rho, p);
}

void addGravity(const Domain& dom,
                float* __restrict__ vx,
                float* __restrict__ vy,
                float* __restrict__ vz,
                cudaStream_t stream) {
  const std::uint32_t bs = 256u;
  k_addGravity<<<blocks(dom.n, bs), dim3(bs), 0, stream>>>(
      dom.n, dom.dt, dom.gx, dom.gy, dom.gz, vx, vy, vz);
}

void integrateEuler(const Domain& dom,
                    float* __restrict__ x,
                    float* __restrict__ y,
                    float* __restrict__ z,
                    const float* __restrict__ vx,
                    const float* __restrict__ vy,
                    const float* __restrict__ vz,
                    cudaStream_t stream) {
  const std::uint32_t bs = 256u;
  k_integrateEuler<<<blocks(dom.n, bs), dim3(bs), 0, stream>>>(
      dom.n, dom.dt, x, y, z, vx, vy, vz);
}

void runStep(const Domain& dom,
             const float* __restrict__ rho,
             float* __restrict__ p,
             float* __restrict__ x,
             float* __restrict__ y,
             float* __restrict__ z,
             float* __restrict__ vx,
             float* __restrict__ vy,
             float* __restrict__ vz,
             cudaStream_t stream) {
  taitPressure(dom, rho, p, stream);
  addGravity(dom, vx, vy, vz, stream);
  integrateEuler(dom, x, y, z, vx, vy, vz, stream);
  cudaGetLastError();
}

}} // namespace dsph::dambreak


