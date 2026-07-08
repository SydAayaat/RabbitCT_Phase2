#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  cat >&2 <<'USAGE'
Usage: scripts/slurm/submit_phase2_baseline.sh <target>

Targets:
  spr-runtime
  spr-likwid
  spr-maqao
  gnr-runtime
  gnr-likwid
  gnr-maqao
  all-runtime
  all-likwid
  all-maqao
USAGE
  exit 1
fi

case "$1" in
  spr-runtime) sbatch scripts/slurm/spr_runtime_fixedfreq.sbatch ;;
  spr-likwid)  sbatch scripts/slurm/spr_likwid_fixedfreq.sbatch ;;
  spr-maqao)   sbatch scripts/slurm/spr_maqao.sbatch ;;
  gnr-runtime) sbatch scripts/slurm/gnr_runtime_fixedfreq.sbatch ;;
  gnr-likwid)  sbatch scripts/slurm/gnr_likwid_strict_2ghz.sbatch ;;
  gnr-maqao)   sbatch scripts/slurm/gnr_maqao.sbatch ;;
  all-runtime)
    sbatch scripts/slurm/spr_runtime_fixedfreq.sbatch
    sbatch scripts/slurm/gnr_runtime_fixedfreq.sbatch
    ;;
  all-likwid)
    sbatch scripts/slurm/spr_likwid_fixedfreq.sbatch
    sbatch scripts/slurm/gnr_likwid_strict_2ghz.sbatch
    ;;
  all-maqao)
    sbatch scripts/slurm/spr_maqao.sbatch
    sbatch scripts/slurm/gnr_maqao.sbatch
    ;;
  *) echo "Unknown target: $1" >&2; exit 1 ;;
esac
