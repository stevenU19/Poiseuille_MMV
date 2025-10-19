#pragma once
#include <cstdint>
#include <cmath>
struct SimParams {
  float Lx = 1.0f;
  float Ly = 0.2f;
  float dp = 0.0025f;
  float h  = 0.00325f;
  float rho0 = 1000.0f;
  float cs   = 15.0f;
  float nu   = 1.0e-6f;
  float gx   = 1.0e-4f;
  float gy   = 0.0f;
  float cfl  = 0.2f;
  float dt   = 1.0e-4f;
  int   steps= 500;
  float cellSize;
  int   nxCells, nyCells;
  void finalize() {
    cellSize = h;
    nxCells  = int(Lx/cellSize) + 1;
    nyCells  = int(Ly/cellSize) + 1;
  }
};
