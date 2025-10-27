#include <cuda_runtime.h>
#include <iostream>
#include <vector>
#include "dam_kernels.hpp"
#include "params.hpp"

int main() {
  using namespace dsph::dambreak;

  Params prm;
  Domain dom{prm.n, prm.dt, prm.h, prm.gamma, prm.rho0, prm.cs, prm.gx, prm.gy, prm.gz};

  std::vector<float> h_rho(dom.n, dom.rho0), h_p(dom.n, 0.0f);
  std::vector<float> h_x(dom.n, 0.0f), h_y(dom.n, 0.0f), h_z(dom.n, 0.0f);
  std::vector<float> h_vx(dom.n, 0.0f), h_vy(dom.n, 0.0f), h_vz(dom.n, 0.0f);

  float *d_rho=nullptr, *d_p=nullptr, *d_x=nullptr, *d_y=nullptr, *d_z=nullptr;
  float *d_vx=nullptr, *d_vy=nullptr, *d_vz=nullptr;
  const size_t bytes = sizeof(float) * dom.n;

  cudaMalloc(&d_rho, bytes); cudaMalloc(&d_p, bytes);
  cudaMalloc(&d_x, bytes);   cudaMalloc(&d_y, bytes); cudaMalloc(&d_z, bytes);
  cudaMalloc(&d_vx, bytes);  cudaMalloc(&d_vy, bytes); cudaMalloc(&d_vz, bytes);

  cudaMemcpy(d_rho, h_rho.data(), bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_x,   h_x.data(),   bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_y,   h_y.data(),   bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_z,   h_z.data(),   bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_vx,  h_vx.data(),  bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_vy,  h_vy.data(),  bytes, cudaMemcpyHostToDevice);
  cudaMemcpy(d_vz,  h_vz.data(),  bytes, cudaMemcpyHostToDevice);

  runStep(dom, d_rho, d_p, d_x, d_y, d_z, d_vx, d_vy, d_vz, 0);
  cudaDeviceSynchronize();

  cudaMemcpy(h_p.data(),  d_p,  bytes, cudaMemcpyDeviceToHost);
  cudaMemcpy(h_vy.data(), d_vy, bytes, cudaMemcpyDeviceToHost);
  cudaMemcpy(h_y.data(),  d_y,  bytes, cudaMemcpyDeviceToHost);

  std::cout << "OK CUDA DamBreak MVP\n";
  std::cout << "p[0]=" << h_p[0] << "  vy[0]=" << h_vy[0] << "  y[0]=" << h_y[0] << "\n";

  cudaFree(d_rho); cudaFree(d_p);
  cudaFree(d_x);   cudaFree(d_y);   cudaFree(d_z);
  cudaFree(d_vx);  cudaFree(d_vy);  cudaFree(d_vz);
  return 0;
}

