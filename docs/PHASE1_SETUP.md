# Phase 1 Setup Note

This note freezes the Phase 1 setup so Phase 2 optimizations are measured against
a stable baseline.

## Benchmark target

- Benchmark: RabbitCT backprojection.
- Main kernels: `LolaOMP` and `LolaASM`.
- Main Phase 2 optimization target: `LolaASM` first.
- SIMD: `AVX512`.
- Compiler: Intel `icx`.
- OpenMP: enabled.
- LIKWID: enabled.
- ISPC: disabled by default.
- Problem size: `-s 1024`, i.e. `1024^3` reconstruction volume.
- Projection count: 496 projections.
- Projection image size: `1248 x 960`.
- Input files:
  - `RabbitInput/RabbitInput.rct`
  - `RabbitInput/RabbitGeometry.rct`
  - `RabbitInput/Reference1024.vol`
- Line range/clipping file used automatically:
  - `RabbitInput/LineRange1024-16.rct`

## Build configuration

`config.mk` is fixed to:

```make
TOOLCHAIN ?= ICX
ENABLE_OPENMP ?= true
ENABLE_LIKWID ?= true
ENABLE_ISPC ?= false
SIMD ?= AVX512
OPTIONS += -DARRAY_ALIGNMENT=64
OPTIONS += -DMAX_NUM_THREADS=128
```

The ICX toolchain file uses:

```make
CC = icx
OPENMP = -qopenmp
FAST_WORKAROUND = -O3 -ffp-model=fast
CFLAGS = $(FAST_WORKAROUND) -g -xHost -std=c99 -Wno-unused-command-line-argument $(OPENMP)
```

Important consequence: because `-xHost` is used, rebuild the binary on the same
architecture where measurements are taken. Do not build on SPR and use that same
binary for GNR measurements.

The binary name is:

```bash
rabbitRunner-AVX512-ICX
```

For `run-bench.sh`, set:

```bash
export TOOLCHAIN=AVX512-ICX
```

## Runtime command

The benchmark wrapper runs this command shape:

```bash
./rabbitRunner-AVX512-ICX \
  -b 1 \
  -m LolaASM \
  -a ./RabbitInput/RabbitGeometry.rct \
  -i ./RabbitInput/RabbitInput.rct \
  -c ./RabbitInput/Reference1024.vol \
  -s 1024
```

Use `LolaOMP` for the OpenMP baseline and `LolaASM` for the hand-written SIMD
assembly baseline.

## Common runtime environment

```bash
export OMP_STACKSIZE=64M
unset OMP_PLACES
unset OMP_PROC_BIND
```

`OMP_STACKSIZE=64M` is needed for the large `1024^3` case. Without it, the
OpenMP worker stack can be too small for the high-thread-count `LolaASM` run.

## SPR setup

- System: Fritz Sapphire Rapids node.
- Example node names observed in Phase 1: `f2161`, `f2267`.
- CPU: Intel Xeon Platinum 8470.
- Sockets: 2.
- Cores/socket: 52.
- Total physical cores/node: 104.
- Single socket used: socket 0.
- Threads used: 52.
- NUMA domains for socket 0: `0-3`.
- LIKWID CPU selection: `S0:0-51`.

SPR modules:

```bash
module purge
module load intel/2023.2.1 likwid/5.5.1
```

SPR SLURM resource shape:

```bash
#SBATCH --partition=spr1tb
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=104
#SBATCH --constraint=hwperf
#SBATCH --exclusive
```

SPR fixed-frequency launch shape:

```bash
srun --cpu-freq=2000000-2000000:performance \
     --ntasks=1 \
     --cpus-per-task=104 \
     --cpu-bind=none \
     numactl --cpunodebind=0-3 --interleave=0-3 \
     likwid-pin -c S0:0-51 \
     ./run-bench.sh -s 1024 -v LolaASM
```

## GNR setup

- System: test cluster.
- Node used: `granrap2`.
- CPU: Intel Xeon 6787P.
- Architecture: Granite Rapids.
- Sockets: 2.
- Cores/socket: 86.
- Total physical cores/node: 172.
- Single socket used: socket 0.
- Threads used: 86.
- NUMA domains for socket 0: `0-1`.
- Physical CPU list: `0-85`.

GNR modules:

```bash
module purge
module load intel/2025.0.0 likwid/5.5.1
```

GNR SLURM resource shape:

```bash
#SBATCH --partition=work
#SBATCH --nodelist=granrap2
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=172
#SBATCH --constraint=hwperf
#SBATCH --exclusive
```

GNR fixed-frequency launch shape:

```bash
srun --cpu-freq=2000000-2000000:performance \
     --ntasks=1 \
     --cpus-per-task=172 \
     --cpu-bind=none \
     numactl --physcpubind=0-85 --membind=0-1 \
     ./run-bench.sh -s 1024 -v LolaASM
```

## LIKWID groups

Phase 1 core groups:

```text
MEM
FLOPS_SP
ENERGY
```

Optional extended groups from the earlier full SPR script:

```text
MEM L3 L2 DATA FLOPS_SP ENERGY
```

Use `-C` with a pinned CPU set. Use capital `-C`, not lowercase `-c`, when the
application itself must be pinned by `likwid-perfctr`.

## MAQAO setup

MAQAO module setup:

```bash
module use -a ~unrz139/.modules/modulefiles
module load maqao hwloc
```

SPR report matrix:

```text
logs/maqao/SPR_LolaOMP
logs/maqao/SPR_LolaASM
```

GNR report matrix:

```text
logs/maqao/GNR_LolaOMP
logs/maqao/GNR_LolaASM
```

Use `--with-FLOPS` and compile with `-g`.

## Comparison rule for Phase 2

Keep all of these fixed unless the specific optimization explicitly changes one
of them:

```text
RabbitCT
size 1024
LolaASM primary baseline
ICX
AVX512
OpenMP enabled
LIKWID enabled
ISPC disabled unless separate experiment
single socket only
fixed 2.0 GHz
same input/reference files
SPR: 52 threads
GNR: 86 threads
```
