// lockstep_top.sv
// Lockstep wrapper: instantiates two identical CPU cores (Master + Shadow)
// and connects their commit buses through fault injection to the extended
// comparator and watchdog.

// lockstep_top.sv
// Lockstep wrapper: instantiates two identical CPU cores (Master + Shadow)
// and connects their commit buses through fault injection to the extended
// comparator and watchdog.

module lockstep_top (
    input  logic        clk,
    input  logic        reset,

    // Fault injection control
    input  logic        fault_en,       // enable fault injection on Core B
    input  logic [2:0]  fault_sel,      // which commit-bus field to perturb
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

    // ------------------------------------------------------------------ //
    //  Fault select encoding
    //  These targets match the 7 fields compared by comparator.sv.
    // ------------------------------------------------------------------ //
    localparam logic [2:0] FAULT_NONE     = 3'd0;
    localparam logic [2:0] FAULT_PC       = 3'd1;   // commit_pc_next
    localparam logic [2:0] FAULT_REG_WE   = 3'd2;   // commit_reg_we
    localparam logic [2:0] FAULT_REG_ADDR = 3'd3;   // commit_reg_addr
    localparam logic [2:0] FAULT_REG_DATA = 3'd4;   // commit_reg_data
    localparam logic [2:0] FAULT_MEM_WE   = 3'd5;   // commit_mem_we
    localparam logic [2:0] FAULT_MEM_ADDR = 3'd6;   // commit_mem_addr
    localparam logic [2:0] FAULT_MEM_DATA = 3'd7;   // commit_mem_data

    // ------------------------------------------------------------------ //
    //  Core A (Master / Golden Reference)
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
    //  Core B (Shadow / Checker) — raw commit bus before fault injection
    // ------------------------------------------------------------------ //
    logic [31:0] b_pc_next_raw;
    logic        b_reg_we_raw;
    logic [4:0]  b_reg_addr_raw;
    logic [31:0] b_reg_data_raw;
    logic        b_mem_we_raw;
    logic [31:0] b_mem_addr_raw;
    logic [31:0] b_mem_data_raw;

    cpu_single_cycle core_b (
        .clk             (clk),
        .reset           (reset),
        .debug_pc        (pc1),
        .debug_reg3      (reg3_1),
        .debug_mem0      (mem0_1),
        .commit_pc_next  (b_pc_next_raw),
        .commit_reg_we   (b_reg_we_raw),
        .commit_reg_addr (b_reg_addr_raw),
        .commit_reg_data (b_reg_data_raw),
        .commit_mem_we   (b_mem_we_raw),
        .commit_mem_addr (b_mem_addr_raw),
        .commit_mem_data (b_mem_data_raw)
    );

    // ------------------------------------------------------------------ //
    //  Fault Injection — XOR mask applied to selected Core B commit field
    //
    //  Only Core B is faulted.
    //  Core A remains clean and acts as the golden reference.
    //
    //  For 1-bit fields, only fault_mask[0] is used.
    //  For 5-bit fields, only fault_mask[4:0] is used.
    //  For 32-bit fields, the full fault_mask[31:0] is used.
    // ------------------------------------------------------------------ //

    // 1. PC next — 32 bits
    fault_inject #(.WIDTH(32)) fi_pc (
        .in_signal  (b_pc_next_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_PC)),
        .fault_mask (fault_mask),
        .out_signal (b_pc_next)
    );

    // 2. Register write enable — 1 bit
    fault_inject #(.WIDTH(1)) fi_reg_we (
        .in_signal  (b_reg_we_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_REG_WE)),
        .fault_mask (fault_mask[0]),
        .out_signal (b_reg_we)
    );

    // 3. Register destination address — 5 bits
    fault_inject #(.WIDTH(5)) fi_reg_addr (
        .in_signal  (b_reg_addr_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_REG_ADDR)),
        .fault_mask (fault_mask[4:0]),
        .out_signal (b_reg_addr)
    );

    // 4. Register write-back data — 32 bits
    fault_inject #(.WIDTH(32)) fi_reg_data (
        .in_signal  (b_reg_data_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_REG_DATA)),
        .fault_mask (fault_mask),
        .out_signal (b_reg_data)
    );

    // 5. Memory write enable — 1 bit
    fault_inject #(.WIDTH(1)) fi_mem_we (
        .in_signal  (b_mem_we_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_MEM_WE)),
        .fault_mask (fault_mask[0]),
        .out_signal (b_mem_we)
    );

    // 6. Memory address — 32 bits
    fault_inject #(.WIDTH(32)) fi_mem_addr (
        .in_signal  (b_mem_addr_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_MEM_ADDR)),
        .fault_mask (fault_mask),
        .out_signal (b_mem_addr)
    );

    // 7. Memory write data — 32 bits
    fault_inject #(.WIDTH(32)) fi_mem_data (
        .in_signal  (b_mem_data_raw),
        .fault_en   (fault_en && (fault_sel == FAULT_MEM_DATA)),
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