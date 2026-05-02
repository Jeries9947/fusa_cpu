// tb_watchdog_campaign.sv
//
// Campaign 3: Watchdog / hang detection campaign.
//
// This testbench injects a PC-hold fault into Core B.
// Core B stops updating its PC, while Core A continues normally.
// The watchdog should detect that Core B is stalled.
//
// Expected:
//   stall_b       = 1
//   stall_any     = 1
//   stall_latched = 1

`timescale 1ns/1ps

module tb_watchdog_campaign;

    localparam logic [3:0] INT_FAULT_NONE    = 4'd0;
    localparam logic [3:0] INT_FAULT_PC_HOLD = 4'd8;

    localparam int MAX_WAIT = 40;

    logic        clk;
    logic        reset;

    logic        int_fault_en;
    logic [3:0]  int_fault_sel;
    logic [31:0] int_fault_mask;
    logic        clear_latched;

    logic [31:0] pc0, pc1;
    logic [31:0] reg3_0, reg3_1;
    logic [31:0] mem0_0, mem0_1;

    logic [31:0] a_pc_next,  b_pc_next;
    logic        a_reg_we,   b_reg_we;
    logic [4:0]  a_reg_addr, b_reg_addr;
    logic [31:0] a_reg_data, b_reg_data;
    logic        a_mem_we,   b_mem_we;
    logic [31:0] a_mem_addr, b_mem_addr;
    logic [31:0] a_mem_data, b_mem_data;

    logic        mismatch_now;
    logic        mismatch_latched;
    logic [6:0]  mismatch_field;

    logic        stall_a;
    logic        stall_b;
    logic        stall_any;
    logic        stall_latched;

    int cycle_count;
    int inject_cycle;
    int detect_cycle;
    int latency;
    bit detected;

    lockstep_top_internal_fault dut (
        .clk              (clk),
        .reset            (reset),

        .int_fault_en     (int_fault_en),
        .int_fault_sel    (int_fault_sel),
        .int_fault_mask   (int_fault_mask),
        .clear_latched    (clear_latched),

        .pc0              (pc0),
        .pc1              (pc1),
        .reg3_0           (reg3_0),
        .reg3_1           (reg3_1),
        .mem0_0           (mem0_0),
        .mem0_1           (mem0_1),

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
        .mismatch_field   (mismatch_field),

        .stall_a          (stall_a),
        .stall_b          (stall_b),
        .stall_any        (stall_any),
        .stall_latched    (stall_latched)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end

    task automatic apply_reset;
        begin
            reset          = 1'b1;
            int_fault_en   = 1'b0;
            int_fault_sel  = INT_FAULT_NONE;
            int_fault_mask = 32'h0000_0000;
            clear_latched  = 1'b0;

            repeat (4) @(posedge clk);

            @(negedge clk);
            reset = 1'b0;
        end
    endtask

    task automatic clear_flags;
        begin
            clear_latched = 1'b1;
            @(posedge clk);
            #1;
            clear_latched = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("watchdog_campaign.vcd");
        $dumpvars(0, tb_watchdog_campaign);

        detected     = 0;
        inject_cycle = -1;
        detect_cycle = -1;
        latency      = -1;

        $display("");
        $display("============================================================");
        $display(" Starting Watchdog Campaign");
        $display("============================================================");

        apply_reset();

        // Normal run before the stall fault.
        repeat (5) begin
            @(posedge clk);
            #1;
            $display("NORMAL  | cycle=%0d | pc0=%08h pc1=%08h | stall_b=%0b stall_latched=%0b",
                     cycle_count, pc0, pc1, stall_b, stall_latched);
        end

        // Inject PC hold fault into Core B.
        @(negedge clk);
        int_fault_sel = INT_FAULT_PC_HOLD;
        int_fault_en  = 1'b1;
        inject_cycle  = cycle_count + 1;

        $display("");
        $display("Injecting Core B PC_HOLD fault at cycle %0d", inject_cycle);
        $display("");

        repeat (MAX_WAIT) begin
            @(posedge clk);
            #1;

            $display("OBSERVE | cycle=%0d | pc0=%08h pc1=%08h | stall_a=%0b stall_b=%0b stall_any=%0b stall_latched=%0b mismatch=%0b",
                     cycle_count, pc0, pc1,
                     stall_a, stall_b, stall_any, stall_latched,
                     mismatch_latched);

            if (!detected && stall_latched) begin
                detected     = 1;
                detect_cycle = cycle_count;
            end
        end

        int_fault_en  = 1'b0;
        int_fault_sel = INT_FAULT_NONE;

        if (detected) begin
            latency = detect_cycle - inject_cycle;
            $display("");
            $display("WATCHDOG RESULT: DETECTED");
            $display("Inject cycle      = %0d", inject_cycle);
            $display("Detect cycle      = %0d", detect_cycle);
            $display("Detection latency = %0d cycles", latency);
        end else begin
            $display("");
            $display("WATCHDOG RESULT: NOT DETECTED");
        end

        clear_flags();

        $display("");
        $display("After clear: stall_latched=%0b", stall_latched);
        $display("============================================================");
        $display("");

        $finish;
    end

endmodule