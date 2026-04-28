// cpu_single_cycle.sv
module cpu_single_cycle (
    input  logic clk,
    input  logic reset,

    // Legacy debug taps (kept for waveform compatibility)
    output logic [31:0] debug_pc,
    output logic [31:0] debug_reg3,
    output logic [31:0] debug_mem0,

    // Commit bus — architectural state written this cycle.
    // Driven combinationally so the lockstep comparator can check
    // both cores in the same clock phase.
    output logic [31:0] commit_pc_next,   // next PC value
    output logic        commit_reg_we,    // register file write enable
    output logic [4:0]  commit_reg_addr,  // destination register
    output logic [31:0] commit_reg_data,  // write-back data
    output logic        commit_mem_we,    // data memory write enable
    output logic [31:0] commit_mem_addr,  // memory address (ALU result)
    output logic [31:0] commit_mem_data   // memory write data
);

    // Program counter
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic [31:0] pc_plus4;
    assign pc_plus4 = pc + 32'd4;

    // Instruction fetch
    logic [31:0] instr;
    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // Decode fields
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

    // Control signals
    logic        reg_write;
    logic        reg_dst;
    logic        alu_src_imm;
    logic        imm_unsigned;
    logic        mem_to_reg;
    logic        mem_read;
    logic        mem_write;
    logic        branch_eq;
    logic        branch_ne;
    logic        jump;
    logic [3:0]  alu_ctrl;

    logic [31:0] rf_debug_reg3;
    logic [31:0] dmem_debug_mem0;

    control_unit u_ctrl (
        .opcode       (opcode),
        .funct        (funct),
        .reg_write    (reg_write),
        .reg_dst      (reg_dst),
        .alu_src_imm  (alu_src_imm),
        .imm_unsigned (imm_unsigned),
        .mem_to_reg   (mem_to_reg),
        .mem_read     (mem_read),
        .mem_write    (mem_write),
        .branch_eq    (branch_eq),
        .branch_ne    (branch_ne),
        .jump         (jump),
        .alu_ctrl     (alu_ctrl)
    );

    // Register file
    logic [4:0]  write_reg;
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
        .rs_data    (rs_data),
        .rt_data    (rt_data),
        .debug_reg3 (rf_debug_reg3)
    );

    // Immediate (sign- or zero-extended, selected by imm_unsigned)
    logic [31:0] imm_ext;

    sign_extend u_sext (
        .imm         (imm16),
        .imm_unsigned(imm_unsigned),
        .imm_ext     (imm_ext)
    );

    // ALU second operand: rt_data or immediate
    logic [31:0] alu_b;
    assign alu_b = alu_src_imm ? imm_ext : rt_data;

    // ALU
    logic [31:0] alu_result;
    logic        alu_zero;
    alu u_alu (
        .a        (rs_data),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // Data memory
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

    // Write back
    assign write_back_data = mem_to_reg ? mem_read_data : alu_result;

    // Branch and jump
    logic [31:0] branch_offset;
    logic [31:0] branch_target;
    logic        take_branch;
    logic [31:0] jump_target;

    assign branch_offset = imm_ext << 2;
    assign branch_target = pc_plus4 + branch_offset;
    assign take_branch   = (branch_eq & alu_zero) | (branch_ne & ~alu_zero);
    assign jump_target   = {pc_plus4[31:28], jaddr, 2'b00};

    assign pc_next = jump        ? jump_target  :
                     take_branch ? branch_target :
                                   pc_plus4;

    // PC update
    always_ff @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

    // Legacy debug taps
    assign debug_pc   = pc;
    assign debug_reg3 = rf_debug_reg3;
    assign debug_mem0 = dmem_debug_mem0;

    // Commit bus
    assign commit_pc_next  = pc_next;
    assign commit_reg_we   = reg_write;
    assign commit_reg_addr = write_reg;
    assign commit_reg_data = write_back_data;
    assign commit_mem_we   = mem_write;
    assign commit_mem_addr = alu_result;
    assign commit_mem_data = rt_data;

endmodule
