#pragma once
#include <chrono>

struct Timer {
  std::chrono::steady_clock::time_point t0{};
  void tic() { t0 = std::chrono::steady_clock::now(); }
  double toc() const {
    return std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
  }
};

