#!/usr/bin/env python3
"""Parse Yosys reports and estimate safety-logic overhead.

The script compares:
  1. a baseline single CPU synthesis report
  2. a full lockstep-system synthesis report

It estimates safety overhead as:

  lockstep_system_cells - 2 * baseline_cpu_cells

This isolates the added safety/control logic beyond the two duplicated CPU cores.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def extract_total_cells(report_path: Path) -> int:
    text = report_path.read_text(encoding="utf-8", errors="replace")

    # Yosys can print several stat sections. The final summary is the one we want.
    matches = re.findall(r"Number of cells:\s+(\d+)", text)
    if not matches:
        raise ValueError(f"Could not find 'Number of cells' in {report_path}")

    return int(matches[-1])


def main() -> None:
    parser = argparse.ArgumentParser(description="Estimate lockstep safety area overhead from Yosys reports.")
    parser.add_argument("--baseline", default="synth/baseline_cpu_report.txt", help="Yosys report for cpu_single_cycle")
    parser.add_argument("--lockstep", default="synth/lockstep_system_report.txt", help="Yosys report for lockstep_top")
    parser.add_argument("--out", default="synth/area_summary.md", help="Markdown output path")
    args = parser.parse_args()

    baseline_path = Path(args.baseline)
    lockstep_path = Path(args.lockstep)
    out_path = Path(args.out)

    baseline_cells = extract_total_cells(baseline_path)
    lockstep_cells = extract_total_cells(lockstep_path)

    duplicated_baseline = 2 * baseline_cells
    safety_overhead = lockstep_cells - duplicated_baseline
    overhead_percent = (safety_overhead / lockstep_cells) * 100.0 if lockstep_cells else 0.0

    status = "PASS" if overhead_percent < 5.0 else "FAIL"

    summary = f"""# Area / Synthesis Summary

## Method

Area is estimated using Yosys cell-count reports.

Two designs are synthesized:

1. **Baseline CPU**: `cpu_single_cycle`
2. **Full lockstep system**: `lockstep_top`

The safety-logic overhead is estimated as:

```text
safety_overhead_cells = lockstep_system_cells - 2 * baseline_cpu_cells
safety_overhead_percent = safety_overhead_cells / lockstep_system_cells * 100
```

This isolates the added comparator, fault-injection logic, watchdog, and lockstep wrapper logic beyond the two duplicated CPU cores.

## Results

| Quantity | Value |
|---|---:|
| Baseline CPU cells | {baseline_cells} |
| Two baseline CPU cores | {duplicated_baseline} |
| Full lockstep system cells | {lockstep_cells} |
| Estimated safety overhead cells | {safety_overhead} |
| Estimated safety overhead | {overhead_percent:.2f}% |
| Target | < 5.00% |
| Status | {status} |

## Notes

- The result is a synthesis-based estimate, not a post-layout silicon area measurement.
- The lockstep system includes two CPU cores plus safety logic.
- Simulation-only details in memory models can affect absolute cell counts, so the most important value is the relative overhead calculation.
"""

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()
