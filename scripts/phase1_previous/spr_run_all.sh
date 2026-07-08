#!/bin/bash -l
set -uo pipefail

cd "$HOME/RabbitCT_SPR" || exit 1

LOG="$PWD/SPR_ALL.log"
exec > >(tee -a "$LOG") 2>&1

echo "===== SPR SHELL SCRIPT START $(date) HOST=$(hostname) ====="

module purge
module load intel/2023.2.1 likwid/5.5.1
module list

export TOOLCHAIN=AVX512-ICX
export ARCH=SPR
export CORES=52
export NUMAS=0-3
export CPUSEL=S0:0-51
export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND

echo "===== SETTINGS ARCH=$ARCH TOOLCHAIN=$TOOLCHAIN CORES=$CORES NUMAS=$NUMAS CPUSEL=$CPUSEL ====="
echo "===== SYSTEM CHECK ====="
hostname
date
lscpu | egrep 'Model name|CPU\(s\)|Core\(s\) per socket|Socket\(s\)|NUMA node'
numactl -H | egrep 'available|node [0-7] cpus|node distances' || true

if [ ! -x ./rabbitRunner-AVX512-ICX ]; then echo "ERROR: ./rabbitRunner-AVX512-ICX missing"; exit 1; fi
if [ ! -x ./run-bench.sh ]; then echo "ERROR: ./run-bench.sh missing or not executable"; chmod +x ./run-bench.sh; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing"; exit 1; fi

echo "===== WARMUP SPR LolaOMP size1024 threads=$CORES ====="
/usr/bin/time -v numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaOMP

for ALG in LolaOMP LolaASM; do
  for REP in 1 2 3; do
    echo "===== REAL SPR $ALG size1024 threads=$CORES rep=$REP ====="
    /usr/bin/time -v numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v $ALG
  done
done

if [ "${RUN_LIKWID:-0}" = "1" ]; then
  for ALG in LolaOMP LolaASM; do
    for G in MEM L3 L2 DATA FLOPS_SP ENERGY; do
      echo "===== LIKWID SPR $ALG group=$G size1024 threads=$CORES ====="
      likwid-perfctr -C $CPUSEL -g $G -O -- numactl --cpunodebind=$NUMAS --interleave=$NUMAS ./run-bench.sh -s 1024 -v $ALG
    done
  done
fi

echo "===== SPR SHELL SCRIPT END $(date) HOST=$(hostname) ====="