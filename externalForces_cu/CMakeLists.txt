cmake_minimum_required(VERSION 3.12)
project(B1_ExternalForces_std_cuda LANGUAGES CXX CUDA)

# Estándar C++ para host (C++11) — compila en CUDA, fallará al portar a HIP (C++17).
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_EXTENSIONS OFF)

# Parámetros configurables
if(NOT DEFINED BLOCK_SIZE)
  set(BLOCK_SIZE 128)
endif()
add_compile_definitions(BLOCK_SIZE=${BLOCK_SIZE})

if(NOT DEFINED STEPS)
  set(STEPS 500)
endif()
add_compile_definitions(STEPS=${STEPS})

if(NOT DEFINED NPART)
  set(NPART 31600)
endif()
add_compile_definitions(NPART=${NPART})

add_executable(external_forces src/external_forces.cu)
target_include_directories(external_forces PRIVATE include)

# NVCC antiguo (CUDA 8/9/10): fuerza -std=c++11 para el compilador CUDA
target_compile_options(external_forces PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:-std=c++11>
  $<$<COMPILE_LANGUAGE:CXX>:-Wall -Wextra>
)

# Arquitectura Fermi (Tesla M2050) — silencia aviso deprecado
set(CMAKE_CUDA_FLAGS "${CMAKE_CUDA_FLAGS} -gencode arch=compute_20,code=sm_20 -Wno-deprecated-gpu-targets")

message(STATUS "BLOCK_SIZE=${BLOCK_SIZE}  STEPS=${STEPS}  NPART=${NPART}")
