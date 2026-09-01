#!/usr/bin/env bash
# ==============================================================================
# watch.sh
# Recompila y corre los tests automáticamente cada vez que un fichero fuente
# cambia. Requiere haber ejecutado ./scripts/configure.sh al menos una vez
# para el preset indicado.
#
# Uso: ./scripts/watch.sh [preset]
#   [preset]   debug | release | coverage | valgrind   (default: debug)
# ==============================================================================
set -euo pipefail

PRESET="${1:-debug}"

if [[ ! -d "temp/build/${PRESET}" ]]; then
    echo "❌ temp/build/${PRESET} no existe. Ejecuta primero: ./scripts/configure.sh ${PRESET}" >&2
    exit 1
fi

echo "==> Vigilando cambios en inc/, src/, app/, test/ (preset: ${PRESET})"
echo "==> Ctrl+C para salir"

find inc src app test -name "*.cpp" -o -name "*.hpp" | \
    entr -c bash -c "cmake --build --preset ${PRESET} && ctest --preset ${PRESET} --output-on-failure"
