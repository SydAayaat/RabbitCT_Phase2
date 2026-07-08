#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_fixed
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=01:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=SPR_FIXEDFREQ.log
#SBATCH --error=SPR_FIXEDFREQ.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1

echo "===== SPR FIXEDFREQ SBATCH START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

export TOOLCHAIN=AVX512-ICX
export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== SETTINGS fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL TOOLCHAIN=$TOOLCHAIN ====="
echo "===== SYSTEM INFO ====="
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing"; exit 1; fi

echo "===== FIXEDFREQ REAL SPR LolaOMP size1024 threads=$CORES rep=1 ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaOMP

echo "===== FIXEDFREQ REAL SPR LolaASM size1024 threads=$CORES rep=1 ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaASM

echo "===== SPR FIXEDFREQ SBATCH END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="