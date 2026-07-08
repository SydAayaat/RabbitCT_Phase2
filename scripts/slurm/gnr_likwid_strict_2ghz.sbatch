#!/bin/bash -l
#SBATCH --job-name=rabbitct_gnr_likwid
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --time=00:35:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/gnr/%x-%j.log
#SBATCH --error=logs/gnr/%x-%j.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV

REPO_DIR="${REPO_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "$REPO_DIR" || exit 1
mkdir -p logs/gnr

ARCH=GNR
CORES=86
NUMAS=0-1
CPULIST=0-85
SIZE="${SIZE:-1024}"
VARIANTS="${VARIANTS:-LolaOMP LolaASM}"
GROUPS="${GROUPS:-MEM FLOPS_SP ENERGY}"
REBUILD="${REBUILD:-0}"

export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"
export TOOLCHAIN=AVX512-ICX
unset OMP_PLACES
unset OMP_PROC_BIND

printf '===== GNR STRICT 2.0GHZ LIKWID START %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"

module purge
module load intel/2025.0.0 likwid/5.5.1
module list

printf '===== SETTINGS arch=%s requested_fixed_freq=2.0GHz size=%s cores=%s numas=%s cpulist=%s groups="%s" rebuild=%s =====\n' "$ARCH" "$SIZE" "$CORES" "$NUMAS" "$CPULIST" "$GROUPS" "$REBUILD"
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true
which likwid-perfctr || true

if [ -n "${SLURM_JOB_ID:-}" ]; then
  echo "===== SLURM JOB INFO ====="
  scontrol show job "$SLURM_JOB_ID" | egrep -i 'CpuFreq|NumCPUs|TRES|NodeList|Command|RunTime|TimeLimit|Partition|ReqNodeList|Features|OverSubscribe' || true
fi

if [ "$REBUILD" = "1" ] || [ ! -x ./rabbitRunner-AVX512-ICX ]; then
  echo "===== REBUILD ON GNR WITH ICX -xHost ====="
  scripts/utils/build_icx_avx512.sh
fi

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing. Run ./download-input.sh first."; exit 1; fi

for ALG in $VARIANTS; do
  for G in $GROUPS; do
    echo "===== STRICT2GHZ LIKWID GNR ${ALG} group=${G} size${SIZE} threads=${CORES} ====="
    srun --cpu-freq=2000000-2000000:performance \
         --ntasks=1 \
         --cpus-per-task=172 \
         --cpu-bind=none \
         bash -lc "echo STEP_HOST=\$(hostname); echo SLURM_CPU_FREQ_REQ=\${SLURM_CPU_FREQ_REQ:-not_set}; echo '--- cpufreq sample before ---'; for C in 0 42 43 85; do echo -n cpu\$C' '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_governor 2>/dev/null || true; echo -n cpu\$C'_cur '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_cur_freq 2>/dev/null || true; done; export TOOLCHAIN=AVX512-ICX OMP_NUM_THREADS=$CORES OMP_STACKSIZE=$OMP_STACKSIZE; unset OMP_PLACES OMP_PROC_BIND; likwid-perfctr -C $CPULIST -g $G -O -- numactl --physcpubind=$CPULIST --membind=$NUMAS ./run-bench.sh -s $SIZE -v $ALG"
  done
done

printf '===== GNR STRICT 2.0GHZ LIKWID END %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"
