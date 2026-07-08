#!/usr/bin/env python3
"""Extract simple RabbitCT runtime/quality rows from job logs.

Usage:
  scripts/utils/parse_rabbitct_logs.py logs/spr/*.log logs/gnr/*.log > results/summary.csv
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

header_re = re.compile(r"===== .*?(SPR|GNR).*?(Lola[A-Za-z0-9_]+).*?size(\d+).*?threads=(\d+).*?=====")
total_re = re.compile(r"^Total:\s*([0-9.]+)\s*s")
avg_re = re.compile(r"^Average:\s*([0-9.]+)\s*ms")
rmse_re = re.compile(r"Root Mean Squared Error:\s*([0-9.eE+-]+)")
psnr_re = re.compile(r"PSNR:\s*([0-9.eE+-]+)")

rows: list[dict[str, str]] = []

for arg in sys.argv[1:]:
    path = Path(arg)
    if not path.exists():
        continue
    current = {
        "file": str(path),
        "arch": "",
        "kernel": "",
        "size": "",
        "threads": "",
        "total_s": "",
        "avg_ms": "",
        "rmse_hu": "",
        "psnr_db": "",
    }
    with path.open(errors="replace") as f:
        for line in f:
            m = header_re.search(line)
            if m:
                if current["kernel"] and (current["total_s"] or current["avg_ms"]):
                    rows.append(current.copy())
                current.update(
                    {
                        "file": str(path),
                        "arch": m.group(1),
                        "kernel": m.group(2),
                        "size": m.group(3),
                        "threads": m.group(4),
                        "total_s": "",
                        "avg_ms": "",
                        "rmse_hu": "",
                        "psnr_db": "",
                    }
                )
                continue
            if m := total_re.search(line):
                current["total_s"] = m.group(1)
            elif m := avg_re.search(line):
                current["avg_ms"] = m.group(1)
            elif m := rmse_re.search(line):
                current["rmse_hu"] = m.group(1)
            elif m := psnr_re.search(line):
                current["psnr_db"] = m.group(1)
    if current["kernel"] and (current["total_s"] or current["avg_ms"]):
        rows.append(current.copy())

writer = csv.DictWriter(sys.stdout, fieldnames=["file", "arch", "kernel", "size", "threads", "total_s", "avg_ms", "rmse_hu", "psnr_db"])
writer.writeheader()
writer.writerows(rows)
