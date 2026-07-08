#!/bin/bash -l
#SBATCH --job-name=rabbitct_gnr_maqao
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --time=00:35:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=GNR_logs/MAQAO/GNR_MAQAO.log
#SBATCH --error=GNR_logs/MAQAO/GNR_MAQAO.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1
mkdir -p GNR_logs/MAQAO GNR_logs/MAQAO/reports

echo "===== GNR MAQAO SBATCH START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2025.0.0 likwid/5.5.1
module use -a ~unrz139/.modules/modulefiles
module load maqao hwloc
module list

export TOOLCHAIN=AVX512-ICX
export CORES=86
export NUMAS=0-1
export CPULIST=0-85
export CPUSEL=S0:0-85
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== SETTINGS fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPULIST=$CPULIST CPUSEL=$CPUSEL TOOLCHAIN=$TOOLCHAIN ====="
hostname
date
which maqao
maqao --version || true
lscpu | egrep 'Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing"; exit 1; fi

echo "===== MAQAO ONEVIEW GNR LolaOMP START ====="
srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=GNR_logs/MAQAO/reports/GNR_LolaOMP --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --executable=./rabbitRunner-AVX512-ICX --run-command="numactl --physcpubind=$CPULIST --membind=$NUMAS <executable> -b 1 -m LolaOMP -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"
echo "===== MAQAO ONEVIEW GNR LolaOMP END ====="

echo "===== MAQAO ONEVIEW GNR LolaASM START ====="
srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=GNR_logs/MAQAO/reports/GNR_LolaASM --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --executable=./rabbitRunner-AVX512-ICX --run-command="numactl --physcpubind=$CPULIST --membind=$NUMAS <executable> -b 1 -m LolaASM -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"
echo "===== MAQAO ONEVIEW GNR LolaASM END ====="

echo "===== REPORT TREE ====="
find GNR_logs/MAQAO -maxdepth 5 -type f \( -name 'index.html' -o -name '*.html' -o -name '*.txt' -o -name '*.csv' \) | sort | head -120

echo "===== GNR MAQAO SBATCH END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
