# Optimization Workflow

The professor asked for code diffs per optimization. Use a strict workflow:

```text
one optimization idea -> one git branch -> one code diff -> one benchmark result row
```

## 1. Start clean

```bash
git status
```

If the working tree is not clean, commit or stash first.

## 2. Create one branch per optimization

```bash
git checkout -b opt-line-range-prefetch
```

Use names like:

```text
opt-prefetch
opt-loop-order
opt-restrict-pointers
opt-block-size
opt-remove-branch
```

## 3. Edit exactly one thing

Do not combine multiple changes in one branch. If two things are changed at once,
the speedup cannot be attributed cleanly.

## 4. Save the diff

```bash
scripts/utils/save_diff.sh opt-line-range-prefetch
```

This writes:

```text
diffs/opt-line-range-prefetch.diff
```

## 5. Run baseline/optimization with the same setup

SPR:

```bash
sbatch scripts/slurm/spr_runtime_fixedfreq.sbatch
sbatch scripts/slurm/spr_likwid_fixedfreq.sbatch
```

GNR:

```bash
sbatch scripts/slurm/gnr_runtime_fixedfreq.sbatch
sbatch scripts/slurm/gnr_likwid_strict_2ghz.sbatch
```

## 6. Parse logs

```bash
scripts/utils/parse_rabbitct_logs.py logs/spr/*.log logs/gnr/*.log > results/summary.csv
```

## 7. Record result table

Keep a manual table like:

| Branch | Kernel | CPU | Runtime | Speedup vs baseline | Energy | Note |
|---|---|---:|---:|---:|---:|---|
| baseline | LolaASM | SPR | ... | 1.00x | ... | clean Phase 1 setup |
| opt-name | LolaASM | SPR | ... | ... | ... | one-line summary |

## 8. Merge only if useful

```bash
git checkout main
git merge opt-line-range-prefetch
```

If the optimization fails or slows down, keep the branch/diff for the report but
do not merge it into the final optimized branch.
