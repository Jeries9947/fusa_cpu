// lockstep_top_internal_fault.sv
//
// Lockstep wrapper for Campaign 2 and Campaign 3.
//
// Core A uses the clean cpu_single_cycle module.
// Core B uses cpu_single_cycle_faultable, which contains internal fault
// injection points before the commit bus.
//
// Campaign 1 is NOT affected by this file.
// Campaign 1 still uses lockstep_top.sv.

module lockstep_top_internal_fault (
    input  logic        clk,
    input  logic        reset,

    // Internal fault injection control for Core B only
    input  logic        int_fault_en,
    input  logic [3:0]  int_fault_sel,
    input  logic [31:0] int_fault_mask,
    input  logic        clear_latched,

    // Legacy debug taps
    output logic [31:0] pc0,
    output logic [31:0] pc1,
    output logic [31:0] reg3_0,
    output logic [31:0] reg3_1,
    output logic [31:0] mem0_0,
    output logic [31:0] mem0_1,

    // Commit bus — Core A
    output logic [31:0] a_pc_next,
    output logic        a_reg_we,
    output logic [4:0]  a_reg_addr,
    output logic [31:0] a_reg_data,
    output logic        a_mem_we,
    output logic [31:0] a_mem_addr,
    output logic [31:0] a_mem_data,

    // Commit bus — Core B
    output logic [31:0] b_pc_next,
    output logic        b_reg_we,
    output logic [4:0]  b_reg_addr,
    output logic [31:0] b_reg_data,
    output logic        b_mem_we,
    output logic [31:0] b_mem_addr,
    output logic [31:0] b_mem_data,

    // Comparator outputs
    output logic        mismatch_now,
    output logic        mismatch_latched,
    output logic [6:0]  mismatch_field,

    // Watchdog outputs
    output logic        stall_a,
    output logic        stall_b,
    output logic        stall_any,
    output logic        stall_latched
);

    // ------------------------------------------------------------------ //
    // Core A — clean golden reference
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
    // Core B — faultable checker core
    // ------------------------------------------------------------------ //
    cpu_single_cycle_faultable core_b (
        .clk             (clk),
        .reset           (reset),

        .int_fault_en    (int_fault_en),
        .int_fault_sel   (int_fault_sel),
        .int_fault_mask  (int_fault_mask),

        .debug_pc        (pc1),
        .debug_reg3      (reg3_1),
        .debug_mem0      (mem0_1),

        .commit_pc_next  (b_pc_next),
        .commit_reg_we   (b_reg_we),
        .commit_reg_addr (b_reg_addr),
        .commit_reg_data (b_reg_data),
        .commit_mem_we   (b_mem_we),
        .commit_mem_addr (b_mem_addr),
        .commit_mem_data (b_mem_data)
    );

    // ------------------------------------------------------------------ //
    // Commit bus comparator
    // ------------------------------------------------------------------ //
    comparator u_cmp (
        .clk              (clk),
        .reset            (reset),
        .clear            (clear_latched),

        .a_pc_next        (a_pc_next),
        .a_reg_we         (a_reg_we),
        .a_reg_addr       (a_reg_addr),
        .a_reg_data       (a_reg_data),
        .a_mem_we         (a_mem_we),
        .a_mem_addr       (a_mem_addr),
        .a_mem_data       (a_mem_data),

        .b_pc_next        (b_pc_next),
        .b_reg_we         (b_reg_we),
        .b_reg_addr       (b_reg_addr),
        .b_reg_data       (b_reg_data),
        .b_mem_we         (b_mem_we),
        .b_mem_addr       (b_mem_addr),
        .b_mem_data       (b_mem_data),

        .mismatch_now     (mismatch_now),
        .mismatch_latched (mismatch_latched),
        .mismatch_field   (mismatch_field)
    );

    // ------------------------------------------------------------------ //
    // Watchdog
    // ------------------------------------------------------------------ //
    watchdog u_wd (
        .clk           (clk),
        .reset         (reset),
        .clear         (clear_latched),

        .pc_a          (pc0),
        .pc_b          (pc1),

        .stall_a       (stall_a),
        .stall_b       (stall_b),
        .stall_any     (stall_any),
        .stall_latched (stall_latched)
    );

endmodule
