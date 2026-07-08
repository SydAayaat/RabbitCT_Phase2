#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_likwid_uncapped
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=01:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --open-mode=truncate

set -euo pipefail
unset SLURM_EXPORT_ENV
cd "$SLURM_SUBMIT_DIR"

echo "===== SPR FRITZ LIKWID UNCAPPED START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

if ! command -v icx >/dev/null 2>&1; then
  echo "ERROR: icx not found after loading intel/2023.2.1" >&2
  exit 1
fi

export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
export OMP_SCHEDULE=guided,1
unset OMP_PLACES
unset OMP_PROC_BIND

# Build uses TOOLCHAIN=ICX. The output binary label is rabbitRunner-AVX512-ICX.
echo "===== BUILD SETTINGS compiler=ICX simd=AVX512 openmp=true likwid=true ispc=false ====="
echo "===== RUN SETTINGS frequency=uncapped CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL OMP_NUM_THREADS=$OMP_NUM_THREADS OMP_SCHEDULE=$OMP_SCHEDULE ====="

hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true
likwid-perfctr -a | egrep 'MEM|FLOPS_SP|ENERGY' || true

for f in ./RabbitInput/RabbitInput.rct ./RabbitInput/RabbitGeometry.rct ./RabbitInput/Reference1024.vol ./RabbitInput/LineRange1024-16.rct; do
  if [ ! -e "$f" ]; then
    echo "ERROR: required input file missing: $f" >&2
    exit 1
  fi
done

chmod +x ./run-bench.sh ./scripts/utils/build_icx_avx512.sh
./scripts/utils/build_icx_avx512.sh

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then
  echo "ERROR: ./rabbitRunner-AVX512-ICX missing after build" >&2
  exit 1
fi

for ALG in LolaOMP LolaASM; do
  for G in MEM FLOPS_SP ENERGY; do
    echo "===== UNCAPPED LIKWID SPR $ALG group=$G size1024 threads=$CORES ====="
    srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none likwid-perfctr -C $CPUSEL -g $G -O -- numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v $ALG
    echo "===== DONE UNCAPPED LIKWID SPR $ALG group=$G size1024 threads=$CORES ====="
  done
done

echo "===== SPR FRITZ LIKWID UNCAPPED END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
