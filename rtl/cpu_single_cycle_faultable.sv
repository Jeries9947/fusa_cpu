// cpu_single_cycle_faultable.sv
//
// Faultable version of the single-cycle CPU.
// This module is intended for the checker/shadow core only.
//
// The clean master core should still use cpu_single_cycle.sv.
// This faultable CPU adds internal RTL fault injection points before
// selected internal signals propagate to the commit bus.
//
// Internal fault targets:
//   0  = NONE
//   1  = ALU_RESULT
//   2  = RS_DATA
//   3  = RT_DATA
//   4  = REG_WRITE
//   5  = MEM_WRITE
//   6  = PC_NEXT
//   7  = WB_DATA
//   8  = PC_HOLD
//   9  = ALU_SRC_IMM
//   10 = REG_DST
//   11 = MEM_TO_REG
//   12 = BRANCH_EQ
//   13 = BRANCH_NE
//   14 = JUMP
//   15 = ALU_CTRL

module cpu_single_cycle_faultable (
    input  logic clk,
    input  logic reset,

    // Internal fault injection control
    input  logic        int_fault_en,
    input  logic [3:0]  int_fault_sel,
    input  logic [31:0] int_fault_mask,

    // Legacy debug taps
    output logic [31:0] debug_pc,
    output logic [31:0] debug_reg3,
    output logic [31:0] debug_mem0,

    // Commit bus
    output logic [31:0] commit_pc_next,
    output logic        commit_reg_we,
    output logic [4:0]  commit_reg_addr,
    output logic [31:0] commit_reg_data,
    output logic        commit_mem_we,
    output logic [31:0] commit_mem_addr,
    output logic [31:0] commit_mem_data
);

    // ------------------------------------------------------------
    // Internal fault select encoding
    // ------------------------------------------------------------
    localparam logic [3:0] INT_FAULT_NONE        = 4'd0;
    localparam logic [3:0] INT_FAULT_ALU_RESULT  = 4'd1;
    localparam logic [3:0] INT_FAULT_RS_DATA     = 4'd2;
    localparam logic [3:0] INT_FAULT_RT_DATA     = 4'd3;
    localparam logic [3:0] INT_FAULT_REG_WRITE   = 4'd4;
    localparam logic [3:0] INT_FAULT_MEM_WRITE   = 4'd5;
    localparam logic [3:0] INT_FAULT_PC_NEXT     = 4'd6;
    localparam logic [3:0] INT_FAULT_WB_DATA     = 4'd7;
    localparam logic [3:0] INT_FAULT_PC_HOLD     = 4'd8;
    localparam logic [3:0] INT_FAULT_ALU_SRC_IMM = 4'd9;
    localparam logic [3:0] INT_FAULT_REG_DST     = 4'd10;
    localparam logic [3:0] INT_FAULT_MEM_TO_REG  = 4'd11;
    localparam logic [3:0] INT_FAULT_BRANCH_EQ   = 4'd12;
    localparam logic [3:0] INT_FAULT_BRANCH_NE   = 4'd13;
    localparam logic [3:0] INT_FAULT_JUMP        = 4'd14;
    localparam logic [3:0] INT_FAULT_ALU_CTRL    = 4'd15;

    // ------------------------------------------------------------
    // Program counter
    // ------------------------------------------------------------
    logic [31:0] pc;
    logic [31:0] pc_next_raw;
    logic [31:0] pc_next;
    logic [31:0] pc_plus4;

    assign pc_plus4 = pc + 32'd4;

    // ------------------------------------------------------------
    // Instruction fetch
    // ------------------------------------------------------------
    logic [31:0] instr;

    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // ------------------------------------------------------------
    // Decode fields
    // ------------------------------------------------------------
    logic [5:0]  opcode;
    logic [4:0]  rs;
    logic [4:0]  rt;
    logic [4:0]  rd;
    logic [15:0] imm16;
    logic [25:0] jaddr;
    logic [5:0]  funct;

    assign opcode = instr[31:26];
    assign rs     = instr[25:21];
    assign rt     = instr[20:16];
    assign rd     = instr[15:11];
    assign imm16  = instr[15:0];
    assign jaddr  = instr[25:0];
    assign funct  = instr[5:0];

    // ------------------------------------------------------------
    // Control signals
    // ------------------------------------------------------------
    logic        reg_write_raw;
    logic        reg_write;

    logic        reg_dst_raw;
    logic        reg_dst;

    logic        alu_src_imm_raw;
    logic        alu_src_imm;

    logic        imm_unsigned;

    logic        mem_to_reg_raw;
    logic        mem_to_reg;

    logic        mem_read;

    logic        mem_write_raw;
    logic        mem_write;

    logic        branch_eq_raw;
    logic        branch_eq;

    logic        branch_ne_raw;
    logic        branch_ne;

    logic        jump_raw;
    logic        jump;

    logic [3:0]  alu_ctrl_raw;
    logic [3:0]  alu_ctrl;

    logic [31:0] rf_debug_reg3;
    logic [31:0] dmem_debug_mem0;

    control_unit u_ctrl (
        .opcode       (opcode),
        .funct        (funct),
        .reg_write    (reg_write_raw),
        .reg_dst      (reg_dst_raw),
        .alu_src_imm  (alu_src_imm_raw),
        .imm_unsigned (imm_unsigned),
        .mem_to_reg   (mem_to_reg_raw),
        .mem_read     (mem_read),
        .mem_write    (mem_write_raw),
        .branch_eq    (branch_eq_raw),
        .branch_ne    (branch_ne_raw),
        .jump         (jump_raw),
        .alu_ctrl     (alu_ctrl_raw)
    );

    // ------------------------------------------------------------
    // Control signal fault injection
    // ------------------------------------------------------------

    fault_inject #(.WIDTH(1)) fi_reg_write (
        .in_signal  (reg_write_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_REG_WRITE)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (reg_write)
    );

    fault_inject #(.WIDTH(1)) fi_mem_write (
        .in_signal  (mem_write_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_MEM_WRITE)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (mem_write)
    );

    fault_inject #(.WIDTH(1)) fi_alu_src_imm (
        .in_signal  (alu_src_imm_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_ALU_SRC_IMM)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (alu_src_imm)
    );

    fault_inject #(.WIDTH(1)) fi_reg_dst (
        .in_signal  (reg_dst_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_REG_DST)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (reg_dst)
    );

    fault_inject #(.WIDTH(1)) fi_mem_to_reg (
        .in_signal  (mem_to_reg_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_MEM_TO_REG)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (mem_to_reg)
    );

    fault_inject #(.WIDTH(1)) fi_branch_eq (
        .in_signal  (branch_eq_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_BRANCH_EQ)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (branch_eq)
    );

    fault_inject #(.WIDTH(1)) fi_branch_ne (
        .in_signal  (branch_ne_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_BRANCH_NE)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (branch_ne)
    );

    fault_inject #(.WIDTH(1)) fi_jump (
        .in_signal  (jump_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_JUMP)),
        .fault_mask (int_fault_mask[0]),
        .out_signal (jump)
    );

    fault_inject #(.WIDTH(4)) fi_alu_ctrl (
        .in_signal  (alu_ctrl_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_ALU_CTRL)),
        .fault_mask (int_fault_mask[3:0]),
        .out_signal (alu_ctrl)
    );

    // ------------------------------------------------------------
    // Register file
    // ------------------------------------------------------------
    logic [4:0]  write_reg;
    logic [31:0] rs_data_raw;
    logic [31:0] rt_data_raw;
    logic [31:0] rs_data;
    logic [31:0] rt_data;
    logic [31:0] write_back_data;

    assign write_reg = reg_dst ? rd : rt;

    register_file u_rf (
        .clk        (clk),
        .reset      (reset),
        .reg_write  (reg_write),
        .rs_addr    (rs),
        .rt_addr    (rt),
        .rd_addr    (write_reg),
        .write_data (write_back_data),
        .rs_data    (rs_data_raw),
        .rt_data    (rt_data_raw),
        .debug_reg3 (rf_debug_reg3)
    );

    fault_inject #(.WIDTH(32)) fi_rs_data (
        .in_signal  (rs_data_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_RS_DATA)),
        .fault_mask (int_fault_mask),
        .out_signal (rs_data)
    );

    fault_inject #(.WIDTH(32)) fi_rt_data (
        .in_signal  (rt_data_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_RT_DATA)),
        .fault_mask (int_fault_mask),
        .out_signal (rt_data)
    );

    // ------------------------------------------------------------
    // Immediate extension
    // ------------------------------------------------------------
    logic [31:0] imm_ext;

    sign_extend u_sext (
        .imm          (imm16),
        .imm_unsigned (imm_unsigned),
        .imm_ext      (imm_ext)
    );

    // ------------------------------------------------------------
    // ALU second operand
    // ------------------------------------------------------------
    logic [31:0] alu_b;

    assign alu_b = alu_src_imm ? imm_ext : rt_data;

    // ------------------------------------------------------------
    // ALU
    // ------------------------------------------------------------
    logic [31:0] alu_result_raw;
    logic [31:0] alu_result;
    logic        alu_zero;

    alu u_alu (
        .a        (rs_data),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result_raw),
        .zero     (alu_zero)
    );

    fault_inject #(.WIDTH(32)) fi_alu_result (
        .in_signal  (alu_result_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_ALU_RESULT)),
        .fault_mask (int_fault_mask),
        .out_signal (alu_result)
    );

    // ------------------------------------------------------------
    // Data memory
    // ------------------------------------------------------------
    logic [31:0] mem_read_data;

    dmem u_dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (alu_result),
        .write_data (rt_data),
        .read_data  (mem_read_data),
        .debug_mem0 (dmem_debug_mem0)
    );

    // ------------------------------------------------------------
    // Write back
    // ------------------------------------------------------------
    logic [31:0] write_back_data_raw;

    assign write_back_data_raw = mem_to_reg ? mem_read_data : alu_result;

    fault_inject #(.WIDTH(32)) fi_wb_data (
        .in_signal  (write_back_data_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_WB_DATA)),
        .fault_mask (int_fault_mask),
        .out_signal (write_back_data)
    );

    // ------------------------------------------------------------
    // Branch and jump
    // ------------------------------------------------------------
    logic [31:0] branch_offset;
    logic [31:0] branch_target;
    logic        take_branch;
    logic [31:0] jump_target;

    assign branch_offset = imm_ext << 2;
    assign branch_target = pc_plus4 + branch_offset;
    assign take_branch   = (branch_eq & alu_zero) | (branch_ne & ~alu_zero);
    assign jump_target   = {pc_plus4[31:28], jaddr, 2'b00};

    assign pc_next_raw = jump        ? jump_target    :
                         take_branch ? branch_target  :
                                       pc_plus4;

    fault_inject #(.WIDTH(32)) fi_pc_next (
        .in_signal  (pc_next_raw),
        .fault_en   (int_fault_en && (int_fault_sel == INT_FAULT_PC_NEXT)),
        .fault_mask (int_fault_mask),
        .out_signal (pc_next)
    );

    // ------------------------------------------------------------
    // PC update
    //
    // INT_FAULT_PC_HOLD models a hang/stall fault:
    // the checker core keeps the same PC instead of progressing.
    // ------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else if (int_fault_en && (int_fault_sel == INT_FAULT_PC_HOLD))
            pc <= pc;
        else
            pc <= pc_next;
    end

    // ------------------------------------------------------------
    // Debug taps
    // ------------------------------------------------------------
    assign debug_pc   = pc;
    assign debug_reg3 = rf_debug_reg3;
    assign debug_mem0 = dmem_debug_mem0;

    // ------------------------------------------------------------
    // Commit bus
    // ------------------------------------------------------------
    assign commit_pc_next  = pc_next;
    assign commit_reg_we   = reg_write;
    assign commit_reg_addr = write_reg;
    assign commit_reg_data = write_back_data;
    assign commit_mem_we   = mem_write;
    assign commit_mem_addr = alu_result;
    assign commit_mem_data = rt_data;

endmodule