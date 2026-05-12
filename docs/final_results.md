# Final Experimental Results

## Formal Targets

| Metric | Target | Result | Status |
|---|---:|---:|:---:|
| Commit-bus detection coverage | >= 95% | 100.00% | PASS |
| Internal fault detection coverage | >= 95% | 95.11% | PASS |
| Detection latency | <= 5 cycles | max 3 cycles internal, 5 cycles watchdog | PASS |
| Safety logic area overhead | < 5% | evaluated by Yosys synthesis flow | In progress |

## Campaign 1: Commit-Bus Fault Injection

### Objective

Validate the extended commit-bus comparator by injecting controlled faults into the seven compared architectural fields of the checker core.

### Compared Fields

- next PC
- register write enable
- destination register address
- register write-back data
- memory write enable
- memory address
- memory write data

### Results

| Metric | Result |
|---|---:|
| Total injected faults | 105 |
| Detected faults | 105 |
| Missed faults | 0 |
| Detection coverage | 100.00% |
| Average latency | 0.00 cycles |
| Maximum latency | 0 cycles |

### Interpretation

All injected commit-bus faults were detected immediately by the comparator. This confirms that the extended comparator covers all monitored architectural commit signals.

## Campaign 2: Internal Checker-Core Fault Injection

### Objective

Inject faults inside the checker core before the commit interface and evaluate whether the resulting architectural effects are detected by the lockstep system.

### Results

| Metric | Result |
|---|---:|
| Total injected faults | 225 |
| Detected faults | 214 |
| Not observed at commit interface | 11 |
| Detection coverage | 95.11% |
| Average latency | 0.02 cycles |
| Maximum latency | 3 cycles |

### Interpretation

The internal campaign meets the required >= 95% coverage target. The 11 not-observed cases did not propagate to architecturally visible commit-bus effects during the observation window. This behavior is expected for some transient internal faults because a fault can be masked by instruction semantics, unused control paths, or overwritten datapath values.

## Campaign 3: Watchdog PC-Hold Fault

### Objective

Validate that the watchdog detects freeze/hang behavior where a core stops making forward progress.

### Results

| Metric | Result |
|---|---:|
| Fault type | Core B PC_HOLD |
| Detection result | Detected |
| Inject cycle | 6 |
| Detect cycle | 11 |
| Detection latency | 5 cycles |

### Interpretation

The watchdog detects the injected PC-hold fault within the required 5-cycle latency bound.

## Overall Conclusion

The implemented FuSa lockstep CPU satisfies the measured detection and latency goals:

- Fault detection coverage >= 95%: PASS
- Detection latency <= 5 cycles: PASS

The remaining quantitative target, safety-logic area overhead below 5%, is evaluated through the Yosys synthesis flow documented in `synth/area_summary.md`.
