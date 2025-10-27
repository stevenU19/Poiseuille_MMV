#!/bin/bash
#SBATCH --job-name=bench_mvp_rocprof
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=bench_mvp_rocprof.out
set -euo pipefail

# === Entorno ROCm 6.4.x ===
module purge
module load cmake/3.24.2
module load gnu12/12.4.0
export PATH=/opt/rocm-6.4.3/llvm/bin:$PATH
export HIP_PLATFORM=amd
export HIP_PATH=/opt/rocm-6.4.3
export CMAKE_PREFIX_PATH=$CMAKE_PREFIX_PATH:/opt/rocm-6.4.3/lib/cmake

cd "${SLURM_SUBMIT_DIR}"

# === Variables del benchmark ===
export REPS=${REPS:-3}
export BLOCKS="${BLOCKS:-128 256}"
export WRITE_PROFILE=${WRITE_PROFILE:-0}
export YBINS=${YBINS:-64}
export BACKEND="rocm"

# === Archivo principal de resultados ===
echo "backend,block_size,run_idx,N,steps,time_ms,mpups" > results_rocm.csv

# === Compilación base ===
rm -rf build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBLOCK_SIZE=128 -DWRITE_PROFILE=${WRITE_PROFILE} -DYBINS=${YBINS} >/dev/null
cmake --build build -j >/dev/null

# === Ejecución con rocprof ===
for BS in ${BLOCKS}; do
  echo ">> Compilando BLOCK_SIZE=${BS} ..."
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBLOCK_SIZE=${BS} -DWRITE_PROFILE=${WRITE_PROFILE} -DYBINS=${YBINS} >/dev/null
  cmake --build build -j >/dev/null

  for r in $(seq 1 ${REPS}); do
    OUTCSV="rocprof_bs${BS}_r${r}.csv"
    echo ">> rocprof -> ${OUTCSV}"

    # Captura de métricas a nivel de kernel (sin JSON/DB)
    rocprof --stats --timestamp on -o "${OUTCSV}" ./build/poiseuille || true

    # Extraer métricas del programa (tiempo total / MPUPS)
    OUT=$(grep -E "N=|steps=|Time=|MPUPS=" "${OUTCSV}" || true)
    N=$(echo "$OUT" | sed -n 's/.*N=\([0-9]\+\).*/\1/p' | head -n1)
    steps=$(echo "$OUT" | sed -n 's/.*steps=\([0-9]\+\).*/\1/p' | head -n1)
    tms=$(echo "$OUT" | sed -n 's/.*Time=\([0-9.]\+\) ms.*/\1/p' | head -n1)
    mp=$(echo "$OUT" | sed -n 's/.*MPUPS=\([0-9.]\+\).*/\1/p' | head -n1)
    N=${N:-0}; steps=${steps:-0}; tms=${tms:-0}; mp=${mp:-0}
    echo "${BACKEND},${BS},${r},${N},${steps},${tms},${mp}" >> results_rocm.csv
    echo "ROCm BS=${BS} run=${r} -> ${tms} ms  ${mp} MPUPS"

    # Limpieza de archivos secundarios (dejamos solo .csv)
    rm -f "${OUTCSV%.csv}.db" "${OUTCSV%.csv}.json" "${OUTCSV%.csv}.sysinfo.txt" \
          "${OUTCSV%.csv}.stats.csv" 2>/dev/null || true
  done
done

echo "? Benchmark completado. Archivos generados:"
echo "  - results_rocm.csv      (métricas globales)"
echo "  - rocprof_bs*_r*.csv    (profiling kernel-level limpio)"

