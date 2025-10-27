#!/bin/bash
#SBATCH --job-name=dambreak_local
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --output=slurm-%j.out

# ========================================================
#  CONFIGURACIÓN LOCAL
# ========================================================
ROCM_PATH="/opt/rocm-6.4.3"
BASE_DIR=$(pwd)
BUILD_DIR="${BASE_DIR}/build"
APP="${BUILD_DIR}/bin/dambreak_hip_ok"
RESULTS_DIR="${BASE_DIR}/results"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${RESULTS_DIR}/run_${DATE_TAG}"

mkdir -p "${RUN_DIR}"

echo "===> Ejecutando en: ${BASE_DIR}"
echo "===> Resultados en: ${RUN_DIR}"
echo "===> Binario esperado: ${APP}"

# ========================================================
#  ENTORNO ROCm
# ========================================================
export PATH="${ROCM_PATH}/bin:${ROCM_PATH}/lib/llvm/bin:${PATH}"
export LD_LIBRARY_PATH="${ROCM_PATH}/lib:${ROCM_PATH}/lib64:${LD_LIBRARY_PATH}"
export HIP_VISIBLE_DEVICES=0
export HSA_ENABLE_SDMA=1

echo "===> Versión de HIP:"
hipconfig --version || echo "hipconfig no encontrado"

# ========================================================
#  COMPILACIÓN AUTOMÁTICA (si no existe binario)
# ========================================================
if [[ ! -f "${APP}" ]]; then
  echo "===> Compilando proyecto dambreak_hip_ok..."
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"
  cmake -DCMAKE_BUILD_TYPE=Release ..
  cmake --build . -j
  cd "${BASE_DIR}"
else
  echo "===> Binario ya existe."
fi

if [[ ! -f "${APP}" ]]; then
  echo "? Error: no se generó el binario dambreak_hip_ok en ${APP}"
  exit 1
fi

# ========================================================
#  EJECUCIÓN CON ROCPROF
# ========================================================
echo "===> Ejecutando con rocprof..."
cd "${RUN_DIR}"

"${ROCM_PATH}/bin/rocprof" \
  --hip-trace \
  --hsa-trace \
  --roctx-trace \
  --stats \
  -o dambreak_trace.csv \
  "${APP}" | tee dambreak_output.log

# ========================================================
#  RESUMEN DE RESULTADOS
# ========================================================
if [[ -f dambreak_trace.csv ]]; then
  TOTAL_TIME=$(grep -i "Total time" dambreak_trace.csv | awk -F',' '{print $2}' | head -n1)
  KERNELS=$(grep -ci "kernel" dambreak_trace.csv)
  echo "Fecha,Tiempo_total(s),Kernels" > summary.csv
  echo "${DATE_TAG},${TOTAL_TIME:-NA},${KERNELS}" >> summary.csv
fi

cd "${BASE_DIR}"

# ========================================================
#  SALIDA FINAL
# ========================================================
echo ""
echo "========================================================"
echo "   EJECUCIÓN FINALIZADA — DAMBREAK HIP"
echo "========================================================"
echo "Directorio de resultados: ${RUN_DIR}"
echo ""
echo "Archivos generados:"
ls -1 "${RUN_DIR}"
echo ""
echo "Vista previa de summary.csv:"
cat "${RUN_DIR}/summary.csv" 2>/dev/null || echo "summary.csv no encontrado"
echo "========================================================"


