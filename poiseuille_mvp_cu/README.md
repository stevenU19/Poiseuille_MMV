# 🚀 Poiseuille_MVP_CU
**Modelo mínimo viable (CUDA) — Flujo de Poiseuille con SPH**

Este proyecto implementa una versión reducida del método **SPH (Smoothed Particle Hydrodynamics)** para simular el flujo laminar de Poiseuille.  
Corresponde al **modelo mínimo viable (MVP)** empleado para evaluar la portabilidad y rendimiento entre **CUDA (NVIDIA)** y **ROCm (AMD)**.

---

## 🧠 Objetivo

Evaluar comparativamente el desempeño y la coherencia física del método SPH en arquitecturas GPU diferentes, conservando el mismo código base.  
Esta versión está optimizada para **GPUs NVIDIA Tesla M2050 (arquitectura Fermi)** usando **CUDA 9.1**.

---

## ⚙️ Configuración del entorno

Antes de compilar y ejecutar, se deben cargar los siguientes módulos:

```bash
module load devtools/gcc/6.2.0
module load devtools/cuda/9.1
module load cmake/3.15.4
```

Variables de entorno recomendadas:

```bash
export CC=gcc
export CXX=g++
export CUDAHOSTCXX=g++
```

---

## 🧩 Estructura del proyecto

```
poiseuille_mvp_cu/
├── src/
│   └── poiseuille.cu           # Código fuente CUDA
├── include/
│   └── sph_kernels.hpp         # Definiciones de kernels SPH
├── CMakeLists.txt              # Configuración del compilador y flags
├── bench_mvp.sbatch            # Script SLURM para ejecutar benchmarks
├── results_CU.csv              # Resultados de ejecución (métricas principales)
└── README.md                   # Este archivo
```

---

## 🔧 Compilación manual

Para compilar el binario, ejecuta los siguientes comando de cmake:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
```

Lo anterior genera el siguiente ejecutable:

```
build/poiseuille
```

---

## 🚀 Ejecución del benchmark (entorno SLURM)

Ejecutar en un nodo GPU:

```bash
srun --gres=gpu:1 --pty bash
```

Dentro del nodo:

```bash
module load devtools/gcc/6.2.0
module load devtools/cuda/9.1
module load cmake/3.15.4
export CC=gcc
export CXX=g++
export CUDAHOSTCXX=g++
```

Luego se ejecuta el script del benchmark:

```bash
sbatch bench_mvp.sbatch
```

---

## 📊 Resultados

El archivo `results_CU.csv` contiene los resultados promediados por bloque, con las siguientes columnas:

| Columna     | Descripción                                           |
|--------------|--------------------------------------------------------|
| backend      | Plataforma utilizada (CUDA)                           |
| block_size   | Tamaño de bloque usado en la GPU                      |
| run_idx      | Índice de repetición (por defecto 1–3)                |
| N            | Número total de partículas simuladas                  |
| steps        | Número de pasos de tiempo                             |
| time_ms      | Tiempo total de simulación en milisegundos            |
| mpups        | Millones de partículas procesadas por segundo         |

**Ejemplo:**

| backend | block_size | run_idx | N     | steps | time_ms  | mpups |
|----------|-------------|---------|--------|--------|-----------|--------|
| cuda     | 128         | 1       | 31600 | 500    | 23198.5   | 0.68   |
| cuda     | 256         | 1       | 31600 | 500    | 23475.2   | 0.66   |

---

## 📈 Análisis posterior

Los resultados se analizan junto con la versión HIP/ROCm (`poiseuille_mvp`) para:

- Calcular promedios y desviaciones por `block_size`.  
- Graficar **MPUPS vs BLOCK_SIZE**.  
- Comparar eficiencia relativa entre CUDA y ROCm.  
- Incorporar normalización por **TFLOPs teóricos** para métricas comparables entre arquitecturas.

---

## 🧮 Datos de referencia

| GPU                | Arquitectura   | TFLOPs pico (FP32) | Ancho de banda | Año  |
|--------------------|----------------|---------------------|----------------|------|
| NVIDIA Tesla M2050 | Fermi (SM 2.0) | 1.03                | 148 GB/s       | 2010 |

---

## 🧾 Autores

Proyecto desarrollado por:  
**Wilmer Farfán** y **Fabián Sánchez**  

Como parte del trabajo de grado titulado:  
> *“Análisis de la portabilidad de la implementación de métodos numéricos de hidrodinámica de partículas suaves en diferentes plataformas y frameworks CPU/GPU.”*


