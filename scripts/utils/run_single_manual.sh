#!/bin/bash -l
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 LolaASM|LolaOMP [size]" >&2
  exit 1
fi

ALG="$1"
SIZE="${2:-1024}"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_DIR"

export TOOLCHAIN=AVX512-ICX
export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"

./run-bench.sh -s "$SIZE" -v "$ALG"
