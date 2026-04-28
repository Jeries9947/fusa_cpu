# ===== Tools =====
IVERILOG = iverilog
VVP      = vvp

RTL_DIR = rtl
TB_DIR  = tb

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

# ===== Outputs =====
CPU_OUT      = cpu_sim.out
LOCKSTEP_OUT = lockstep_sim.out
CAMPAIGN_OUT = fault_campaign_sim.out

# Default
all: cpu lockstep

# Single core CPU testbench
cpu: $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.sv
	$(IVERILOG) -g2012 -o $(CPU_OUT) $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.sv
	$(VVP) $(CPU_OUT)

# Lockstep testbench
lockstep: $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.sv
	$(IVERILOG) -g2012 -o $(LOCKSTEP_OUT) $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.sv
	$(VVP) $(LOCKSTEP_OUT)

# Fault injection campaign testbench
fault_campaign: $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_fault_campaign.sv
	$(IVERILOG) -g2012 -o $(CAMPAIGN_OUT) $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_fault_campaign.sv
	$(VVP) $(CAMPAIGN_OUT)

clean:
	rm -f *.out *.vcd

.PHONY: all cpu lockstep fault_campaign clean
