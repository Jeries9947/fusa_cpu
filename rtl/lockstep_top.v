// lockstep_top.v
// Lockstep wrapper: instantiates two identical CPU cores (Master + Shadow)
// and connects their commit buses through fault injection to the extended
// comparator and watchdog.

module lockstep_top (
    input  wire        clk,
    input  wire        reset,

    // Fault injection control
    input  wire        fault_en,       // enable fault injection on Core B
    input  wire [1:0]  fault_sel,      // which commit-bus field to perturb
    input  wire [31:0] fault_mask,     // XOR mask applied to selected field
    input  wire        clear_latched,  // synchronously clears mismatch/stall latches

    // Legacy debug taps (kept for waveform / testbench compatibility)
    output wire [31:0] pc0,            // Core A current PC
    output wire [31:0] pc1,            // Core B current PC
    output wire [31:0] reg3_0,
    output wire [31:0] reg3_1,
    output wire [31:0] mem0_0,
    output wire [31:0] mem0_1,

    // Commit bus — Core A (raw, no fault injection)
    output wire [31:0] a_pc_next,
    output wire        a_reg_we,
    output wire [4:0]  a_reg_addr,
    output wire [31:0] a_reg_data,
    output wire        a_mem_we,
    output wire [31:0] a_mem_addr,
    output wire [31:0] a_mem_data,

    // Commit bus — Core B (after fault injection on selected field)
    output wire [31:0] b_pc_next,
    output wire        b_reg_we,
    output wire [4:0]  b_reg_addr,
    output wire [31:0] b_reg_data,
    output wire        b_mem_we,
    output wire [31:0] b_mem_addr,
    output wire [31:0] b_mem_data,

    // Comparator fault detection outputs
    output wire        mismatch_now,
    output wire        mismatch_latched,
    output wire [6:0]  mismatch_field,  // one-hot: identifies diverging field

    // Watchdog fault detection outputs
    output wire        stall_a,
    output wire        stall_b,
    output wire        stall_any,
    output wire        stall_latched
);

    // fault_sel encoding
    localparam FAULT_NONE     = 2'd0;
    localparam FAULT_PC       = 2'd1;   // perturb Core B commit_pc_next
    localparam FAULT_REG_DATA = 2'd2;   // perturb Core B commit_reg_data
    localparam FAULT_MEM_DATA = 2'd3;   // perturb Core B commit_mem_data

    // ------------------------------------------------------------------ //
    //  Core A (Master)
    // ------------------------------------------------------------------ //
    cpu_single_cycle core_a (
        .clk             (clk),
        .reset           (reset),
        .debug_pc        (pc0),
        .debug_reg3      (reg3_0),
        .debug_mem0      (mem0_0),
        .commit_pc_next  (a_pc_next),
        .commit_reg_we   (a_reg_we),
        .commit_reg_addr (a_reg_addr),
        .commit_reg_data (a_reg_data),
        .commit_mem_we   (a_mem_we),
        .commit_mem_addr (a_mem_addr),
        .commit_mem_data (a_mem_data)
    );

    // ------------------------------------------------------------------ //
    //  Core B (Shadow / Checker) — raw commit bus, before fault injection
    // ------------------------------------------------------------------ //
    wire [31:0] b_pc_next_raw;
    wire [31:0] b_reg_data_raw;
    wire [31:0] b_mem_data_raw;

    cpu_single_cycle core_b (
        .clk             (clk),
        .reset           (reset),
        .debug_pc        (pc1),
        .debug_reg3      (reg3_1),
        .debug_mem0      (mem0_1),
        .commit_pc_next  (b_pc_next_raw),
        .commit_reg_we   (b_reg_we),
        .commit_reg_addr (b_reg_addr),
        .commit_reg_data (b_reg_data_raw),
        .commit_mem_we   (b_mem_we),
        .commit_mem_addr (b_mem_addr),
        .commit_mem_data (b_mem_data_raw)
    );

    // ------------------------------------------------------------------ //
    //  Fault Injection — XOR mask applied to one Core B commit-bus field
    // ------------------------------------------------------------------ //
    fault_inject fi_pc (
        .in_signal  (b_pc_next_raw),
        .fault_en   (fault_en & (fault_sel == FAULT_PC)),
        .fault_mask (fault_mask),
        .out_signal (b_pc_next)
    );

    fault_inject fi_reg (
        .in_signal  (b_reg_data_raw),
        .fault_en   (fault_en & (fault_sel == FAULT_REG_DATA)),
        .fault_mask (fault_mask),
        .out_signal (b_reg_data)
    );

    fault_inject fi_mem (
        .in_signal  (b_mem_data_raw),
        .fault_en   (fault_en & (fault_sel == FAULT_MEM_DATA)),
        .fault_mask (fault_mask),
        .out_signal (b_mem_data)
    );

    // ------------------------------------------------------------------ //
    //  Extended Commit Bus Comparator
    // ------------------------------------------------------------------ //
    comparator u_cmp (
        .clk             (clk),
        .reset           (reset),
        .clear           (clear_latched),

        .a_pc_next       (a_pc_next),
        .a_reg_we        (a_reg_we),
        .a_reg_addr      (a_reg_addr),
        .a_reg_data      (a_reg_data),
        .a_mem_we        (a_mem_we),
        .a_mem_addr      (a_mem_addr),
        .a_mem_data      (a_mem_data),

        .b_pc_next       (b_pc_next),
        .b_reg_we        (b_reg_we),
        .b_reg_addr      (b_reg_addr),
        .b_reg_data      (b_reg_data),
        .b_mem_we        (b_mem_we),
        .b_mem_addr      (b_mem_addr),
        .b_mem_data      (b_mem_data),

        .mismatch_now    (mismatch_now),
        .mismatch_latched(mismatch_latched),
        .mismatch_field  (mismatch_field)
    );

    // ------------------------------------------------------------------ //
    //  Watchdog
    // ------------------------------------------------------------------ //
    watchdog u_wd (
        .clk          (clk),
        .reset        (reset),
        .clear        (clear_latched),
        .pc_a         (pc0),
        .pc_b         (pc1),
        .stall_a      (stall_a),
        .stall_b      (stall_b),
        .stall_any    (stall_any),
        .stall_latched(stall_latched)
    );

endmodule
