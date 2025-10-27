#pragma once

struct Params {
  unsigned n = 1u << 12; // 4096
  float dt   = 1e-4f;
  float h    = 0.01f;
  float gamma = 7.0f;
  float rho0  = 1000.0f;
  float cs    = 30.0f;
  float gx = 0.0f, gy = -9.81f, gz = 0.0f;
};
