#!/bin/bash
#SBATCH --job-name=b1_hip_prof_min
#SBATCH --gres=gpu:1
#SBATCH --time=00:20:00
#SBATCH --output=b1_hip_prof_min.out
set -Eeuo pipefail

module purge
module load cmake/3.24.2
module load gnu12/12.4.0
export PATH=/opt/rocm-6.4.3/llvm/bin:$PATH

cd "${SLURM_SUBMIT_DIR}"

# Asegura que el propio script no tenga CR (por si fue copiado con CRLF)
# (No falla si 'sed' no encuentra CR)
sed -i 's/\r$//' "${SLURM_SUBMIT_DIR}/bench_hip_prof_fixed_min.sbatch" || true

export BLOCKS="${BLOCKS:-128 256}"
export NPART="${NPART:-31600}"
export STEPS="${STEPS:-500}"
export REPS="${REPS:-3}"

echo "backend,block_size,run_idx,N,steps,time_ms,mpups" > results_b1_rocm_fixed.csv

rm -rf build_fixed
cmake -S . -B build_fixed -DCMAKE_BUILD_TYPE=Release -DBLOCK_SIZE=128 -DNPART=${NPART} -DSTEPS=${STEPS}
cmake --build build_fixed -j

for BS in ${BLOCKS}; do
  cmake -S . -B build_fixed -DCMAKE_BUILD_TYPE=Release \
        -DBLOCK_SIZE=${BS} -DNPART=${NPART} -DSTEPS=${STEPS} >/dev/null
  cmake --build build_fixed -j >/dev/null

  for r in $(seq 1 ${REPS}); do
    base="rocprof_bs${BS}_r${r}"
    out="${base}.csv"   # <-- si tu rocprof exige MAYÚSCULAS, cambia a .CSV

    # Debug: imprime el nombre exacto y su representación escapada (detecta \r)
    printf 'Archivo de salida para rocprof: "%s"\n' "$out"
    printf 'Escapado (debug): %q\n' "$out"

    echo ">> Ejecutando BLOCK_SIZE=${BS} (repetición ${r}) ..."
    rocprof --stats --timestamp on -o "$out" ./build_fixed/external_forces_fixed \
      | tee "${base}.run.log"

    # Extrae métricas del stdout del programa
    tms=$(sed -n 's/.*Time=\([0-9.]\+\) ms.*/\1/p' "${base}.run.log" | head -n1)
    mp=$(sed -n 's/.*MPUPS=\([0-9.]\+\).*/\1/p' "${base}.run.log" | head -n1)
    echo "rocm,${BS},${r},${NPART},${STEPS},${tms:-0},${mp:-0}" | tee -a results_b1_rocm_fixed.csv

    # Limpieza: solo dejamos .csv y el results global
    rm -f "${base}.db" "${base}.json" "${base}.sysinfo.txt" \
          "${base}.stats.csv" "${base}.hip"*.csv 2>/dev/null || true
  done
done

echo "OK. Conservados: results_b1_rocm_fixed.csv y rocprof_bs*_r*.csv"



