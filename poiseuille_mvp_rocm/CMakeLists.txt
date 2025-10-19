cmake_minimum_required(VERSION 3.21)
project(poiseuille_mvp LANGUAGES CXX HIP)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_HIP_STANDARD 17)

# Flags coherentes para comparabilidad CUDA/ROCm
add_compile_options(-O3 -ffp-contract=off -Wall -Wextra)

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

# ——— Intentar localizar el package de HIP ———
set(_HAVE_HIP_PACKAGE OFF)
find_package(HIP QUIET CONFIG)    # try moderno (mayúsculas)
if(TARGET HIP::device)
  set(_HAVE_HIP_PACKAGE ON)
  set(_HIP_TARGET HIP::device)
else()
  find_package(hip QUIET CONFIG)  # fallback (minúsculas)
  if(TARGET hip::device)
    set(_HAVE_HIP_PACKAGE ON)
    set(_HIP_TARGET hip::device)
  endif()
endif()

# Incluir directorios de ROCm si no hay paquete HIP (fallback)
if(NOT _HAVE_HIP_PACKAGE)
  if(DEFINED ENV{ROCM_PATH})
    set(_ROCM_INC "$ENV{ROCM_PATH}/include")
  else()
    set(_ROCM_INC "/opt/rocm/include")
  endif()
  message(WARNING "HIP package config NOT found. Using includes fallback: ${_ROCM_INC}")
endif()

# Ejecutable
add_executable(poiseuille src/poiseuille.hip)
target_include_directories(poiseuille PRIVATE include)
if(NOT _HAVE_HIP_PACKAGE)
  target_include_directories(poiseuille PRIVATE ${_ROCM_INC})
endif()

# Enlazar con el target HIP si existe (opcional)
if(_HAVE_HIP_PACKAGE)
  target_link_libraries(poiseuille PRIVATE ${_HIP_TARGET})
endif()

message(STATUS "BLOCK_SIZE=${BLOCK_SIZE}  YBINS=${YBINS}  WRITE_PROFILE=${WRITE_PROFILE}")
message(STATUS "HIP package: ${_HAVE_HIP_PACKAGE}  TargetUsed: ${_HIP_TARGET}")
message(STATUS "Selecciona backend con HIP_PLATFORM=amd|nvidia")


