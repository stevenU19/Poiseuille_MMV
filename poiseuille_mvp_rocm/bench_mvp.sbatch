#!/bin/bash
#SBATCH --job-name=bench_mvp_rocm
#SBATCH --gres=gpu:1
#SBATCH --time=00:30:00
#SBATCH --output=bench_mvp_rocm.out



cd "${SLURM_SUBMIT_DIR}"

# Variables del benchmark
export REPS=${REPS:-3}
export BLOCKS="${BLOCKS:-128 256 384 512}"
export WRITE_PROFILE=${WRITE_PROFILE:-0}
export YBINS=${YBINS:-64}
export BACKEND="rocm"

# HIP backend (amd/nvidia) - por defecto AMD:
export HIP_PLATFORM=${HIP_PLATFORM:-amd}

# Hints para CMake si el package hip no aparece
export CMAKE_PREFIX_PATH=${CMAKE_PREFIX_PATH:-/opt/rocm:/opt/rocm/hip}
export HIP_PATH=${HIP_PATH:-/opt/rocm}

echo "backend,block_size,run_idx,N,steps,time_ms,mpups" > results_rocm.csv

for BS in ${BLOCKS}; do
  echo ">> Compilando BLOCK_SIZE=$BS ..."
  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBLOCK_SIZE=${BS} -DWRITE_PROFILE=${WRITE_PROFILE} -DYBINS=${YBINS} >/dev/null
  cmake --build build -j >/dev/null

  # Monitor rocm-smi
  if command -v rocm-smi >/dev/null 2>&1; then
    if rocm-smi --help 2>/dev/null | grep -qi -- "--json"; then
      rocm-smi --json --interval 1000 > "util_rocm_BS${BS}.json" &
      MON_PID=$!
    else
      rocm-smi --showuse --showmemuse --showpower --interval 1000 > "util_rocm_BS${BS}.log" &
      MON_PID=$!
    fi
  fi

  for r in $(seq 1 ${REPS}); do
    OUT=$(./build/poiseuille || true)
    N=$(echo "$OUT" | sed -n 's/.*N=\([0-9]\+\).*/\1/p' | head -n1)
    steps=$(echo "$OUT" | sed -n 's/.*steps=\([0-9]\+\).*/\1/p' | head -n1)
    tms=$(echo "$OUT" | sed -n 's/.*Time=\([0-9.]\+\) ms.*/\1/p' | head -n1)
    mp=$(echo "$OUT" | sed -n 's/.*MPUPS=\([0-9.]\+\).*/\1/p' | head -n1)
    N=${N:-0}; steps=${steps:-0}; tms=${tms:-0}; mp=${mp:-0}
    echo "${BACKEND},${BS},${r},${N},${steps},${tms},${mp}" >> results_rocm.csv
    echo "ROCm BS=${BS} run=${r} -> ${tms} ms  ${mp} MPUPS"
  done

  if [[ -n "${MON_PID:-}" ]]; then
    kill "${MON_PID}" >/dev/null 2>&1 || true
  fi
done

echo "OK. Resultados en results_rocm.csv y util_rocm_BS*.log/.json"
