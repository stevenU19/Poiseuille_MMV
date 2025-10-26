cmake_minimum_required(VERSION 3.21)
project(B1_ExternalForces_FIXED_HIP LANGUAGES CXX HIP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED BLOCK_SIZE)
  set(BLOCK_SIZE 128)
endif()
if(NOT DEFINED STEPS)
  set(STEPS 500)
endif()
if(NOT DEFINED NPART)
  set(NPART 31600)
endif()

add_compile_definitions(BLOCK_SIZE=${BLOCK_SIZE})
add_compile_definitions(STEPS=${STEPS})
add_compile_definitions(NPART=${NPART})

add_executable(external_forces_fixed
  src/external_forces_fixed.hip
)

target_include_directories(external_forces_fixed PRIVATE include)

target_compile_options(external_forces_fixed PRIVATE
  --offload-arch=gfx90a
  -O3 -ffast-math
  -Wall -Wextra
)

message(STATUS "BLOCK_SIZE=${BLOCK_SIZE}  STEPS=${STEPS}  NPART=${NPART}")

