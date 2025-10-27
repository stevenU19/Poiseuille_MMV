#include <hip/hip_runtime.h>
#include <iostream>
#include <vector>
#include "dam_kernels.hpp"
#include "params.hpp"

int main() {
  using namespace dsph::dambreak;

  Params prm;
  Domain dom{prm.n, prm.dt, prm.h, prm.gamma, prm.rho0, prm.cs, prm.gx, prm.gy, prm.gz};

  // Host
  std::vector<float> h_rho(dom.n, dom.rho0), h_p(dom.n, 0.0f);
  std::vector<float> h_x(dom.n, 0.0f), h_y(dom.n, 0.0f), h_z(dom.n, 0.0f);
  std::vector<float> h_vx(dom.n, 0.0f), h_vy(dom.n, 0.0f), h_vz(dom.n, 0.0f);

  // Device
  float *d_rho=nullptr, *d_p=nullptr, *d_x=nullptr, *d_y=nullptr, *d_z=nullptr;
  float *d_vx=nullptr, *d_vy=nullptr, *d_vz=nullptr;
  const size_t bytes = sizeof(float) * dom.n;

  hipMalloc(&d_rho, bytes); hipMalloc(&d_p, bytes);
  hipMalloc(&d_x, bytes);   hipMalloc(&d_y, bytes); hipMalloc(&d_z, bytes);
  hipMalloc(&d_vx, bytes);  hipMalloc(&d_vy, bytes); hipMalloc(&d_vz, bytes);

  hipMemcpy(d_rho, h_rho.data(), bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_x,   h_x.data(),   bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_y,   h_y.data(),   bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_z,   h_z.data(),   bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_vx,  h_vx.data(),  bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_vy,  h_vy.data(),  bytes, hipMemcpyHostToDevice);
  hipMemcpy(d_vz,  h_vz.data(),  bytes, hipMemcpyHostToDevice);

  runStep(dom, d_rho, d_p, d_x, d_y, d_z, d_vx, d_vy, d_vz, nullptr);
  hipDeviceSynchronize();

  hipMemcpy(h_p.data(), d_p, bytes, hipMemcpyDeviceToHost);
  hipMemcpy(h_vy.data(), d_vy, bytes, hipMemcpyDeviceToHost);
  hipMemcpy(h_y.data(), d_y, bytes, hipMemcpyDeviceToHost);

  std::cout << "OK ROCm DamBreak MVP\n";
  std::cout << "p[0]=" << h_p[0] << "  vy[0]=" << h_vy[0] << "  y[0]=" << h_y[0] << "\n";

  hipFree(d_rho); hipFree(d_p);
  hipFree(d_x); hipFree(d_y); hipFree(d_z);
  hipFree(d_vx); hipFree(d_vy); hipFree(d_vz);
  return 0;
}
