# ===== Tools =====
IVERILOG = iverilog
VVP      = vvp
YOSYS    = yosys
PYTHON   = python3

RTL_DIR = rtl
TB_DIR  = tb
SYNTH_DIR = synth

# ===== RTL files =====
CPU_RTL = $(RTL_DIR)/alu.sv \
          $(RTL_DIR)/control_unit.sv \
          $(RTL_DIR)/cpu_single_cycle.sv \
          $(RTL_DIR)/dmem.sv \
          $(RTL_DIR)/imem.sv \
          $(RTL_DIR)/register_file.sv \
          $(RTL_DIR)/sign_extend.sv

LOCKSTEP_RTL = $(RTL_DIR)/fault_inject.sv \
               $(RTL_DIR)/comparator.sv \
               $(RTL_DIR)/watchdog.sv \
               $(RTL_DIR)/lockstep_top.sv

INTERNAL_FAULT_RTL = $(RTL_DIR)/fault_inject.sv \
                     $(RTL_DIR)/comparator.sv \
                     $(RTL_DIR)/watchdog.sv \
                     $(RTL_DIR)/cpu_single_cycle_faultable.sv \
                     $(RTL_DIR)/lockstep_top_internal_fault.sv

# ===== Outputs =====
CPU_OUT               = cpu_sim.out
LOCKSTEP_OUT          = lockstep_sim.out
CAMPAIGN_OUT          = fault_campaign_sim.out
INTERNAL_CAMPAIGN_OUT = internal_fault_campaign_sim.out
WATCHDOG_CAMPAIGN_OUT = watchdog_campaign_sim.out

# Default
all: cpu lockstep

# Single-core CPU testbench
cpu: $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.sv
	$(IVERILOG) -g2012 -o $(CPU_OUT) $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.sv
	$(VVP) $(CPU_OUT)

# Lockstep integration testbench
lockstep: $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.sv
	$(IVERILOG) -g2012 -o $(LOCKSTEP_OUT) $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.sv
	$(VVP) $(LOCKSTEP_OUT)

# Campaign 1: Commit-bus RTL fault injection campaign
fault_campaign: $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_fault_campaign.sv
	$(IVERILOG) -g2012 -o $(CAMPAIGN_OUT) $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_fault_campaign.sv
	$(VVP) $(CAMPAIGN_OUT)

# Campaign 2: Internal checker-core fault injection campaign
internal_fault_campaign: $(CPU_RTL) $(INTERNAL_FAULT_RTL) $(TB_DIR)/tb_internal_fault_campaign.sv
	$(IVERILOG) -g2012 -o $(INTERNAL_CAMPAIGN_OUT) $(CPU_RTL) $(INTERNAL_FAULT_RTL) $(TB_DIR)/tb_internal_fault_campaign.sv
	$(VVP) $(INTERNAL_CAMPAIGN_OUT)

# Campaign 3: Watchdog / hang detection campaign
watchdog_campaign: $(CPU_RTL) $(INTERNAL_FAULT_RTL) $(TB_DIR)/tb_watchdog_campaign.sv
	$(IVERILOG) -g2012 -o $(WATCHDOG_CAMPAIGN_OUT) $(CPU_RTL) $(INTERNAL_FAULT_RTL) $(TB_DIR)/tb_watchdog_campaign.sv
	$(VVP) $(WATCHDOG_CAMPAIGN_OUT)

# Run all fault-injection experiments
campaigns: fault_campaign internal_fault_campaign watchdog_campaign

# Synthesis: baseline CPU only
synth_baseline:
	$(YOSYS) -s $(SYNTH_DIR)/baseline_cpu.ys | tee $(SYNTH_DIR)/baseline_cpu_report.txt

# Synthesis: full lockstep system
synth_lockstep:
	$(YOSYS) -s $(SYNTH_DIR)/lockstep_system.ys | tee $(SYNTH_DIR)/lockstep_system_report.txt

# Run both synthesis reports
synth: synth_baseline synth_lockstep

# Parse Yosys reports and generate area summary
area_summary:
	$(PYTHON) scripts/area_from_yosys.py

clean:
	rm -f *.out *.vcd fault_results.csv internal_fault_results.csv

.PHONY: all cpu lockstep fault_campaign internal_fault_campaign watchdog_campaign campaigns synth_baseline synth_lockstep synth area_summary clean
