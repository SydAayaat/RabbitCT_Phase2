#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_numa_sweep
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=02:00:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --open-mode=truncate

set -euo pipefail
unset SLURM_EXPORT_ENV
cd "$SLURM_SUBMIT_DIR"
mkdir -p logs results

echo "===== SPR FRITZ NUMA SWEEP UNCAPPED START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

command -v icx >/dev/null 2>&1 || { echo "ERROR: icx not found" >&2; exit 1; }

export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
export OMP_SCHEDULE=guided,1
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== RUN SETTINGS frequency=uncapped CORES=$CORES CPUSEL=$CPUSEL OMP_NUM_THREADS=$OMP_NUM_THREADS OMP_SCHEDULE=$OMP_SCHEDULE BUFFER_SIZE=8 ====="
hostname
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

for f in ./RabbitInput/RabbitInput.rct ./RabbitInput/RabbitGeometry.rct ./RabbitInput/Reference1024.vol ./RabbitInput/LineRange1024-16.rct; do
  if [ ! -e "$f" ]; then
    echo "ERROR: required input file missing: $f" >&2
    exit 1
  fi
done

chmod +x ./run-bench.sh ./scripts/utils/build_icx_avx512.sh
./scripts/utils/build_icx_avx512.sh

run_case() {
  LABEL="$1"
  shift
  echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE NUMA_POLICY=$LABEL ====="
  srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none "$@" likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaASM -b 8
  echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE NUMA_POLICY=$LABEL ====="
}

run_case interleave_0-3 numactl --cpunodebind=0-3 --interleave=0-3
run_case localalloc numactl --cpunodebind=0-3 --localalloc
run_case membind_0-3 numactl --cpunodebind=0-3 --membind=0-3
run_case membind_0 numactl --cpunodebind=0-3 --membind=0
run_case membind_1 numactl --cpunodebind=0-3 --membind=1
run_case membind_2 numactl --cpunodebind=0-3 --membind=2
run_case membind_3 numactl --cpunodebind=0-3 --membind=3

echo "===== SPR FRITZ NUMA SWEEP UNCAPPED END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
