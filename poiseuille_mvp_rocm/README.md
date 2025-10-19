🚀 Poiseuille_MVP_ROCM
Modelo mínimo viable (ROCm) — Flujo de Poiseuille con SPH

Este proyecto implementa una versión reducida del método SPH (Smoothed Particle Hydrodynamics) para simular el flujo laminar de Poiseuille.
Corresponde al modelo mínimo viable (MVP) utilizado para evaluar la portabilidad y el rendimiento del método SPH al migrar desde CUDA (NVIDIA) hacia ROCm (AMD).


🧠 Objetivo

Validar experimentalmente la portabilidad funcional y física del método SPH sobre la arquitectura **AMD Instinct MI210**, utilizando el framework **ROCm/HIP**.
El propósito es comparar métricas de rendimiento con la versión CUDA, eliminando dependencias del ecosistema propietario de NVIDIA.

⚙️ Configuración del entorno (Cluster ROCm)

Para ejecutar correctamente el benchmark en el nodo GPU, se deben seguir los siguientes pasos.

1️⃣ Acceso al nodo
ssh guaneExa
srun --nodelist=ExaDELL --pty bash
salloc --gres=gpu:1 -n 128
ssh ExaDELL

2️⃣ Carga de módulos
module load cmake/3.24.2
module load gnu12/12.4.0

3️⃣ Variables de entorno ROCm

Configura el entorno de compilación de ROCm y las rutas a los módulos CMake del SDK HIP:

export HIP_DIR=/opt/rocm-6.3.0/lib/cmake/hip
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:/opt/rocm-6.3.0/lib/cmake/hip

export AMDDeviceLibs_DIR=/opt/rocm-6.3.0/lib/cmake/AMDDeviceLibs
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:/opt/rocm-6.3.0/lib/cmake/AMDDeviceLibs

export amd_comgr_DIR=/opt/rocm-6.3.0/lib/cmake/amd_comgr
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:/opt/rocm-6.3.0/lib/cmake/amd_comgr

export hsa_runtime64_DIR=/opt/rocm-6.3.0/lib/cmake/hsa-runtime64
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:/opt/rocm-6.3.0/lib/cmake/hsa-runtime64

export PATH=/opt/rocm-6.3.0/llvm/bin:$PATH
export LIBRARY_PATH=/opt/rocm-6.3.0/llvm/lib:$LIBRARY_PATH
export LD_LIBRARY_PATH=/opt/rocm-6.3.0/llvm/lib:$LD_LIBRARY_PATH
export C_INCLUDE_PATH=/opt/rocm-6.3.0/llvm/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=/opt/rocm-6.3.0/llvm/include:$CPLUS_INCLUDE_PATH

🧩 Estructura del proyecto
poiseuille_mvp/
├── src/
│   └── poiseuille.hip           # Código HIP (equivalente CUDA)
├── include/
│   └── sph_kernels.hpp          # Kernels SPH compartidos
├── CMakeLists.txt               # Configuración de build HIP/Clang
├── bench_mvp.sbatch             # Script de benchmark SLURM
├── results_rocm.csv             # Resultados de ejecución
└── README.md                    # Este archivo

🔧 Compilación manual

Compila el código usando hipcc (Clang):

cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j

Lo anterior genera el siguiente ejecutable:

build/poiseuille

🚀 Ejecución del benchmark

El benchmark puede ejecutarse mediante SLURM:

sbatch bench_mvp.sbatch


Este script:

Compila automáticamente para distintos tamaños de bloque (BLOCK_SIZE).

Ejecuta varias repeticiones (REPS=3).

Mide el tiempo total de ejecución y el rendimiento (MPUPS).

Registra la utilización de GPU (potencia, memoria, % uso).

📊 Resultados obtenidos

El archivo results_rocm.csv contiene las métricas de rendimiento por tamaño de bloque:

| Columna     | Descripción                                           |
|--------------|--------------------------------------------------------|
| backend      | Plataforma utilizada (CUDA)                           |
| block_size   | Tamaño de bloque usado en la GPU                      |
| run_idx      | Índice de repetición (por defecto 1–3)                |
| N            | Número total de partículas simuladas                  |
| steps        | Número de pasos de tiempo                             |
| time_ms      | Tiempo total de simulación en milisegundos            |
| mpups        | Millones de partículas procesadas por segundo         |

Ejemplo:

| backend | block_size | run_idx | N     | steps | time_ms | mpups |
|----------|-------------|---------|--------|--------|---------|--------|
| rocm     | 128         | 1       | 31600 | 500    | 1024.7  | 15.9   |
| rocm     | 256         | 1       | 31600 | 500    | 1086.5  | 14.8   |

🧮 Eficiencia y análisis

MPUPS mide directamente la eficiencia computacional.
	​

🧮 Datos de referencia de hardware

| GPU               | Arquitectura    | TFLOPs pico (FP32) | Ancho de banda | Año  |
|-------------------|-----------------|---------------------|----------------|------|
| AMD Instinct MI210 | CDNA2 (gfx90a) | 45.25               | 1.6 TB/s       | 2022 |

🧾 Autores

Proyecto desarrollado por:  
**Wilmer Farfán** y **Fabián Sánchez**  

Como parte del trabajo de grado titulado:  
> *“Análisis de la portabilidad de la implementación de métodos numéricos de hidrodinámica de partículas suaves en diferentes plataformas y frameworks CPU/GPU.”*
