cmake_minimum_required(VERSION 3.15)

project(dambreak_cuda_ref LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(CUDA 8.0 REQUIRED)

if(NOT DEFINED CUDA_ARCH)
  set(CUDA_ARCH 60)
endif()

set(CUDA_NVCC_FLAGS
  ${CUDA_NVCC_FLAGS}
  -std=c++11
  -Xcompiler -fPIC
  -gencode arch=compute_${CUDA_ARCH},code=sm_${CUDA_ARCH}
)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${CUDA_INCLUDE_DIRS}
)

cuda_add_executable(dambreak_cuda_ref
  ${CMAKE_CURRENT_SOURCE_DIR}/src/dambreak.cu
  ${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp
)

target_link_libraries(dambreak_cuda_ref
  ${CUDA_LIBRARIES}
)

set_target_properties(dambreak_cuda_ref PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)





