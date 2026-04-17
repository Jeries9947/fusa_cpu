// lockstep_top.v
module lockstep_top (
    input  wire        clk,
    input  wire        reset,
    input  wire        fault_en,

    output wire [31:0] pc0,
    output wire [31:0] pc1,
    output wire [31:0] reg3_0,
    output wire [31:0] reg3_1,
    output wire [31:0] mem0_0,
    output wire [31:0] mem0_1,

    output wire        mismatch_now,    // combinational compare
    output reg         mismatch_latched // sticky error flag
);

    wire [31:0] reg3_1_raw;
    wire [31:0] reg3_1_faulted;

    assign reg3_1 = reg3_1_faulted;

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
        .debug_reg3 (reg3_1_raw),
        .debug_mem0 (mem0_1)
    );

    // Fault injection on checker reg3
    fault_inject fi_reg3 (
        .in_signal  (reg3_1_raw),
        .fault_en   (fault_en),
        .fault_value(32'hDEADBEEF),
        .out_signal (reg3_1_faulted)
    );

    // Simple comparator - for now we compare:
    // - PC
    // - reg3
    // - mem[0]
    assign mismatch_now =
           (pc0    != pc1)            ||
           (reg3_0 != reg3_1_faulted) ||
           (mem0_0 != mem0_1);

    // Sticky flag that latches any mismatch
    always @(posedge clk or posedge reset) begin
        if (reset)
            mismatch_latched <= 1'b0;
        else if (mismatch_now)
            mismatch_latched <= 1'b1;
    end

endmodule