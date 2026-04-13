# ===== Tools =====
IVERILOG = iverilog
VVP      = vvp

RTL_DIR = rtl
TB_DIR  = tb

# ===== RTL files (your real names) =====
CPU_RTL = $(RTL_DIR)/alu.v \
          $(RTL_DIR)/control_unit.v \
          $(RTL_DIR)/cpu_single_cycle.v \
          $(RTL_DIR)/dmem.v \
          $(RTL_DIR)/imem.v \
          $(RTL_DIR)/register_file.v \
          $(RTL_DIR)/sign_extend.v

LOCKSTEP_RTL = $(RTL_DIR)/lockstep_top.v

# ===== Outputs =====
CPU_OUT      = cpu_sim.out
LOCKSTEP_OUT = lockstep_sim.out

# Default
all: cpu lockstep

# Single core CPU testbench
cpu: $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.v
	$(IVERILOG) -g2012 -o $(CPU_OUT) $(CPU_RTL) $(TB_DIR)/tb_cpu_basic.v
	$(VVP) $(CPU_OUT)

# Lockstep testbench
lockstep: $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.v
	$(IVERILOG) -g2012 -o $(LOCKSTEP_OUT) $(CPU_RTL) $(LOCKSTEP_RTL) $(TB_DIR)/tb_lockstep.v
	$(VVP) $(LOCKSTEP_OUT)

clean:
	rm -f *.out *.vcd

.PHONY: all cpu lockstep clean
