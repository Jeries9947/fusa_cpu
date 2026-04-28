// watchdog.v
// Monitors forward progress of both CPU cores in the lockstep system.
//
// Each core is independently watched. A stall is declared when a core's
// PC does not change for TIMEOUT consecutive clock cycles. The threshold
// is set via the TIMEOUT parameter (default 16 cycles), giving enough
// slack for multi-cycle instruction sequences while still meeting the
// project requirement of ≤5 cycle detection latency for hang faults.
//
// Outputs
//   stall_a        : Core A has been stuck for TIMEOUT cycles (combinational)
//   stall_b        : Core B has been stuck for TIMEOUT cycles (combinational)
//   stall_any      : OR of stall_a and stall_b
//   stall_latched  : sticky flag — set on first stall, cleared only by reset

module watchdog #(
    parameter TIMEOUT = 16   // cycles before a non-advancing PC is a fault
) (
    input  wire        clk,
    input  wire        reset,
    input  wire        clear,          // synchronous clear of stall_latched

    input  wire [31:0] pc_a,   // current PC from Core A
    input  wire [31:0] pc_b,   // current PC from Core B

    output wire        stall_a,
    output wire        stall_b,
    output wire        stall_any,
    output reg         stall_latched
);

    // Number of counter bits needed to represent TIMEOUT
    localparam CTR_BITS = $clog2(TIMEOUT + 1);

    // ------------------------------------------------------------------ //
    //  Per-core stall counters
    // ------------------------------------------------------------------ //

    reg [31:0]    pc_a_prev, pc_b_prev;
    reg [CTR_BITS-1:0] ctr_a, ctr_b;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_a_prev <= 32'b0;
            pc_b_prev <= 32'b0;
            ctr_a     <= {CTR_BITS{1'b0}};
            ctr_b     <= {CTR_BITS{1'b0}};
        end else begin
            // Core A
            pc_a_prev <= pc_a;
            if (pc_a != pc_a_prev)
                ctr_a <= {CTR_BITS{1'b0}};
            else if (ctr_a != TIMEOUT[CTR_BITS-1:0])
                ctr_a <= ctr_a + 1'b1;

            // Core B
            pc_b_prev <= pc_b;
            if (pc_b != pc_b_prev)
                ctr_b <= {CTR_BITS{1'b0}};
            else if (ctr_b != TIMEOUT[CTR_BITS-1:0])
                ctr_b <= ctr_b + 1'b1;
        end
    end

    // ------------------------------------------------------------------ //
    //  Stall flags
    // ------------------------------------------------------------------ //

    assign stall_a   = (ctr_a == TIMEOUT[CTR_BITS-1:0]);
    assign stall_b   = (ctr_b == TIMEOUT[CTR_BITS-1:0]);
    assign stall_any = stall_a | stall_b;

    // Sticky latch — cleared by async reset or synchronous clear pulse
    always @(posedge clk or posedge reset) begin
        if (reset)
            stall_latched <= 1'b0;
        else if (clear)
            stall_latched <= 1'b0;
        else if (stall_any)
            stall_latched <= 1'b1;
    end

endmodule
