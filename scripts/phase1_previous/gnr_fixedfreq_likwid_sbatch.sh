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
#SBATCH --output=GNR_logs/GNR_FIXEDFREQ_LIKWID.log
#SBATCH --error=GNR_logs/GNR_FIXEDFREQ_LIKWID.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1
mkdir -p GNR_logs

echo "===== GNR FIXEDFREQ LIKWID START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

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

echo "===== SETTINGS fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPULIST=$CPULIST TOOLCHAIN=$TOOLCHAIN ====="
hostname
date
lscpu | egrep 'Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true
which likwid-perfctr || true

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi

for ALG in LolaOMP LolaASM; do
  for G in MEM FLOPS_SP ENERGY; do
    echo "===== FIXEDFREQ LIKWID GNR $ALG group=$G size1024 threads=$CORES ====="
    srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none likwid-perfctr -C $CPULIST -g $G -O -- numactl --physcpubind=$CPULIST --membind=$NUMAS ./run-bench.sh -s 1024 -v $ALG
  done
done

echo "===== GNR FIXEDFREQ LIKWID END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
