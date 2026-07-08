#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_likwid
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=01:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=SPR_FIXEDFREQ_LIKWID.log
#SBATCH --error=SPR_FIXEDFREQ_LIKWID.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1

echo "===== SPR FIXEDFREQ LIKWID SBATCH START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

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

for ALG in LolaOMP LolaASM; do
  for G in MEM FLOPS_SP ENERGY; do
    echo "===== FIXEDFREQ LIKWID SPR $ALG group=$G size1024 threads=$CORES ====="
    srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none likwid-perfctr -C $CPUSEL -g $G -O -- numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v $ALG
  done
done

echo "===== SPR FIXEDFREQ LIKWID SBATCH END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="