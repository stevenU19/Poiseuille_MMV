# B1 – ExternalForces (HIP/ROCm, C++17) — Errores de estándar y solución

**Propósito.** Reproducir en HIP los errores de portabilidad de C++ al migrar desde un código CUDA/C++11:
- `std::auto_ptr` → eliminado en C++17
- `std::result_of` → obsoleto/remplazado por `std::invoke_result_t`
- `std::random_shuffle` → eliminado en C++17 (usar `std::shuffle`)

## Compilación
```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
# Compila dos targets:
# - external_forces_broken  (debe FALLAR con errores de C++17)
# - external_forces_fixed   (debe compilar y ejecutar)

