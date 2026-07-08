# RabbitCT MuCoSim Phase 2 Clean Repository

Clean RabbitCT repository for the MuCoSim seminar Phase 2 optimization work.
This repository is based on the Phase 1 RabbitCT setup and keeps the benchmark
configuration fixed so that every optimization can be compared fairly.

## Fixed baseline setup

| Item | Value |
|---|---|
| Benchmark | RabbitCT backprojection |
| Input | `RabbitInput/RabbitInput.rct` |
| Geometry | `RabbitInput/RabbitGeometry.rct` |
| Reference | `RabbitInput/Reference1024.vol` |
| Problem size | `1024^3` via `-s 1024` |
| Main kernels | `LolaOMP`, `LolaASM` |
| Main Phase 2 target | start from `LolaASM` |
| Compiler | Intel `icx` |
| SIMD | `AVX512` |
| OpenMP | enabled |
| LIKWID | enabled |
| ISPC | disabled by default |
| Compile flags | `-O3 -ffp-model=fast -g -xHost -qopenmp` |
| Frequency | fixed 2.0 GHz through `srun --cpu-freq=2000000-2000000:performance` |
| SPR socket setup | 52 threads, socket 0, NUMA nodes `0-3`, CPU selection `S0:0-51` |
| GNR socket setup | 86 threads, socket 0, NUMA nodes `0-1`, CPU list `0-85` |

The executable produced by the Phase 1 configuration is:

```bash
rabbitRunner-AVX512-ICX
```

`run-bench.sh` expects this executable when the runtime variable is set as:

```bash
export TOOLCHAIN=AVX512-ICX
```

## Directory layout

```text
src/                         RabbitCT source code
mk/                          compiler/toolchain make includes
scripts/slurm/               cleaned SLURM scripts for SPR/GNR runs
scripts/utils/               helper scripts for building, diffs, and log parsing
scripts/phase1_previous/     previous Phase 1 scripts kept for traceability
docs/PHASE1_SETUP.md         detailed Phase 1 setup note
docs/OPTIMIZATION_WORKFLOW.md optimization + diff workflow
logs/                        job logs; ignored except .gitkeep
results/                     generated CSV/result files; ignored except .gitkeep
diffs/                       one diff per optimization
```

## First run on the cluster

Copy this folder to the cluster and enter it:

```bash
cd RabbitCT_Phase2_clean
```

Download the input once:

```bash
./download-input.sh
```

Submit a clean baseline runtime run:

```bash
sbatch scripts/slurm/spr_runtime_fixedfreq.sbatch
sbatch scripts/slurm/gnr_runtime_fixedfreq.sbatch
```

Submit LIKWID counter runs:

```bash
sbatch scripts/slurm/spr_likwid_fixedfreq.sbatch
sbatch scripts/slurm/gnr_likwid_strict_2ghz.sbatch
```

Submit MAQAO runs:

```bash
sbatch scripts/slurm/spr_maqao.sbatch
sbatch scripts/slurm/gnr_maqao.sbatch
```

All logs are written below `logs/`.

## Manual build

On SPR:

```bash
module purge
module load intel/2023.2.1 likwid/5.5.1
scripts/utils/build_icx_avx512.sh
```

On GNR:

```bash
module purge
module load intel/2025.0.0 likwid/5.5.1
scripts/utils/build_icx_avx512.sh
```

Equivalent direct command:

```bash
make distclean
make TOOLCHAIN=ICX ENABLE_OPENMP=true ENABLE_LIKWID=true ENABLE_ISPC=false SIMD=AVX512 \
     LIKWID_INC="-I${LIKWID_INCDIR}" LIKWID_LIB="-L${LIKWID_LIBDIR}"
```

## Optimization workflow

For every optimization:

```bash
git checkout -b opt-name
# edit exactly one optimization
scripts/utils/save_diff.sh opt-name
sbatch scripts/slurm/spr_runtime_fixedfreq.sbatch
sbatch scripts/slurm/gnr_runtime_fixedfreq.sbatch
```

This creates:

```text
diffs/opt-name.diff
```

So the professor gets exactly what was requested: one optimization, one code diff,
one benchmark result.

## Notes

The previous Phase 1 scripts were not thrown away. They are preserved in:

```text
scripts/phase1_previous/
```

The cleaned production scripts in `scripts/slurm/` are derived from those earlier
SPR/GNR scripts, but they avoid hard-coded `cd "$HOME/RabbitCT_SPR"` paths and write
logs into a cleaner structure.
