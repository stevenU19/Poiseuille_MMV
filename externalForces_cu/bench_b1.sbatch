#!/bin/bash
#SBATCH --job-name=b1_nvprof
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=b1_nvprof.out

set -euo pipefail

# === Toolchain compatible con Tesla M2050 (Fermi) ===
module purge
module load devtools/gcc/5.3.0
module load devtools/cuda/8.0
module load cmake/3.15.4

cd "${SLURM_SUBMIT_DIR}"

# === Parámetros del benchmark ===
export BLOCKS="${BLOCKS:-128 256}"
export NPART="${NPART:-31600}"
export STEPS="${STEPS:-500}"

# === Salidas ===
RESULTS_CSV="results_b1_cuda.csv"
echo "backend,block_size,N,steps,time_ms,mpups" > "${RESULTS_CSV}"

# Perfilados nvprof irán a: nvprof_cuda_bs<BS>.csv
# (uno por cada tamaño de bloque)

for BS in ${BLOCKS}; do
  echo ">> Compilando (BS=${BS}) ..."
  BDIR="build_bs_${BS}"
  rm -rf "${BDIR}"

  cmake -S . -B "${BDIR}" -DCMAKE_BUILD_TYPE=Release \
        -DBLOCK_SIZE=${BS} -DNPART=${NPART} -DSTEPS=${STEPS}
  cmake --build "${BDIR}" -j

  echo ">> Ejecutando con nvprof (BS=${BS}) ..."
  # --csv: salida en formato CSV
  # --print-gpu-trace: tiempos por kernel
  # --log-file: guarda el trace en un archivo por BS
  nvprof --csv --print-gpu-trace \
         --log-file "nvprof_cuda_bs${BS}.csv" \
         "./${BDIR}/external_forces" 2>&1 | tee "run_bs${BS}.log"

  # Extraer métricas del stdout del programa
  # Ejemplo de línea: "Time=XXXX ms  MPUPS=YY.YY"
  tms=$(sed -n 's/.*Time=\([0-9.]\+\) ms.*/\1/p' "run_bs${BS}.log" | head -n1)
  mp=$(sed -n 's/.*MPUPS=\([0-9.]\+\).*/\1/p' "run_bs${BS}.log" | head -n1)
  tms=${tms:-0}; mp=${mp:-0}

  echo "cuda,${BS},${NPART},${STEPS},${tms},${mp}" | tee -a "${RESULTS_CSV}"
  echo ">> OK (BS=${BS})  time_ms=${tms}  mpups=${mp}"
done

echo "Hecho."
echo "- Resultados del programa: ${RESULTS_CSV}"
echo "- Traces nvprof por bloque: nvprof_cuda_bs*.csv"

