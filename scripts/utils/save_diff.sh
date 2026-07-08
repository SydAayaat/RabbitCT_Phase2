#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <optimization-name>" >&2
  exit 1
fi

NAME="$1"
REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
cd "$REPO_DIR"

mkdir -p diffs
OUT="diffs/${NAME}.diff"

git diff -- src mk Makefile config.mk > "$OUT"

if [ ! -s "$OUT" ]; then
  echo "WARNING: diff is empty: $OUT" >&2
else
  echo "Wrote $OUT"
fi
