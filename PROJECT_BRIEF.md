# FuSa Lockstep CPU — Technical Project Brief

## What This Project Is

This project implements a dual-core RISC processor in SystemVerilog RTL to demonstrate hardware fault detection using a lockstep architecture. Two identical CPU cores execute the same instruction stream in parallel. Their architecturally visible outputs are compared every cycle, and mismatches are reported through a sticky detection flag.

The project is a final-year engineering capstone focused on Functional Safety (FuSa) concepts: fault detection, diagnostic coverage, detection latency, and area overhead.

## Formal Quantitative Targets

The work plan defines three quantitative targets:

- Fault detection coverage: >= 95% of injected single-bit fault cases
- Detection latency: <= 5 clock cycles
- Comparator + FI logic + watchdog area overhead: < 5% of the lockstep system, estimated analytically and by synthesis

## System Architecture

```text
                  +-----------------------------------------+
                  |              lockstep_top               |
                  |                                         |
clk, reset -----> |  +-------------+      +-------------+    |
                  |  | Core A      |      | Core B      |    |
                  |  | Master      |      | Checker     |    |
                  |  +------+------+      +------+------+    |
                  |         |                    |           |
                  |         | commit bus          | commit bus |
                  |         v                    v           |
                  |      +----------------------------+       |
                  |      | Extended Comparator        |       |
                  |      +-------------+--------------+       |
                  |                    |                      |
                  |          mismatch_now / mismatch_latched  |
                  |                                         |
                  |      +----------------------------+       |
                  |      | Watchdog                   |       |
                  |      +-------------+--------------+       |
                  |                    |                      |
                  |          stall_any / stall_latched        |
                  +-----------------------------------------+
```

## Compared Commit-Bus Signals

The comparator checks seven architectural signals:

1. next PC
2. register write enable
3. destination register address
4. register write-back data
5. memory write enable
6. memory address
7. memory write data

These signals represent the architectural effects of each instruction. A divergence between the two cores indicates that the checker core no longer matches the golden reference core.

## Completed Work

### Semester A

- Designed and implemented a single-cycle RISC CPU from scratch
- Implemented ALU, control unit, register file, instruction memory, data memory, sign extension, and PC update logic
- Integrated two identical CPU instances into a lockstep wrapper
- Implemented a basic comparator
- Verified normal lockstep execution and mismatch detection in simulation
- Delivered the mid-project presentation

### Semester B

- Extended the comparator into a full commit-bus comparator
- Replaced ad-hoc testbench forcing with reusable RTL fault-injection logic
- Added an internal faultable checker-core version for realistic internal fault campaigns
- Added a watchdog for PC-stall / hang-type faults
- Built automated fault-injection campaigns
- Collected coverage and latency results
- Added a Yosys synthesis flow for area estimation

## Final Experimental Results

| Campaign                              | Total Faults | Detected | Coverage | Max Latency |
|------------------------------------------------------------------------------------------|
| Commit-bus fault injection            | 105          | 105      | 100.00%  | 0 cycles    |
| Internal checker-core fault injection | 225 | 214    | 95.11%   | 3 cycles |             |
| Watchdog PC-hold fault                | 1            | 1        | 100.00%  | 5 cycles    |

The project meets the formal coverage and latency targets.

## Design Principles

- All RTL modules are implemented from scratch, without third-party CPU IP.
- Safety logic is kept separate from the core CPU datapath where possible.
- The comparator observes architecturally meaningful commit signals.
- Fault injection is controlled and repeatable through RTL/testbench interfaces.
- Every major safety feature has an associated testbench or automated campaign.
- Quantitative results are reported using coverage and latency metrics.

## Tools

- RTL: SystemVerilog
- Simulation: Icarus Verilog / VVP
- Waveforms: VCD-compatible viewers such as GTKWave
- Build automation: GNU Make
- Synthesis/area estimation: Yosys
