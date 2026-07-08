#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_bf_sweep
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=03:00:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --open-mode=truncate

set -euo pipefail
unset SLURM_EXPORT_ENV
cd "$SLURM_SUBMIT_DIR"
mkdir -p logs results

echo "===== SPR FRITZ BLOCKING_FACTOR SWEEP UNCAPPED START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

command -v icx >/dev/null 2>&1 || { echo "ERROR: icx not found" >&2; exit 1; }

export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== RUN SETTINGS frequency=uncapped CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL OMP_NUM_THREADS=$OMP_NUM_THREADS ====="
hostname
lscpu | egrep "Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node" || true

for f in ./RabbitInput/RabbitInput.rct ./RabbitInput/RabbitGeometry.rct ./RabbitInput/Reference1024.vol ./RabbitInput/LineRange1024-16.rct; do if [ ! -e "$f" ]; then echo "ERROR: required input file missing: $f" >&2; exit 1; fi; done

chmod +x ./run-bench.sh ./scripts/utils/build_icx_avx512.sh

for BF in 4 8 16 32 64; do
  echo "===== BUILD BLOCKING_FACTOR=$BF ====="
  EXTRA_OPTIONS="-DBLOCKING_FACTOR=$BF" ./scripts/utils/build_icx_avx512.sh
  echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BLOCKING_FACTOR=$BF ====="
  srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaASM
  echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BLOCKING_FACTOR=$BF ====="
done

echo "===== SPR FRITZ BLOCKING_FACTOR SWEEP UNCAPPED END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
