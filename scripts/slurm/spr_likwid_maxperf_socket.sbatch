#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_likwid_maxperf
#SBATCH --partition=work
#SBATCH --nodelist=saprap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
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
NODE_NAME=saprap2
SIZE="${SIZE:-1024}"
VARIANTS="${VARIANTS:-LolaOMP LolaASM}"
GROUPS="${GROUPS:-MEM FLOPS_SP ENERGY}"
REBUILD="${REBUILD:-0}"
USE_SMT="${USE_SMT:-1}"
CPU_FREQ="${CPU_FREQ:-high:performance}"

export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"
export TOOLCHAIN=AVX512-ICX
unset OMP_PLACES
unset OMP_PROC_BIND

make_csv() { paste -sd, -; }

detect_socket0() {
  local map
  if [ "$USE_SMT" = "1" ]; then
    map=$(lscpu -p=CPU,SOCKET,NODE 2>/dev/null | awk -F, '$0 !~ /^#/ && $2 == 0 {print $1","$3}')
  else
    map=$(lscpu -p=CPU,SOCKET,CORE,NODE 2>/dev/null | awk -F, '$0 !~ /^#/ && $2 == 0 && !seen[$3]++ {print $1","$4}')
  fi
  SOCKET0_CPUS=$(printf '%s\n' "$map" | cut -d, -f1 | sed '/^$/d' | make_csv)
  SOCKET0_NUMAS=$(printf '%s\n' "$map" | cut -d, -f2 | sed '/^$/d' | sort -n -u | make_csv)
  NTHREADS=$(printf '%s' "$SOCKET0_CPUS" | tr ',' '\n' | sed '/^$/d' | wc -l)
  if [ -z "${SOCKET0_CPUS:-}" ] || [ "$NTHREADS" -eq 0 ]; then
    echo "ERROR: Could not detect socket 0 CPU list from lscpu" >&2
    exit 1
  fi
}

printf '===== SPR MAXPERF SINGLE-SOCKET LIKWID START %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

detect_socket0
export OMP_NUM_THREADS="$NTHREADS"
SRUN_CPUS="${SRUN_CPUS:-${SLURM_CPUS_ON_NODE:-$NTHREADS}}"
SRUN_FREQ_ARGS=()
if [ "$CPU_FREQ" != "none" ]; then SRUN_FREQ_ARGS=(--cpu-freq="$CPU_FREQ"); fi

printf '===== SETTINGS arch=%s node=%s freq_request=%s size=%s use_smt=%s omp_threads=%s socket0_cpus=%s socket0_numas=%s groups="%s" rebuild=%s =====\n' \
  "$ARCH" "$NODE_NAME" "$CPU_FREQ" "$SIZE" "$USE_SMT" "$NTHREADS" "$SOCKET0_CPUS" "$SOCKET0_NUMAS" "$GROUPS" "$REBUILD"
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-9]+ cpus|node distances' || true
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
    echo "===== MAXPERF LIKWID SPR ${ALG} group=${G} size${SIZE} threads=${NTHREADS} use_smt=${USE_SMT} ====="
    srun "${SRUN_FREQ_ARGS[@]}" \
         --ntasks=1 \
         --cpus-per-task="$SRUN_CPUS" \
         --cpu-bind=none \
         likwid-perfctr -C "$SOCKET0_CPUS" -g "$G" -O -- \
         numactl --physcpubind="$SOCKET0_CPUS" --membind="$SOCKET0_NUMAS" \
         ./run-bench.sh -s "$SIZE" -v "$ALG"
  done
done

printf '===== SPR MAXPERF SINGLE-SOCKET LIKWID END %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"
