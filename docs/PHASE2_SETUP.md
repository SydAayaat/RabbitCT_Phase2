# RabbitCT Phase 2 setup

This repository is a clean Phase 2 baseline for the FAU MuCoSim RabbitCT work.
It keeps only source, build config, small utility scripts, and documentation.
Old binaries, object files, logs, MAQAO reports, LIKWID output, and generated volumes are intentionally not tracked.

## Target benchmark setup

- Benchmark: RabbitCT
- Phase 2 focus kernels: `LolaOMP` and `LolaASM`
- Main problem size: `1024`
- Compiler: Intel ICX from `intel/2023.2.1`
- SIMD: `AVX512`
- OpenMP: enabled
- LIKWID: enabled
- ISPC: disabled by default
- Build command uses `TOOLCHAIN=ICX`
- Output binary name: `rabbitRunner-AVX512-ICX`

## Fritz Sapphire Rapids run setup

Use Fritz for Sapphire Rapids runs.

- Partition: `spr1tb`
- CPU: Intel Xeon Platinum 8470
- Node layout: 2 sockets x 52 physical cores
- Allocation: whole node with `--cpus-per-task=104` and `--exclusive`
- Measurement scope: one socket only
- Socket: socket 0
- OpenMP threads: `52`
- CPU selection: `S0:0-51`
- NUMA memory domains: `0-3`
- Frequency policy: uncapped / highest normal performance
- Do not use `--cpu-freq=2000000-2000000:performance`

The SLURM scripts deliberately use the old working style:

```text
srun --ntasks=1 --cpus-per-task=104 --cpu-bind=none numactl --cpunodebind=$NUMAS --interleave=$NUMAS likwid-pin -c $CPUSEL ./run-bench.sh -s 1024 -v LolaOMP
```

and the same for `LolaASM`.

## Required input files

The repository does not track the large RabbitCT input files.
Place or symlink the input directory as `RabbitInput` at the repository root.

Required files:

- `RabbitInput/RabbitInput.rct`
- `RabbitInput/RabbitGeometry.rct`
- `RabbitInput/Reference1024.vol`
- `RabbitInput/LineRange1024-16.rct`

Preferred setup on Fritz:

```bash
ln -s /path/to/old/RabbitInput RabbitInput
```

Check it with:

```bash
ls -lh RabbitInput/RabbitInput.rct RabbitInput/RabbitGeometry.rct RabbitInput/Reference1024.vol RabbitInput/LineRange1024-16.rct
```

## Manual build on Fritz frontend

Load modules:

```bash
module purge
module load intel/2023.2.1 likwid/5.5.1
```

Build:

```bash
./scripts/utils/build_icx_avx512.sh
```

This runs:

```bash
make TOOLCHAIN=ICX SIMD=AVX512 ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false
```

## Submit main uncapped run

From the repository root:

```bash
sbatch scripts/slurm/spr_fritz_buildrun_uncapped.sbatch
```

This builds the binary and runs:

- `LolaOMP`, size `1024`, 52 threads
- `LolaASM`, size `1024`, 52 threads

The log file is created in the repository root as:

```text
SPR_FRITZ_BUILDRUN_UNCAPPED_<jobid>.log
```

## Submit LIKWID uncapped run

From the repository root:

```bash
sbatch scripts/slurm/spr_fritz_likwid_uncapped.sbatch
```

This builds the binary and runs both kernels with LIKWID groups:

- `MEM`
- `FLOPS_SP`
- `ENERGY`

The log file is created in the repository root as:

```text
SPR_FRITZ_LIKWID_UNCAPPED_<jobid>.log
```

## Parse logs

Example:

```bash
python3 scripts/utils/parse_rabbitct_logs.py SPR_FRITZ_BUILDRUN_UNCAPPED_*.log SPR_FRITZ_LIKWID_UNCAPPED_*.log -o results/rabbitct_phase2_summary.csv
```

Create the results directory first because it is ignored by git:

```bash
mkdir -p results
```

Extracted fields:

- source file
- run label
- kernel
- size
- threads
- LIKWID group if present
- total time in seconds
- average projection time in microseconds
- RMSE
- PSNR

## Save one optimization diff

After making one optimization change:

```bash
./scripts/utils/save_diff.sh <optimization-name>
```

This writes a patch into:

```text
docs/diffs/YYYYMMDD_HHMMSS_<optimization-name>.diff
```

Then commit the optimization separately:

```bash
git add src scripts docs config.mk Makefile
```

```bash
git commit -m "Optimize <short-description>"
```

## Git workflow

Baseline idea:

```bash
git status
```

```bash
git log --oneline --max-count=5
```

Do not commit raw inputs, logs, results, generated volumes, object files, binaries, or MAQAO reports.
