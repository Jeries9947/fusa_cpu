// lockstep_top.v
module lockstep_top (
    input  wire        clk,
    input  wire        reset,

    output wire [31:0] pc0,
    output wire [31:0] pc1,
    output wire [31:0] reg3_0,
    output wire [31:0] reg3_1,
    output wire [31:0] mem0_0,
    output wire [31:0] mem0_1,

    output wire        mismatch_now,   // combinational compare
    output reg         mismatch_latched // sticky error flag
);
    // Core 0 (master)
    cpu_single_cycle core0 (
        .clk        (clk),
        .reset      (reset),
        .debug_pc   (pc0),
        .debug_reg3 (reg3_0),
        .debug_mem0 (mem0_0)
    );

    // Core 1 (checker)
    cpu_single_cycle core1 (
        .clk        (clk),
        .reset      (reset),
        .debug_pc   (pc1),
        .debug_reg3 (reg3_1),
        .debug_mem0 (mem0_1)
    );

    // Simple comparator - for now we compare:
    // - PC
    // - reg3
    // - mem[0]
    assign mismatch_now =
           (pc0    != pc1)   ||
           (reg3_0 != reg3_1) ||
           (mem0_0 != mem0_1);

    // Sticky flag that latches any mismatch
    always @(posedge clk or posedge reset) begin
        if (reset)
            mismatch_latched <= 1'b0;
        else if (mismatch_now)
            mismatch_latched <= 1'b1;
    end

endmodule
