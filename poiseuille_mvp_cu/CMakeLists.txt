cmake_minimum_required(VERSION 3.15)
project(poiseuille_cuda LANGUAGES CXX CUDA)

# Host en C++11 (CUDA 8.0 se lleva bien con esto)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_EXTENSIONS OFF)

# No agregamos -O3 manual: en Release CMake ya pasa optimización.
# Evitamos “redefinition of argument 'optimize'” en nvcc 8/9.

# Parámetros configurables
if(NOT DEFINED BLOCK_SIZE)
  set(BLOCK_SIZE 256)
endif()
add_compile_definitions(BLOCK_SIZE=${BLOCK_SIZE})

if(NOT DEFINED YBINS)
  set(YBINS 64)
endif()
add_compile_definitions(YBINS=${YBINS})

if(NOT DEFINED WRITE_PROFILE)
  set(WRITE_PROFILE 1)
endif()
add_compile_definitions(WRITE_PROFILE=${WRITE_PROFILE})

add_executable(poiseuille src/poiseuille.cu)
target_include_directories(poiseuille PRIVATE include)

# Fuerza estándar para NVCC antiguo: usa -std=c++11 (no --std=)
target_compile_options(poiseuille PRIVATE
  $<$<COMPILE_LANGUAGE:CUDA>:-std=c++11>
  $<$<COMPILE_LANGUAGE:CUDA>:-Xcompiler=-ffp-contract=off>
  $<$<COMPILE_LANGUAGE:CXX>:-ffp-contract=off -Wall -Wextra>
)

# Arquitectura Fermi
set_property(TARGET poiseuille PROPERTY CUDA_ARCHITECTURES 20)

message(STATUS "Toolchain esperado: CUDA 8.0 + GCC 5.3.0 (Fermi sm_20, C++11)")



