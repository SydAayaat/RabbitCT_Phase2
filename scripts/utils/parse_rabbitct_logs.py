#!/usr/bin/env python3
"""Parse RabbitCT raw logs into CSV.

Extracts: source file, kernel, size, threads, total time, average projection time,
RMSE, PSNR, LIKWID group if visible, and run label.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional

ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
HEADER_RE = re.compile(r"^=+\s*(?P<label>.*?)\s*=+$")
KERNEL_RE = re.compile(r"\b(LolaOMP|LolaASM|LolaBunny|LolaOPT|LolaISPC)\b")
SIZE_RE = re.compile(r"(?:\bsize\s*=?\s*|\s-s\s+)(?P<size>\d+)", re.IGNORECASE)
THREAD_RE = re.compile(r"(?:\bthreads\s*=?\s*|OMP_NUM_THREADS=)(?P<threads>\d+)", re.IGNORECASE)
GROUP_RE = re.compile(r"\bgroup\s*=\s*(?P<group>[A-Za-z0-9_]+)")
CMD_KERNEL_RE = re.compile(r"\s-m\s+(?P<kernel>[A-Za-z0-9_]+)")
CMD_SIZE_RE = re.compile(r"\s-s\s+(?P<size>\d+)")
TOTAL_RE = re.compile(r"^Total:\s*(?P<value>[0-9]+(?:\.[0-9]+)?)\s*s\b", re.IGNORECASE)
AVG_RE = re.compile(r"^Average:\s*(?P<value>[0-9]+(?:\.[0-9]+)?)\s*ms\b", re.IGNORECASE)
MEAN_US_RE = re.compile(r"^mean time \[usec\]:\s*(?P<value>[0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)
RMSE_RE = re.compile(r"^Root Mean Squared Error:\s*(?P<value>[0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)
PSNR_RE = re.compile(r"^PSNR:\s*(?P<value>[0-9]+(?:\.[0-9]+)?)", re.IGNORECASE)


def clean(line: str) -> str:
    return ANSI_RE.sub("", line).strip()


def empty_run(source: str) -> Dict[str, Optional[str]]:
    return {
        "source": source,
        "run_label": None,
        "kernel": None,
        "size": None,
        "threads": None,
        "likwid_group": None,
        "total_time_s": None,
        "avg_projection_time_us": None,
        "avg_projection_time_ms": None,
        "rmse_hu": None,
        "psnr_db": None,
    }


def has_measurement(run: Dict[str, Optional[str]]) -> bool:
    return bool(run.get("kernel") and (run.get("total_time_s") or run.get("psnr_db") or run.get("rmse_hu")))


def finalize(runs: List[Dict[str, Optional[str]]], run: Dict[str, Optional[str]]) -> None:
    if has_measurement(run):
        if run.get("avg_projection_time_us") is None and run.get("avg_projection_time_ms") is not None:
            run["avg_projection_time_us"] = f"{float(run['avg_projection_time_ms']) * 1000.0:.6g}"
        runs.append(run.copy())


def parse_file(path: Path) -> List[Dict[str, Optional[str]]]:
    runs: List[Dict[str, Optional[str]]] = []
    run = empty_run(str(path))
    last_threads: Optional[str] = None
    last_group: Optional[str] = None

    with path.open("r", errors="replace") as fh:
        for raw in fh:
            line = clean(raw)
            if not line:
                continue

            hm = HEADER_RE.match(line)
            if hm:
                label = hm.group("label")
                km = KERNEL_RE.search(label)
                if km:
                    finalize(runs, run)
                    run = empty_run(str(path))
                    run["run_label"] = label
                    run["kernel"] = km.group(1)
                    sm = SIZE_RE.search(label)
                    tm = THREAD_RE.search(label)
                    gm = GROUP_RE.search(label)
                    if sm:
                        run["size"] = sm.group("size")
                    if tm:
                        run["threads"] = tm.group("threads")
                        last_threads = tm.group("threads")
                    elif last_threads:
                        run["threads"] = last_threads
                    if gm:
                        run["likwid_group"] = gm.group("group")
                        last_group = gm.group("group")
                    elif last_group and "LIKWID" in label:
                        run["likwid_group"] = last_group
                continue

            if "OMP_NUM_THREADS=" in line or "threads=" in line:
                tm = THREAD_RE.search(line)
                if tm:
                    last_threads = tm.group("threads")
                    if run.get("threads") is None:
                        run["threads"] = last_threads

            gm = GROUP_RE.search(line)
            if gm:
                last_group = gm.group("group")
                if run.get("likwid_group") is None:
                    run["likwid_group"] = last_group

            if "rabbitRunner" in line or "run-bench.sh" in line:
                km = CMD_KERNEL_RE.search(line)
                sm = CMD_SIZE_RE.search(line)
                if km:
                    if run.get("kernel") and run.get("kernel") != km.group("kernel") and has_measurement(run):
                        finalize(runs, run)
                        run = empty_run(str(path))
                    run["kernel"] = km.group("kernel")
                if sm:
                    run["size"] = sm.group("size")
                if last_threads and run.get("threads") is None:
                    run["threads"] = last_threads
                if last_group and run.get("likwid_group") is None:
                    run["likwid_group"] = last_group

            for regex, key in ((RMSE_RE, "rmse_hu"), (PSNR_RE, "psnr_db"), (TOTAL_RE, "total_time_s"), (MEAN_US_RE, "avg_projection_time_us"), (AVG_RE, "avg_projection_time_ms")):
                mm = regex.match(line)
                if mm:
                    run[key] = mm.group("value")

    finalize(runs, run)
    return runs


def iter_paths(args: Iterable[str]) -> Iterable[Path]:
    for arg in args:
        p = Path(arg)
        if p.is_dir():
            yield from sorted(x for x in p.rglob("*.log") if x.is_file())
            yield from sorted(x for x in p.rglob("*.out") if x.is_file())
        else:
            yield p


def main() -> int:
    ap = argparse.ArgumentParser(description="Parse RabbitCT logs and write CSV to stdout or a file.")
    ap.add_argument("paths", nargs="+", help="Log files or directories containing *.log / *.out files")
    ap.add_argument("-o", "--output", help="CSV output file. Default: stdout")
    ns = ap.parse_args()

    rows: List[Dict[str, Optional[str]]] = []
    for path in iter_paths(ns.paths):
        if path.exists() and path.is_file():
            rows.extend(parse_file(path))

    fields = [
        "source",
        "run_label",
        "kernel",
        "size",
        "threads",
        "likwid_group",
        "total_time_s",
        "avg_projection_time_us",
        "rmse_hu",
        "psnr_db",
    ]

    out_fh = open(ns.output, "w", newline="") if ns.output else sys.stdout
    try:
        writer = csv.DictWriter(out_fh, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)
    finally:
        if ns.output:
            out_fh.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
