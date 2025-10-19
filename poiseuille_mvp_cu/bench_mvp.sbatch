#!/bin/bash
#SBATCH --job-name=bench_mvp
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=bench_mvp.out

set -euo pipefail

module purge
module load devtools/gcc/5.3.0
module load devtools/cuda/8.0
module load cmake/3.15.4

cd "${SLURM_SUBMIT_DIR}"

export REPS="${REPS:-3}"
export BLOCKS="${BLOCKS:-128 256}"
export WRITE_PROFILE="${WRITE_PROFILE:-0}"
export YBINS="${YBINS:-64}"
export BACKEND="cuda"

echo "backend,block_size,run_idx,N,steps,time_ms,mpups" > results.csv

for BS in ${BLOCKS}; do
  echo ">> Compilando BLOCK_SIZE=${BS} ..."
  BUILDDIR="build_bs_${BS}"
  rm -rf "${BUILDDIR}"
  cmake -S . -B "${BUILDDIR}" -DCMAKE_BUILD_TYPE=Release -DBLOCK_SIZE="${BS}" -DWRITE_PROFILE="${WRITE_PROFILE}" -DYBINS="${YBINS}"
  cmake --build "${BUILDDIR}" -j

  # --- Monitor GPU compatible con Fermi ---
  MON_PID=""
  # 1) intenta dmon (puede NO estar soportado en driver 390/M2050)
  if nvidia-smi dmon -h >/dev/null 2>&1; then
    ( nvidia-smi dmon -s pucm -d 1 -o DT > "util_cuda_BS${BS}.log" ) & MON_PID=$! || MON_PID=""
    # si el primer muestreo imprime "Not supported..." y termina, MON_PID quedará vacío
    sleep 1
    if ! kill -0 "${MON_PID}" >/dev/null 2>&1; then
      MON_PID=""
    fi
  fi
  # 2) fallback estable para Fermi: query CSV por segundo
  if [[ -z "${MON_PID}" ]]; then
    ( nvidia-smi --query-gpu=timestamp,index,name,utilization.gpu,utilization.memory,memory.used \
                 --format=csv -l 1 > "util_cuda_BS${BS}.csv" ) & MON_PID=$! || MON_PID=""
    sleep 1
  fi

  # --- Ejecución y parseo ---
  for r in $(seq 1 "${REPS}"); do
    OUT=$("./${BUILDDIR}/poiseuille" || true)
    N=$(echo "$OUT" | sed -n 's/.*N=\([0-9]\+\).*/\1/p' | head -n1)
    steps=$(echo "$OUT" | sed -n 's/.*steps=\([0-9]\+\).*/\1/p' | head -n1)
    tms=$(echo "$OUT" | sed -n 's/.*Time=\([0-9.]\+\) ms.*/\1/p' | head -n1)
    mp=$(echo "$OUT" | sed -n 's/.*MPUPS=\([0-9.]\+\).*/\1/p' | head -n1)
    N=${N:-0}; steps=${steps:-0}; tms=${tms:-0}; mp=${mp:-0}
    echo "${BACKEND},${BS},${r},${N},${steps},${tms},${mp}" | tee -a results.csv
    echo "CUDA BS=${BS} run=${r} -> ${tms} ms  ${mp} MPUPS"
  done

  # detener monitor si estaba activo
  if [[ -n "${MON_PID}" ]]; then
    kill "${MON_PID}" >/dev/null 2>&1 || true
  fi
done

echo "OK. Resultados en results.csv y util_cuda_BS*.log/.csv"


