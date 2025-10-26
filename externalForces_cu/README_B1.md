# B1 – ExternalForces (CUDA, C++11) → Errores de estándar al portar a HIP

**Propósito.** Modelo mínimo que compila y corre en CUDA (C++11), pero al migrarlo a HIP/ROCm (C++17/20) provoca **errores de estándar** reproducibles:
- `std::auto_ptr` (eliminado en C++17)
- `std::result_of` (obsoleto; reemplazo: `std::invoke_result_t`)
- `std::random_shuffle` (eliminado en C++17; usar `std::shuffle`)

## Compilación y ejecución en CUDA
```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/external_forces
# o con SLURM:
sbatch bench_b1.sbatch
