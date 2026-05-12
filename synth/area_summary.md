# Area / Synthesis Summary

## Purpose

This document summarizes how the project evaluates the area-overhead target:

```text
Comparator + fault-injection logic + watchdog overhead < 5%
```

The project uses Yosys synthesis reports to estimate relative cell count overhead.

## Method

Two designs are synthesized:

1. **Baseline CPU**
   - Top module: `cpu_single_cycle`
   - Script: `synth/baseline_cpu.ys`
   - Report: `synth/baseline_cpu_report.txt`

2. **Full Lockstep System**
   - Top module: `lockstep_top`
   - Includes two CPU cores, comparator, fault-injection logic, watchdog, and lockstep wrapper
   - Script: `synth/lockstep_system.ys`
   - Report: `synth/lockstep_system_report.txt`

The estimated safety-logic overhead is computed as:

```text
safety_overhead_cells = lockstep_system_cells - 2 * baseline_cpu_cells
safety_overhead_percent = safety_overhead_cells / lockstep_system_cells * 100
```

This isolates the additional safety logic beyond the two duplicated CPU cores.

## How to Regenerate

Run:

```bash
make synth
make area_summary
```

The `make area_summary` target runs:

```bash
python3 scripts/area_from_yosys.py
```

and rewrites this file with the extracted Yosys cell counts.

## Notes

- This is a synthesis-based area estimate, not a post-layout silicon area measurement.
- Absolute cell counts can be affected by simulation-style memory models.
- The important value is the relative overhead of the added safety logic compared with the full lockstep system.
- If memory models dominate the absolute area, the same flow can also be repeated with logic-only memory stubs for a stricter comparator/watchdog/FI estimate.
