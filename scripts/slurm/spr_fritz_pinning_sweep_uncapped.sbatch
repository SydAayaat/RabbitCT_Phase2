#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_pin_sweep
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

echo "===== SPR FRITZ THREAD PINNING SWEEP UNCAPPED START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

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

echo "===== RUN SETTINGS frequency=uncapped CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE ====="
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

echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=likwid_S0_0-51 ====="
unset OMP_PLACES
unset OMP_PROC_BIND
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c S0:0-51 ./run-bench.sh -s 1024 -v LolaASM -b 8
echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=likwid_S0_0-51 ====="

echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=likwid_phys_0-51 ====="
unset OMP_PLACES
unset OMP_PROC_BIND
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c 0-51 ./run-bench.sh -s 1024 -v LolaASM -b 8
echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=likwid_phys_0-51 ====="

echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=no_likwid_pin ====="
unset OMP_PLACES
unset OMP_PROC_BIND
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v LolaASM -b 8
echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=no_likwid_pin ====="

echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=omp_close ====="
export OMP_PLACES=cores
export OMP_PROC_BIND=close
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v LolaASM -b 8
echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=omp_close ====="

echo "===== UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=omp_spread ====="
export OMP_PLACES=cores
export OMP_PROC_BIND=spread
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v LolaASM -b 8
echo "===== DONE UNCAPPED SPR LolaASM size1024 threads=$CORES BUFFER_SIZE=8 OMP_SCHEDULE=$OMP_SCHEDULE PIN_POLICY=omp_spread ====="

echo "===== SPR FRITZ THREAD PINNING SWEEP UNCAPPED END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
