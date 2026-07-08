#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_energy_final
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

echo "===== SPR FRITZ FINAL ENERGY SWEEP UNCAPPED START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

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

echo "===== RUN SETTINGS frequency=uncapped CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL ====="
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

for f in ./RabbitInput/RabbitInput.rct ./RabbitInput/RabbitGeometry.rct ./RabbitInput/Reference1024.vol ./RabbitInput/LineRange1024-16.rct; do
  if [ ! -e "$f" ]; then
    echo "ERROR: required input file missing: $f" >&2
    exit 1
  fi
done

chmod +x ./run-bench.sh ./scripts/utils/build_icx_avx512.sh

run_energy_case() {
  CASE="$1"
  PD="$2"
  BUF="$3"
  SCHED="$4"

  echo "===== BUILD ENERGY_CASE=$CASE PREFETCH_DISTANCE_BYTES=$PD ====="
  rm -rf build rabbitRunner-AVX512-ICX
  EXTRA_OPTIONS="-DPREFETCH_DISTANCE_BYTES=$PD" ./scripts/utils/build_icx_avx512.sh

  if [ "$SCHED" = "none" ]; then
    unset OMP_SCHEDULE
    SCHED_LABEL=none
  else
    export OMP_SCHEDULE="$SCHED"
    SCHED_LABEL="$OMP_SCHEDULE"
  fi

  echo "===== UNCAPPED ENERGY SPR LolaASM size1024 threads=$CORES ENERGY_CASE=$CASE BUFFER_SIZE=$BUF OMP_SCHEDULE=$SCHED_LABEL PREFETCH_DISTANCE_BYTES=$PD ====="
  srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none likwid-perfctr -C $CPUSEL -g ENERGY -O -- numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaASM -b $BUF
  echo "===== DONE UNCAPPED ENERGY SPR LolaASM size1024 threads=$CORES ENERGY_CASE=$CASE BUFFER_SIZE=$BUF OMP_SCHEDULE=$SCHED_LABEL PREFETCH_DISTANCE_BYTES=$PD ====="
}

run_energy_case baseline_asm 256 1 none
run_energy_case buffer8_static 256 8 none
run_energy_case buffer8_guided1 256 8 guided,1
run_energy_case final_best 64 8 guided,1

echo "===== SPR FRITZ FINAL ENERGY SWEEP UNCAPPED END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
