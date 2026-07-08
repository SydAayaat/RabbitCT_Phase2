#!/bin/bash -l
#SBATCH --job-name=rabbitct_gnr_v2
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --time=00:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=GNR_logs/GNR_FIXEDFREQ_V2.log
#SBATCH --error=GNR_logs/GNR_FIXEDFREQ_V2.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1
mkdir -p GNR_logs

echo "===== GNR FIXEDFREQ V2 START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

module purge
module load intel/2025.0.0 likwid/5.5.1 || module load intel likwid/5.5.1
module list
icx --version
echo "LIKWID_INCDIR=$LIKWID_INCDIR"
echo "LIKWID_LIBDIR=$LIKWID_LIBDIR"

export CORES=86
export NUMAS=0-1
export CPULIST=0-85
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== SETTINGS fixed_freq=2.0GHz CORES=$CORES NUMAS=$NUMAS CPULIST=$CPULIST ====="
lscpu | egrep 'Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true

echo "===== CLEAN OLD GNR BUILD ====="
rm -rf build/AVX512-ICX rabbitRunner-AVX512-ICX

echo "===== REBUILD ON GNR WITH TOOLCHAIN=ICX SIMD=AVX512 -xHost ====="
unset TOOLCHAIN
make distclean || true
make TOOLCHAIN=ICX ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false SIMD=AVX512 LIKWID_INC="-I${LIKWID_INCDIR}" LIKWID_LIB="-L${LIKWID_LIBDIR}"

echo "===== BINARY CHECK ====="
ls -lh rabbitRunner-AVX512-ICX
if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: binary missing after GNR rebuild"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then chmod +x ./run-bench.sh; fi

export TOOLCHAIN=AVX512-ICX

echo "===== FIXEDFREQ REAL GNR LolaOMP size1024 threads=$CORES rep=1 ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none numactl --physcpubind=$CPULIST --membind=$NUMAS ./run-bench.sh -s 1024 -v LolaOMP

echo "===== FIXEDFREQ REAL GNR LolaASM size1024 threads=$CORES rep=1 ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=172 --cpu-bind=none numactl --physcpubind=$CPULIST --membind=$NUMAS ./run-bench.sh -s 1024 -v LolaASM

echo "===== GNR FIXEDFREQ V2 END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
