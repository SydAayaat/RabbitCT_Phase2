#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <optimization-name>" >&2
  echo "Example: $0 lolaasm-prefetch" >&2
  exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "ERROR: this is not a git repository" >&2
  exit 1
fi

name=$(printf '%s' "$1" | tr ' /' '__' | tr -cd 'A-Za-z0-9_.-')
ts=$(date +%Y%m%d_%H%M%S)
out="docs/diffs/${ts}_${name}.diff"

mkdir -p docs/diffs

git diff --check
git diff HEAD -- . > "$out"

if [ ! -s "$out" ]; then
  rm -f "$out"
  echo "No diff to save."
  exit 0
fi

echo "Saved diff: $out"
