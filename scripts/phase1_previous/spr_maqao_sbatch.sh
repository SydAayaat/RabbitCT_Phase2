#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_maqao
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=02:00:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=SPR_MAQAO.log
#SBATCH --error=SPR_MAQAO.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1

echo "===== SPR MAQAO SBATCH START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module use -a ~unrz139/.modules/modulefiles
module load maqao hwloc
module list

export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export BIN=./rabbitRunner-AVX512-ICX
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

mkdir -p maqao_reports

echo "===== SETTINGS fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL BIN=$BIN ====="
hostname
date
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

if [ ! -x "$BIN" ]; then echo "ERROR: binary $BIN missing"; exit 1; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing"; exit 1; fi

echo "===== MAQAO SPR LolaOMP size1024 threads=$CORES ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=maqao_reports/SPR_LolaOMP --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --pinning-command="numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL" --executable=$BIN --run-command="<executable> -b 1 -m LolaOMP -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"

echo "===== MAQAO SPR LolaASM size1024 threads=$CORES ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=maqao_reports/SPR_LolaASM --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --pinning-command="numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL" --executable=$BIN --run-command="<executable> -b 1 -m LolaASM -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"

echo "===== MAQAO REPORT FILES ====="
find maqao_reports -maxdepth 5 -type f | sort | head -300

echo "===== SPR MAQAO SBATCH END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
