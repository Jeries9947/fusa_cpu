// comparator.v
// Extended Commit Bus Comparator for the lockstep system.
//
// Checks seven architectural signals every clock cycle:
//   1. commit_pc_next  — next program counter
//   2. commit_reg_we   — register write enable
//   3. commit_reg_addr — destination register address
//   4. commit_reg_data — register write-back data
//   5. commit_mem_we   — data memory write enable
//   6. commit_mem_addr — memory address
//   7. commit_mem_data — memory write data
//
// All inputs are combinational (driven by the cores' commit buses).
// mismatch_now  : asserted immediately in the cycle a divergence is seen.
// mismatch_latched : sticky; cleared only by reset.
// mismatch_field   : one-hot encoded, identifies which field(s) diverged
//                    (useful for fault diagnosis in simulation).
//
// Field encoding for mismatch_field[6:0]:
//   [0] pc_next
//   [1] reg_we
//   [2] reg_addr
//   [3] reg_data
//   [4] mem_we
//   [5] mem_addr
//   [6] mem_data

module comparator (
    input  wire        clk,
    input  wire        reset,
    input  wire        clear,          // synchronous clear of mismatch_latched

    // Core A commit bus
    input  wire [31:0] a_pc_next,
    input  wire        a_reg_we,
    input  wire [4:0]  a_reg_addr,
    input  wire [31:0] a_reg_data,
    input  wire        a_mem_we,
    input  wire [31:0] a_mem_addr,
    input  wire [31:0] a_mem_data,

    // Core B commit bus
    input  wire [31:0] b_pc_next,
    input  wire        b_reg_we,
    input  wire [4:0]  b_reg_addr,
    input  wire [31:0] b_reg_data,
    input  wire        b_mem_we,
    input  wire [31:0] b_mem_addr,
    input  wire [31:0] b_mem_data,

    // Outputs
    output wire        mismatch_now,
    output reg         mismatch_latched,
    output wire [6:0]  mismatch_field    // one-hot per diverging field
);

    // Per-field mismatch flags (combinational)
    wire f_pc_next  = (a_pc_next  != b_pc_next);
    wire f_reg_we   = (a_reg_we   != b_reg_we);
    wire f_reg_addr = (a_reg_addr != b_reg_addr);
    wire f_reg_data = (a_reg_data != b_reg_data);
    wire f_mem_we   = (a_mem_we   != b_mem_we);
    wire f_mem_addr = (a_mem_addr != b_mem_addr);
    wire f_mem_data = (a_mem_data != b_mem_data);

    assign mismatch_field = {f_mem_data, f_mem_addr, f_mem_we,
                             f_reg_data, f_reg_addr, f_reg_we, f_pc_next};

    assign mismatch_now = |mismatch_field;

    // Sticky latch — cleared by async reset or synchronous clear pulse
    always @(posedge clk or posedge reset) begin
        if (reset)
            mismatch_latched <= 1'b0;
        else if (clear)
            mismatch_latched <= 1'b0;
        else if (mismatch_now)
            mismatch_latched <= 1'b1;
    end

endmodule
