# FuSa Lockstep CPU — Project Briefing for Claude Code

## What This Project Is
A dual-core RISC processor implemented in Verilog RTL, designed to demonstrate
hardware fault detection via a Lockstep architecture. Two identical CPU cores run the same instruction stream in parallel; a Comparator unit checks their outputs every clock cycle and flags any mismatch. The project is a final-year engineering capstone spanning two semesters.

## Formal Quantitative Targets (from work plan — authoritative)
- Fault detection coverage: ≥ 95% of injected single-bit fault cases
- Detection latency: ≤ 5 clock cycles
- Comparator + FI logic area overhead: < 5% of combined core size (analytical estimate)

---

## Project Structure

```
fusa_cpu/
├── Makefile
├── CLAUDE.md                  ← this file
├── docs/                      ← documentation
├── rtl/                       ← all RTL source files
│   ├── cpu_single_cycle.v     ← single-cycle RISC core
│   ├── alu.v                  ← Arithmetic Logic Unit
│   ├── control_unit.v         ← instruction decode + control signals
│   ├── register_file.v        ← 32-entry register file
│   ├── imem.v                 ← instruction memory (simulation model)
│   ├── dmem.v                 ← data memory (simulation model)
│   ├── sign_extend.v          ← immediate sign extension
│   └── lockstep_top.v         ← lockstep wrapper: two cores + comparator
├── tb/                        ← testbench source files
│   ├── tb_cpu_basic.v         ← unit testbench for single CPU
│   └── tb_lockstep.v          ← integration testbench for lockstep system
├── cpu_basic.vcd              ← waveform dump (CPU)
└── lockstep.vcd               ← waveform dump (lockstep)
```

---

## Semester A — COMPLETED
All of the following are done and verified in simulation:

- Single-cycle RISC CPU (`cpu_single_cycle.v`) — fully functional
- All core sub-modules: ALU, control unit, register file, IMEM, DMEM, sign-extend
- Lockstep wrapper (`lockstep_top.v`) — instantiates two identical cores (Master + Shadow)
- Basic Comparator inside lockstep_top — compares PC and Write-Back signals each cycle
- Fault injection via forced signal override in testbench (not yet RTL module)
- Waveform evidence of: normal lockstep operation + mismatch detection on injected fault
- Mid-project presentation delivered

## Semester B — IN PROGRESS
These are the remaining tasks, in priority order:

1. **Extended Commit Bus Comparator** — expand comparison beyond PC/WB to cover more architectural signals
2. **RTL Fault Injection Unit** (`fault_inject.v`) — dedicated Verilog module to perturb signals in one core under testbench control, replacing ad-hoc force statements
3. **Watchdog Module** (`watchdog.v`) — monitors forward progress (PC must advance); detects stall/hang faults
4. **Automated Fault Injection Campaign** — scripted testbench that injects faults systematically and logs results
5. **Coverage & Latency Measurement** — post-processing (Python or log analysis) to compute detection rate and cycle latency vs. the formal targets above

### Upcoming Deadlines
| Date | Milestone |
|------|-----------|
| Apr 12, 2026 | Mid-semester progress report |
| May 24, 2026 | Poster submission |
| July–Aug 2026 | Final presentation + book submission |

---

## Architecture Summary

```
         ┌─────────────────────────────────────────────┐
         │              lockstep_top.v                  │
         │                                              │
         │  ┌──────────────┐    ┌──────────────┐        │
clk ─────┤→ │ Core A       │    │ Core B       │        │
rst ─────┤→ │ (Master)     │    │ (Shadow)     │        │
         │  │              │    │              │        │
         │  │ PC, WB_data  │    │ PC, WB_data  │        │
         │  └──────┬───────┘    └──────┬───────┘        │
         │         │                   │                 │
         │         └────────┬──────────┘                 │
         │                  ↓                            │
         │           [ Comparator ]                      │
         │                  │                            │
         │           mismatch_flag ──────────────────────┤→ output
         └─────────────────────────────────────────────┘
```

- Both cores receive identical `clk`, `rst`, and instruction memory
- Comparator checks signals every clock cycle
- On mismatch: `mismatch_now = 1` (combinational), `mismatch_latched = 1` (sticky, holds until reset)

---

## Tools & Environment
- **Language:** Verilog RTL (`.v` files)
- **Simulator:** Verilator (via Makefile)
- **Waveform viewer:** GTKWave
- **Build system:** GNU Make
- **OS:** macOS (local development)
- **Version control:** GitHub — `Jeries9947/fusa_cpu`
- **No FPGA** — simulation only

---

## Key Principles for Claude Code
- The **work plan document** is the authoritative source of truth. If anything conflicts with it, the work plan wins.
- All RTL modules are implemented from scratch — no third-party IP.
- Keep safety logic (comparator, watchdog, FI unit) clearly separated from core CPU logic.
- Every new module should have a corresponding testbench in `tb/`.
- Maintain the quantitative targets at all times: ≥95% coverage, ≤5 cycle latency, <5% area overhead.