cmake_minimum_required(VERSION 3.24)

# Importante: habilitamos HIP (y CXX por dependencia de Threads), pero
# vamos a compilar main.cpp también como HIP para evitar banderas en c++.
project(dambreak_hip_ok LANGUAGES CXX HIP)

# Host C++ (por si CMake/HIP requiere un compilador CXX detectable)
if(NOT CMAKE_CXX_COMPILER)
  if(EXISTS "/opt/rocm-6.4.3/lib/llvm/bin/clang++")
    set(CMAKE_CXX_COMPILER "/opt/rocm-6.4.3/lib/llvm/bin/clang++" CACHE FILEPATH "Host C++ compiler" FORCE)
  elseif(EXISTS "/opt/ohpc/pub/devtools/gcc/9.2.0/bin/g++")
    set(CMAKE_CXX_COMPILER "/opt/ohpc/pub/devtools/gcc/9.2.0/bin/g++" CACHE FILEPATH "Host C++ compiler" FORCE)
  endif()
endif()

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_HIP_STANDARD 17)
set(CMAKE_HIP_STANDARD_REQUIRED ON)

find_package(HIP REQUIRED CONFIG)
find_package(Threads REQUIRED)

# Arquitectura HIP solo para kernels
set(CMAKE_HIP_ARCHITECTURES gfx90a)

add_executable(dambreak_hip_ok
  src/dambreak.hip
  src/main.cpp
)

# Compilar ambos con el compilador HIP: esto define __HIP_PLATFORM_AMD__ y
# evita que c++ vea --offload-arch. Además, el .hip queda marcado como HIP.
set_source_files_properties(
  src/dambreak.hip
  PROPERTIES
    LANGUAGE HIP
    HIP_SOURCE_PROPERTY_FORMAT 1
)
set_source_files_properties(
  src/main.cpp
  PROPERTIES
    LANGUAGE HIP
    HIP_SOURCE_PROPERTY_FORMAT 1
)

# También fija la arch a nivel de target (algunos CMake/HIP lo requieren)
set_property(TARGET dambreak_hip_ok PROPERTY HIP_ARCHITECTURES gfx90a)

# Includes propios y de HIP (HIP_INCLUDE_DIRS viene de find_package(HIP))
target_include_directories(dambreak_hip_ok PUBLIC
  ${CMAKE_CURRENT_SOURCE_DIR}/include
  ${HIP_INCLUDE_DIRS}
  /opt/rocm/include
)

# Enlace HIP robusto (detecta target correcto en ROCm 6.4.3)
set(_HIP_DEVICE_TARGET "")
if(TARGET hip::device)
  set(_HIP_DEVICE_TARGET hip::device)
elseif(TARGET HIP::device)
  set(_HIP_DEVICE_TARGET HIP::device)
elseif(TARGET hip::amdhip64)
  set(_HIP_DEVICE_TARGET hip::amdhip64)
endif()

if(_HIP_DEVICE_TARGET)
  target_link_libraries(dambreak_hip_ok PUBLIC ${_HIP_DEVICE_TARGET} Threads::Threads)
else()
  find_library(AMDHIP64_LIB amdhip64
    HINTS ENV ROCM_PATH /opt/rocm /opt/rocm-6.4.3
    PATH_SUFFIXES lib lib64)
  if(NOT AMDHIP64_LIB)
    message(FATAL_ERROR "No se encontró la librería amdhip64. Define ROCM_PATH o verifica la instalación de ROCm.")
  endif()
  target_link_libraries(dambreak_hip_ok PUBLIC ${AMDHIP64_LIB} Threads::Threads)
endif()

set_target_properties(dambreak_hip_ok PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)



