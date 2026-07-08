#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if ! command -v icx >/dev/null 2>&1; then
  echo "ERROR: icx not found. Load Intel first, e.g.: module load intel/2023.2.1" >&2
  exit 1
fi

echo "===== BUILD ICX AVX512 START $(date) HOST=$(hostname) ====="
icx --version | head -n 2

make clean TOOLCHAIN=ICX SIMD=AVX512 ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false
make -j "${MAKE_JOBS:-8}" TOOLCHAIN=ICX SIMD=AVX512 ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false

test -x ./rabbitRunner-AVX512-ICX || { echo "ERROR: rabbitRunner-AVX512-ICX was not created" >&2; exit 1; }

ls -lh ./rabbitRunner-AVX512-ICX

echo "===== BUILD ICX AVX512 END $(date) HOST=$(hostname) ====="
