// cpu_single_cycle.v
module cpu_single_cycle (
    input  wire clk,
    input  wire reset,
    output wire [31:0] debug_pc,
    output wire [31:0] debug_reg3,
    output wire [31:0] debug_mem0
);
    // Program counter
    reg [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;
    assign pc_plus4 = pc + 32'd4;

    // Instruction fetch
    wire [31:0] instr;
    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // Decode fields
    wire [5:0] opcode = instr[31:26];
    wire [4:0] rs     = instr[25:21];
    wire [4:0] rt     = instr[20:16];
    wire [4:0] rd     = instr[15:11];
    wire [15:0] imm16 = instr[15:0];
    wire [25:0] jaddr = instr[25:0];

    // Control signals
    wire       reg_write;
    wire       reg_dst;
    wire       alu_src_imm;
    wire       imm_unsigned;
    wire       mem_to_reg;
    wire       mem_read;
    wire       mem_write;
    wire       branch_eq;
    wire       branch_ne;
    wire       jump;
    wire [3:0] alu_ctrl;
   
    wire [31:0] rf_debug_reg3;
    wire [31:0] dmem_debug_mem0;

    control_unit u_ctrl (
        .opcode       (opcode),
        .funct        (instr[5:0]),
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
    wire [4:0]  write_reg = reg_dst ? rd : rt;
    wire [31:0] rs_data;
    wire [31:0] rt_data;
    wire [31:0] write_back_data;

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


    // Immediate
    wire [31:0] imm_sext;
    wire [31:0] imm_zext;
    sign_extend u_sext (
        .imm     (imm16),
        .imm_ext (imm_sext)
    );
    assign imm_zext = {16'b0, imm16};

    wire [31:0] alu_b = alu_src_imm ?
                        (imm_unsigned ? imm_zext : imm_sext) :
                        rt_data;

    // ALU
    wire [31:0] alu_result;
    wire        alu_zero;
    alu u_alu (
        .a        (rs_data),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // Data memory
    wire [31:0] mem_read_data;
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
    wire [31:0] branch_offset = imm_sext << 2;
    wire [31:0] branch_target = pc_plus4 + branch_offset;
    wire        take_branch   = (branch_eq & alu_zero) | (branch_ne & ~alu_zero);

    wire [31:0] jump_target = {pc_plus4[31:28], jaddr, 2'b00};

    assign pc_next = jump        ? jump_target :
                     take_branch ? branch_target :
                                   pc_plus4;

    // PC update
    always @(posedge clk) begin
        if (reset)
            pc <= 32'b0;
        else
            pc <= pc_next;
    end

    // Simple debug taps (for now, only PC is meaningful)
    assign debug_pc   = pc;
    assign debug_reg3 = rf_debug_reg3;
    assign debug_mem0 = dmem_debug_mem0;


endmodule
