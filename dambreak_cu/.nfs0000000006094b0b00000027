#!/bin/bash
#SBATCH --job-name=dambreak_cuda_prof
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --output=slurm-%j.out

# ========================================================
#  MÓDULOS / ENTORNO
# ========================================================
module purge
module load devtools/gcc/5.3.0
module load devtools/cuda/8.0
module load cmake/3.15.4

BASE_DIR="$(pwd)"
BUILD_DIR="${BASE_DIR}/build"
APP="${BUILD_DIR}/bin/dambreak_cuda_ref"   # nombre del binario del CMake que te pasé
RESULTS_DIR="${BASE_DIR}/results_cuda"
DATE_TAG=$(date +%Y%m%d_%H%M%S)
RUN_DIR="${RESULTS_DIR}/run_${DATE_TAG}"

mkdir -p "${RUN_DIR}"

echo "===> BASE_DIR=${BASE_DIR}"
echo "===> BUILD_DIR=${BUILD_DIR}"
echo "===> APP=${APP}"
echo "===> RUN_DIR=${RUN_DIR}"

echo "===> nvcc:"
nvcc --version || echo "nvcc no disponible"
echo "===> nvprof:"
nvprof --version || echo "nvprof no disponible"

# ========================================================
#  COMPILACIÓN (si no existe)
# ========================================================
if [[ ! -f "${APP}" ]]; then
  echo "===> Compilando proyecto (Release)..."
  rm -rf "${BUILD_DIR}"
  mkdir -p "${BUILD_DIR}" && cd "${BUILD_DIR}"
  # Ajusta -DCUDA_ARCH si tu GPU es distinta (p.ej., 61)
  cmake -DCMAKE_BUILD_TYPE=Release -DCUDA_ARCH=60 ..
  cmake --build . -j
  cd "${BASE_DIR}"
else
  echo "===> Binario existente: ${APP}"
fi

if [[ ! -f "${APP}" ]]; then
  echo "? Error: no se generó el binario en ${APP}"
  exit 1
fi

# ========================================================
#  EJECUCIÓN + NVPROF (CSV)
# ========================================================
cd "${RUN_DIR}"

# --print-gpu-trace: actividades GPU detalladas
# --csv + --log-file: volcamos todo a CSV (en un solo archivo)
echo "===> Ejecutando con nvprof (CSV)..."
nvprof \
  --print-gpu-trace \
  --csv \
  --log-file dambreak_trace.csv \
  "${APP}" | tee dambreak_output.log

# ========================================================
#  POST: RESUMEN RÁPIDO EN CSV
#   nvprof --csv genera encabezados y varias secciones.
#   Extraemos:
#     - Nº de filas de traza GPU (~ #actividades)
#     - “Tiempo total” (si aparece en el CSV textual)
# ========================================================
echo "===> Generando summary.csv..."
KERNEL_ROWS=0
TOTAL_TIME="NA"

# Conteo simple de filas “útiles” (ignora encabezados/comentarios)
if [[ -f dambreak_trace.csv ]]; then
  # Filas no vacías que no comienzan con '#', ni contienen 'Start' (header), ni 'GPU activities' (sección)
  KERNEL_ROWS=$(awk -F',' 'NF>5 && $0 !~ /^#/ && tolower($0) !~ /start/ && tolower($0) !~ /gpu activities/' dambreak_trace.csv | wc -l | tr -d ' ')
  # Intento de extraer una línea con "Total" (si nvprof incluye ese resumen en este CSV)
  TOTAL_TIME_LINE=$(grep -i "total" dambreak_trace.csv | head -n1)
  if [[ -n "$TOTAL_TIME_LINE" ]]; then
    # Toma el último campo como estimación (suele ser duración/tiempo)
    TOTAL_TIME=$(echo "$TOTAL_TIME_LINE" | awk -F',' '{print $NF}')
  fi
fi

echo "Fecha,Tiempo_total,Kernels" > summary.csv
echo "${DATE_TAG},${TOTAL_TIME},${KERNEL_ROWS}" >> summary.csv

cd "${BASE_DIR}"

# ========================================================
#  SALIDA FINAL
# ========================================================
echo ""
echo "========================================================"
echo "   EJECUCIÓN FINALIZADA — DAMBREAK CUDA (nvprof)"
echo "========================================================"
echo "Directorio de resultados: ${RUN_DIR}"
echo ""
echo "Archivos generados:"
ls -1 "${RUN_DIR}"
echo ""
echo "Vista previa summary.csv:"
cat "${RUN_DIR}/summary.csv" 2>/dev/null || echo "summary.csv no encontrado"
echo "========================================================"



