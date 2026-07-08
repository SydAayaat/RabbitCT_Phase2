#!/bin/bash -l
#SBATCH --job-name=rabbitct_gnr_2ghz_likwid
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --time=00:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=GNR_logs/GNR_FIXEDFREQ_2GHZ_LIKWID.log
#SBATCH --error=GNR_logs/GNR_FIXEDFREQ_2GHZ_LIKWID.log
#SBATCH --open-mode=truncate

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1
mkdir -p GNR_logs

echo "===== GNR STRICT 2.0GHZ LIKWID START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2025.0.0 likwid/5.5.1
module list

export TOOLCHAIN=AVX512-ICX
export CORES=86
export NUMAS=0-1
export CPULIST=0-85
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== SETTINGS requested_fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPULIST=$CPULIST TOOLCHAIN=$TOOLCHAIN ====="
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true
which likwid-perfctr || true

echo "===== SLURM JOB INFO ====="
scontrol show job "$SLURM_JOB_ID" | egrep -i 'CpuFreq|NumCPUs|TRES|NodeList|Command|RunTime|TimeLimit|Partition|ReqNodeList|Features|OverSubscribe' || true

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi

run_likwid () {
  ALG="$1"
  G="$2"
  echo "===== STRICT2GHZ LIKWID GNR ${ALG} group=${G} size1024 threads=${CORES} ====="
  srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none bash -lc "echo STEP_HOST=\$(hostname); echo SLURM_CPU_FREQ_REQ=\${SLURM_CPU_FREQ_REQ:-not_set}; echo '--- cpufreq sample before ---'; for C in 0 42 43 85; do echo -n cpu\$C' '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_governor 2>/dev/null || true; echo -n cpu\$C'_cur '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_cur_freq 2>/dev/null || true; echo -n cpu\$C'_min '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_min_freq 2>/dev/null || true; echo -n cpu\$C'_max '; cat /sys/devices/system/cpu/cpu\$C/cpufreq/scaling_max_freq 2>/dev/null || true; done; export TOOLCHAIN=AVX512-ICX OMP_NUM_THREADS=$CORES OMP_STACKSIZE=64M; unset OMP_PLACES OMP_PROC_BIND; likwid-perfctr -C $CPULIST -g $G -O -- numactl --physcpubind=$CPULIST --membind=$NUMAS ./run-bench.sh -s 1024 -v $ALG"
}

run_likwid LolaOMP MEM
run_likwid LolaOMP FLOPS_SP
run_likwid LolaOMP ENERGY
run_likwid LolaASM MEM
run_likwid LolaASM FLOPS_SP
run_likwid LolaASM ENERGY

echo "===== GNR STRICT 2.0GHZ LIKWID END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
