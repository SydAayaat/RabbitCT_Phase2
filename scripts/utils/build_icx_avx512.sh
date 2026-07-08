#!/bin/bash -l
set -euo pipefail

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_DIR"

if ! command -v icx >/dev/null 2>&1; then
  echo "ERROR: icx not found. Load an Intel module first, e.g.:" >&2
  echo "  module load intel/2023.2.1 likwid/5.5.1   # SPR" >&2
  echo "  module load intel/2025.0.0 likwid/5.5.1   # GNR" >&2
  exit 1
fi

if [ "${ENABLE_MODULE_INFO:-1}" = "1" ]; then
  echo "===== MODULES ====="
  module list 2>&1 || true
  echo "===== COMPILER ====="
  icx --version || true
  echo "LIKWID_INCDIR=${LIKWID_INCDIR:-not_set}"
  echo "LIKWID_LIBDIR=${LIKWID_LIBDIR:-not_set}"
fi

make distclean || true
make TOOLCHAIN=ICX \
     ENABLE_OPENMP=true \
     ENABLE_LIKWID=true \
     ENABLE_ISPC=false \
     SIMD=AVX512 \
     LIKWID_INC="-I${LIKWID_INCDIR:-/usr/local/include}" \
     LIKWID_LIB="-L${LIKWID_LIBDIR:-/usr/local/lib}"

ls -lh rabbitRunner-AVX512-ICX
