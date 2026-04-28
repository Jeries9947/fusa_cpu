// lockstep_top.sv
// Lockstep wrapper: instantiates two identical CPU cores (Master + Shadow)
// and connects their commit buses through fault injection to the extended
// comparator and watchdog.

module lockstep_top (
    input  logic        clk,
    input  logic        reset,

    // Fault injection control
    input  logic        fault_en,       // enable fault injection on Core B
    input  logic [1:0]  fault_sel,      // which commit-bus field to perturb
    input  logic [31:0] fault_mask,     // XOR mask applied to selected field
    input  logic        clear_latched,  // synchronously clears mismatch/stall latches

    // Legacy debug taps (kept for waveform / testbench compatibility)
    output logic [31:0] pc0,            // Core A current PC
    output logic [31:0] pc1,            // Core B current PC
    output logic [31:0] reg3_0,
    output logic [31:0] reg3_1,
    output logic [31:0] mem0_0,
    output logic [31:0] mem0_1,

    // Commit bus — Core A (raw, no fault injection)
    output logic [31:0] a_pc_next,
    output logic        a_reg_we,
    output logic [4:0]  a_reg_addr,
    output logic [31:0] a_reg_data,
    output logic        a_mem_we,
    output logic [31:0] a_mem_addr,
    output logic [31:0] a_mem_data,

    // Commit bus — Core B (after fault injection on selected field)
    output logic [31:0] b_pc_next,
    output logic        b_reg_we,
    output logic [4:0]  b_reg_addr,
    output logic [31:0] b_reg_data,
    output logic        b_mem_we,
    output logic [31:0] b_mem_addr,
    output logic [31:0] b_mem_data,

    // Comparator fault detection outputs
    output logic        mismatch_now,
    output logic        mismatch_latched,
    output logic [6:0]  mismatch_field,  // one-hot: identifies diverging field

    // Watchdog fault detection outputs
    output logic        stall_a,
    output logic        stall_b,
    output logic        stall_any,
    output logic        stall_latched
);

    // fault_sel encoding
    localparam logic [1:0] FAULT_NONE     = 2'd0;
    localparam logic [1:0] FAULT_PC       = 2'd1;   // perturb Core B commit_pc_next
    localparam logic [1:0] FAULT_REG_DATA = 2'd2;   // perturb Core B commit_reg_data
    localparam logic [1:0] FAULT_MEM_DATA = 2'd3;   // perturb Core B commit_mem_data

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
    logic [31:0] b_pc_next_raw;
    logic [31:0] b_reg_data_raw;
    logic [31:0] b_mem_data_raw;

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
