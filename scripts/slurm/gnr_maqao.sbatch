#!/bin/bash -l
#SBATCH --job-name=rabbitct_gnr_maqao
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --time=00:50:00
#SBATCH --constraint=hwperf
#SBATCH --exclusive
#SBATCH --output=logs/gnr/%x-%j.log
#SBATCH --error=logs/gnr/%x-%j.log
#SBATCH --open-mode=append

set -uo pipefail
unset SLURM_EXPORT_ENV

REPO_DIR="${REPO_DIR:-${SLURM_SUBMIT_DIR:-$PWD}}"
cd "$REPO_DIR" || exit 1
mkdir -p logs/gnr logs/maqao

ARCH=GNR
CORES=86
NUMAS=0-1
CPULIST=0-85
SIZE="${SIZE:-1024}"
VARIANTS="${VARIANTS:-LolaOMP LolaASM}"
REBUILD="${REBUILD:-0}"
BIN=./rabbitRunner-AVX512-ICX

export OMP_NUM_THREADS=$CORES
export OMP_STACKSIZE="${OMP_STACKSIZE:-64M}"
export TOOLCHAIN=AVX512-ICX
export KMP_AFFINITY=granularity=fine,compact,1,0
unset OMP_PLACES
unset OMP_PROC_BIND

printf '===== GNR MAQAO START %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"

module purge
module load intel/2025.0.0 likwid/5.5.1
module use -a ~unrz139/.modules/modulefiles
module load maqao hwloc
module list

printf '===== SETTINGS arch=%s fixed_freq=2.0GHz size=%s cores=%s numas=%s cpulist=%s rebuild=%s variants="%s" =====\n' "$ARCH" "$SIZE" "$CORES" "$NUMAS" "$CPULIST" "$REBUILD" "$VARIANTS"
hostname
date
which maqao || true
maqao --version || true
lscpu | egrep 'Model name|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)|NUMA node' || true
numactl -H | egrep 'available|node [0-3] cpus|node distances' || true

if [ "$REBUILD" = "1" ] || [ ! -x "$BIN" ]; then
  echo "===== REBUILD ON GNR WITH ICX -xHost ====="
  scripts/utils/build_icx_avx512.sh
fi

if [ ! -x "$BIN" ]; then echo "ERROR: $BIN missing"; exit 1; fi
if [ ! -d ./RabbitInput ]; then echo "ERROR: RabbitInput missing. Run ./download-input.sh first."; exit 1; fi

for ALG in $VARIANTS; do
  XP="logs/maqao/${ARCH}_${ALG}"
  rm -rf "$XP"
  echo "===== MAQAO ${ARCH} ${ALG} size${SIZE} threads=${CORES} ====="
  /usr/bin/time -v \
    srun --cpu-freq=2000000-2000000:performance \
         --ntasks=1 \
         --cpus-per-task=172 \
         --cpu-bind=none \
         numactl --physcpubind=$CPULIST --membind=$NUMAS \
         maqao oneview -R1 --with-FLOPS \
         --xp="$XP" \
         --envv_OMP_NUM_THREADS=$CORES \
         --envv_OMP_STACKSIZE=$OMP_STACKSIZE \
         --envv_KMP_AFFINITY=$KMP_AFFINITY \
         --executable="$BIN" \
         --run-command="<executable> -b 1 -m ${ALG} -a ./RabbitInput/RabbitGeometry.rct -i ./RabbitInput/RabbitInput.rct -c ./RabbitInput/Reference${SIZE}.vol -s ${SIZE}"
done

find logs/maqao -maxdepth 6 -type f \( -name 'index.html' -o -name '*.html' -o -name '*.txt' -o -name '*.csv' \) | sort | head -200
printf '===== GNR MAQAO END %s HOST=%s JOBID=%s =====\n' "$(date)" "$(hostname)" "${SLURM_JOB_ID:-no_jobid}"
