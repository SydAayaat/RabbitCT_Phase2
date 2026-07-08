#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_likwid
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=01:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/spr/%x-%j.log
#SBATCH --error=logs/spr/%x-%j.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV

REPO_DIR="${REPO_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "$REPO_DIR" || exit 1
mkdir -p logs/spr

ARCH=SPR
CORES=52
NUMAS=0-3
CPUSEL=S0:0-51
SIZE="${SIZE:-1024}"
VARIANTS="${VARIANTS:-LolaOMP LolaASM}"
GROUPS="${GROUPS:-MEM FLOPS_SP ENERGY}"
REBUILD="${REBUILD:-0}"

export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"
export TOOLCHAIN=AVX512-ICX
unset OMP_PLACES
unset OMP_PROC_BIND

printf '===== SPR FIXEDFREQ LIKWID START %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

printf '===== SETTINGS arch=%s fixed_freq=2.0GHz size=%s cores=%s numas=%s cpusel=%s groups="%s" rebuild=%s =====\n' "$ARCH" "$SIZE" "$CORES" "$NUMAS" "$CPUSEL" "$GROUPS" "$REBUILD"
hostname
date
lscpu | egrep 'Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true
which likwid-perfctr || true

if [ "$REBUILD" = "1" ] || [ ! -x ./rabbitRunner-AVX512-ICX ]; then
  echo "===== REBUILD ON SPR WITH ICX -xHost ====="
  scripts/utils/build_icx_avx512.sh
fi

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing. Run ./download-input.sh first."; exit 1; fi

for ALG in $VARIANTS; do
  for G in $GROUPS; do
    echo "===== FIXEDFREQ LIKWID SPR ${ALG} group=${G} size${SIZE} threads=${CORES} ====="
    srun --cpu-freq=2000000-2000000:performance \
         --ntasks=1 \
         --cpus-per-task=104 \
         --cpu-bind=none \
         likwid-perfctr -C $CPUSEL -g $G -O -- \
         numactl --cpunodebind=$NUMAS --interleave=$NUMAS \
         ./run-bench.sh -s "$SIZE" -v "$ALG"
  done
done

printf '===== SPR FIXEDFREQ LIKWID END %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"
