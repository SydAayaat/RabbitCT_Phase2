#!/bin/bash -l
#SBATCH --job-name=rabbitct_spr_rebuild_maqao
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --time=02:30:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=SPR_REBUILD_MAQAO.log
#SBATCH --error=SPR_REBUILD_MAQAO.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV
cd "$HOME/RabbitCT_SPR" || exit 1

echo "===== SPR REBUILD + MAQAO START $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="

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

echo "===== SYSTEM INFO ====="
hostname
date
ldd --version | head -1
lscpu | egrep 'Model name|CPU MHz|CPU max MHz|CPU min MHz|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

echo "===== FIX CONFIG + PATCH MAKEFILE ====="
cp mk/config-default.mk config.mk
sed -i 's/^TOOLCHAIN ?=.*/TOOLCHAIN ?= ICX/' config.mk
sed -i 's/^ENABLE_OPENMP ?=.*/ENABLE_OPENMP ?= true/' config.mk
sed -i 's/^ENABLE_LIKWID ?=.*/ENABLE_LIKWID ?= true/' config.mk
sed -i 's/^ENABLE_ISPC ?=.*/ENABLE_ISPC ?= false/' config.mk
sed -i 's/^SIMD ?=.*/SIMD ?= AVX512/' config.mk
sed -i '14,16s/^/#/' Makefile
sed -i 's/&: %.ispc/: %.ispc/' Makefile
sed -i '/patsubst.*%.ispc.*BUILD_DIR.*%.o/s/^#*/#/' Makefile
grep -q -- '-g -xHost' mk/include_ICX.mk || sed -i 's/FAST_WORKAROUND) -xHost/FAST_WORKAROUND) -g -xHost/' mk/include_ICX.mk
grep -n "TOOLCHAIN\|ENABLE_OPENMP\|ENABLE_LIKWID\|ENABLE_ISPC\|SIMD\|VECTORSIZE\|SIMD_NAME" config.mk
grep -n "xHost\|-g" mk/include_ICX.mk

echo "===== REBUILD BINARY ON THIS NODE ====="
make distclean
make TOOLCHAIN=ICX ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false SIMD=AVX512 LIKWID_INC="-I${LIKWID_INCDIR:-/usr/local/include}" LIKWID_LIB="-L${LIKWID_LIBDIR:-/usr/local/lib}"

echo "===== CHECK NEW BINARY ====="
ls -lh rabbitRunner-*
ldd "$BIN" | egrep "libc|not found|GLIBC" || true
"$BIN" -h | head -40

echo "===== CLEAN OLD MAQAO REPORTS ====="
rm -rf maqao_reports/SPR_LolaOMP maqao_reports/SPR_LolaASM
mkdir -p maqao_reports

echo "===== MAQAO SPR LolaOMP size1024 threads=$CORES ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=maqao_reports/SPR_LolaOMP --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --pinning-command="numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL" --executable=$BIN --run-command="<executable> -b 1 -m LolaOMP -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"

echo "===== MAQAO SPR LolaASM size1024 threads=$CORES ====="
/usr/bin/time -v srun --cpu-freq=2000000-2000000:performance --ntasks=1 --cpus-per-task=104 --cpu-bind=none maqao oneview -R1 --with-FLOPS --xp=maqao_reports/SPR_LolaASM --envv_OMP_NUM_THREADS=$CORES --envv_OMP_STACKSIZE=64M --pinning-command="numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL" --executable=$BIN --run-command="<executable> -b 1 -m LolaASM -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference1024.vol -s 1024"

echo "===== MAQAO REPORT FILES ====="
find maqao_reports -maxdepth 5 -type f | sort | head -300

echo "===== SPR REBUILD + MAQAO END $(date) HOST=$(hostname) JOBID=$SLURM_JOB_ID ====="
