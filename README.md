# FuSa Lockstep CPU

A dual-core lockstep RISC processor implemented in SystemVerilog RTL for a final-year engineering project. The system demonstrates hardware fault detection using two synchronized CPU cores, an extended commit-bus comparator, RTL fault-injection logic, a watchdog, and automated fault-injection campaigns.

## Project Goal

The project evaluates whether a compact lockstep architecture can detect injected hardware faults within strict functional-safety targets.

## Formal Targets

| Metric                              |Required Target|Measured Result                         | Status      |
|------------------------------------------------------------------------------------------------------------|
| Commit-bus fault detection coverage | >= 95%      | 100.00%                                  | PASS        |
| Internal fault detection coverage   | >= 95%      | 95.11%                                   | PASS        |
| Detection latency                   | <= 5 cycles | max 3 cycles internal, 5 cycles watchdog | PASS        |
| Safety-logic area overhead          | < 5%        | evaluated by Yosys synthesis flow        | In progress |

## Architecture

The system contains two identical single-cycle RISC cores:

- **Core A**, the master/golden core
- **Core B**, the checker/shadow core
- **Extended commit-bus comparator**, comparing architecturally visible signals every cycle
- **RTL fault-injection logic**, used to inject controlled bit flips
- **Watchdog**, used to detect PC-stall and hang-type faults

The comparator checks:

1. next PC
2. register write enable
3. register destination address
4. register write-back data
5. memory write enable
6. memory address
7. memory write data

## Final Fault-Injection Results

### Campaign 1: Commit-Bus Fault Injection

| Metric | Result |
|---|---:|
| Total injected faults | 105 |
| Detected faults | 105 |
| Missed faults | 0 |
| Detection coverage | 100.00% |
| Average latency | 0.00 cycles |
| Maximum latency | 0 cycles |

### Campaign 2: Internal Checker-Core Fault Injection

| Metric | Result |
|---|---:|
| Total injected faults | 225 |
| Detected faults | 214 |
| Not observed at commit interface | 11 |
| Detection coverage | 95.11% |
| Average latency | 0.02 cycles |
| Maximum latency | 3 cycles |

### Campaign 3: Watchdog PC-Hold Fault

| Metric | Result |
|---|---:|
| Fault type | Core B PC_HOLD |
| Detection result | Detected |
| Inject cycle | 6 |
| Detect cycle | 11 |
| Detection latency | 5 cycles |

## Repository Structure

```text
fusa_cpu/
├── rtl/                      # CPU, lockstep, comparator, FI, watchdog RTL
├── tb/                       # SystemVerilog testbenches and campaigns
├── docs/                     # Final results and technical documentation
├── results/                  # Campaign summaries and generated CSV outputs
├── synth/                    # Yosys scripts, raw reports, and area summary
├── scripts/                  # Helper scripts for parsing reports
├── Makefile                  # Simulation and synthesis automation
└── PROJECT_BRIEF.md          # Technical project brief
```

## How to Run

Run the basic CPU and lockstep tests:

```bash
make clean
make cpu
make lockstep
```

Run the automated fault campaigns:

```bash
make fault_campaign
make internal_fault_campaign
make watchdog_campaign
```

Run the synthesis reports:

```bash
make synth
make area_summary
```

## Main Deliverables

- Single-cycle RISC CPU RTL
- Dual-core lockstep wrapper
- Extended commit-bus comparator
- RTL fault-injection unit
- Watchdog for PC-stall detection
- Automated fault-injection campaigns
- Coverage and latency measurements
- Yosys synthesis flow for area estimation

## Conclusion

The implemented FuSa lockstep CPU meets the measured detection and latency targets. The final results show 100.00% commit-bus detection coverage, 95.11% internal fault detection coverage, and detection latency within the required 5-cycle bound.
