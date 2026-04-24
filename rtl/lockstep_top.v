module lockstep_top (
    input  wire        clk,
    input  wire        reset,

    input  wire        fault_en,
    input  wire [1:0]  fault_sel,
    input  wire [31:0] fault_mask,
    input  wire        clear_latched,

    output wire [31:0] pc0,
    output wire [31:0] pc1,
    output wire [31:0] reg3_0,
    output wire [31:0] reg3_1,
    output wire [31:0] mem0_0,
    output wire [31:0] mem0_1,

    output wire        mismatch_now,
    output reg         mismatch_latched
);

    localparam FAULT_NONE = 2'd0;
    localparam FAULT_REG3 = 2'd1;
    localparam FAULT_PC   = 2'd2;

    wire [31:0] pc1_raw;
    wire [31:0] pc1_faulted;

    wire [31:0] reg3_1_raw;
    wire [31:0] reg3_1_faulted;

    wire fault_reg3_en;
    wire fault_pc_en;

    assign fault_reg3_en = fault_en && (fault_sel == FAULT_REG3);
    assign fault_pc_en   = fault_en && (fault_sel == FAULT_PC);

    assign pc1    = pc1_faulted;
    assign reg3_1 = reg3_1_faulted;

    cpu_single_cycle core0 (
        .clk        (clk),
        .reset      (reset),
        .debug_pc   (pc0),
        .debug_reg3 (reg3_0),
        .debug_mem0 (mem0_0)
    );

    cpu_single_cycle core1 (
        .clk        (clk),
        .reset      (reset),
        .debug_pc   (pc1_raw),
        .debug_reg3 (reg3_1_raw),
        .debug_mem0 (mem0_1)
    );

    fault_inject fi_pc (
        .in_signal  (pc1_raw),
        .fault_en   (fault_pc_en),
        .fault_mask (fault_mask),
        .out_signal (pc1_faulted)
    );

    fault_inject fi_reg3 (
        .in_signal  (reg3_1_raw),
        .fault_en   (fault_reg3_en),
        .fault_mask (fault_mask),
        .out_signal (reg3_1_faulted)
    );

    assign mismatch_now =
           (pc0    != pc1_faulted)    ||
           (reg3_0 != reg3_1_faulted) ||
           (mem0_0 != mem0_1);

    always @(posedge clk or posedge reset) begin
        if (reset)
            mismatch_latched <= 1'b0;
        else if (clear_latched)
            mismatch_latched <= 1'b0;
        else if (mismatch_now)
            mismatch_latched <= 1'b1;
    end

endmodule