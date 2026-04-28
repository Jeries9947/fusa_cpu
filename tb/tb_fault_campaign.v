// tb_fault_campaign.v
// Automated fault-injection campaign for the FuSa lockstep CPU.
//
// IMEM program (from imem.v, runs once then self-loops at beq):
//   PC= 0  addi $1,$0, 5    reg1=5
//   PC= 4  addi $2,$0,10    reg2=10
//   PC= 8  add  $3,$1,$2    reg3=15  ← injection window used by most tests
//   PC=12  sw   $3, 0($0)   mem[0]=15
//   PC=16  beq  $0,$0,-1    loops to PC=16 forever
//
// After reset the comparator's do_reset task leaves the CPU at PC=8,
// mid-execution of the add instruction, where all commit-bus fields
// carry meaningful non-zero values. Faults are injected there.
//
// Fault catalogue:
//   1  reg1 read bit-flip (Core A)  — force dut.core_a.rs_data
//   2  reg2 read bit-flip (Core A)  — force dut.core_a.rt_data
//   3  PC corruption    (Core A)    — force dut.core_a.pc
//   4  ALU result corruption        — force dut.core_a.alu_result
//   5  WB data corruption           — force dut.core_a.write_back_data
//   6  No fault (baseline)          — nothing forced; expect no mismatch
//
// iverilog note: `force x = x ^ mask` evaluates the RHS once at the
// moment of the statement (i.e. the forced value is constant). That is
// exactly the behaviour we want for a single-cycle injection.
//
// Detection latency is measured in clock cycles from the cycle in which
// the fault is applied to the first cycle in which mismatch_now is seen.

`timescale 1ns/1ps

module tb_fault_campaign;

    // ------------------------------------------------------------------ //
    //  Parameters
    // ------------------------------------------------------------------ //
    parameter CLK_HALF   = 5;    // 10 ns period = 100 MHz
    parameter RST_CYCLES = 4;    // reset assertion duration (posedges)
    parameter MAX_WAIT   = 20;   // max posedges to wait for detection

    // ------------------------------------------------------------------ //
    //  DUT signals
    // ------------------------------------------------------------------ //
    reg         clk;
    reg         reset;
    reg         fault_en;
    reg  [1:0]  fault_sel;
    reg  [31:0] fault_mask;
    reg         clear_latch;

    wire [31:0] pc0, pc1;
    wire [31:0] reg3_0, reg3_1;
    wire [31:0] mem0_0, mem0_1;
    wire [31:0] a_pc_next,  b_pc_next;
    wire        a_reg_we,   b_reg_we;
    wire [4:0]  a_reg_addr, b_reg_addr;
    wire [31:0] a_reg_data, b_reg_data;
    wire        a_mem_we,   b_mem_we;
    wire [31:0] a_mem_addr, b_mem_addr;
    wire [31:0] a_mem_data, b_mem_data;
    wire        mismatch_now;
    wire        mismatch_latched;
    wire [6:0]  mismatch_field;
    wire        stall_a, stall_b, stall_any, stall_latched;

    // ------------------------------------------------------------------ //
    //  DUT
    // ------------------------------------------------------------------ //
    lockstep_top dut (
        .clk             (clk),
        .reset           (reset),
        .fault_en        (fault_en),
        .fault_sel       (fault_sel),
        .fault_mask      (fault_mask),
        .clear_latched   (clear_latch),
        .pc0             (pc0),      .pc1         (pc1),
        .reg3_0          (reg3_0),   .reg3_1      (reg3_1),
        .mem0_0          (mem0_0),   .mem0_1      (mem0_1),
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
        .mismatch_field  (mismatch_field),
        .stall_a         (stall_a),
        .stall_b         (stall_b),
        .stall_any       (stall_any),
        .stall_latched   (stall_latched)
    );

    // ------------------------------------------------------------------ //
    //  Clock
    // ------------------------------------------------------------------ //
    initial clk = 1'b0;
    always  #CLK_HALF clk = ~clk;

    // ------------------------------------------------------------------ //
    //  Free-running cycle counter (resets with the DUT)
    // ------------------------------------------------------------------ //
    integer cycle_count;
    always @(posedge clk)
        if (reset) cycle_count <= 0;
        else        cycle_count <= cycle_count + 1;

    // ------------------------------------------------------------------ //
    //  Result storage (6 tests)
    // ------------------------------------------------------------------ //
    integer inj_cyc [0:5];
    integer det_cyc [0:5];
    integer lat     [0:5];
    integer det_ok  [0:5];   // 1 = fault detected, 0 = not detected

    // ------------------------------------------------------------------ //
    //  Reset + latch-clear helper
    //  Leaves CPU at PC=8 (add $3,$1,$2), cycle_count=2.
    // ------------------------------------------------------------------ //
    task do_reset;
        begin
            reset      = 1'b1;
            fault_en   = 1'b0;
            fault_sel  = 2'd0;
            fault_mask = 32'd0;
            clear_latch = 1'b0;
            repeat (RST_CYCLES) @(posedge clk);  // hold reset
            reset = 1'b0;
            @(posedge clk);          // execute addi $1,$0,5  (cycle 1)
            clear_latch = 1'b1;
            @(posedge clk);          // execute addi $2,$0,10 (cycle 2)
            clear_latch = 1'b0;
            // CPU is now between posedge 2 and 3, PC=8 (add $3,$1,$2)
            // rs_data=5 ($1), rt_data=10 ($2), alu_result=15, write_back_data=15
        end
    endtask

    // ------------------------------------------------------------------ //
    //  Detection poll: call after forcing a fault.
    //  Samples mismatch_now one tick after each posedge.
    //  Writes det_ok[t], det_cyc[t], lat[t].
    //  Also releases any force you pass as the `release_target` string —
    //  but Verilog tasks cannot accept hierarchical names as parameters,
    //  so we release outside this task.
    // ------------------------------------------------------------------ //
    task poll_detection;
        input integer t;           // test index
        input integer inj;         // injection cycle number
        integer wc;
        begin
            det_ok[t]  = 0;
            det_cyc[t] = -1;
            wc = 0;
            while (!det_ok[t] && wc < MAX_WAIT) begin
                @(posedge clk);
                #1;                // let combinational logic settle
                if (mismatch_now) begin
                    det_ok[t]  = 1;
                    det_cyc[t] = cycle_count;
                end
                wc = wc + 1;
            end
            lat[t] = det_ok[t] ? (det_cyc[t] - inj) : -1;
        end
    endtask

    // ------------------------------------------------------------------ //
    //  Main stimulus
    // ------------------------------------------------------------------ //
    initial begin
        $dumpfile("fault_campaign.vcd");
        $dumpvars(0, tb_fault_campaign);

        cycle_count = 0;

        // ============================================================== //
        //  TEST 1 — reg1 read bit-flip (Core A)
        //  Inject into rs_data; during add $3,$1,$2, rs=$1 so rs_data=5.
        //  Forced value: 5 ^ 0x1 = 4.
        //  Effect: alu computes 4+10=14 instead of 15 → commit_reg_data diverges.
        // ============================================================== //
        do_reset;
        inj_cyc[0] = cycle_count;
        force dut.core_a.rs_data = dut.core_a.rs_data ^ 32'h0000_0001;
        poll_detection(0, inj_cyc[0]);
        release dut.core_a.rs_data;

        // ============================================================== //
        //  TEST 2 — reg2 read bit-flip (Core A)
        //  Inject into rt_data; during add $3,$1,$2, rt=$2 so rt_data=10.
        //  Forced value: 10 ^ 0x4 = 14.
        //  Effect: alu computes 5+14=19 instead of 15 → commit_reg_data diverges.
        // ============================================================== //
        do_reset;
        inj_cyc[1] = cycle_count;
        force dut.core_a.rt_data = dut.core_a.rt_data ^ 32'h0000_0004;
        poll_detection(1, inj_cyc[1]);
        release dut.core_a.rt_data;

        // ============================================================== //
        //  TEST 3 — PC corruption (Core A)
        //  Flip bit 2 of the PC register.  PC=8, forced=12.
        //  Core A then fetches instr[3] (sw) and computes pc_next=16,
        //  while Core B stays on add and computes pc_next=12.
        //  commit_pc_next diverges immediately.
        // ============================================================== //
        do_reset;
        inj_cyc[2] = cycle_count;
        force dut.core_a.pc = dut.core_a.pc ^ 32'h0000_0004;
        poll_detection(2, inj_cyc[2]);
        release dut.core_a.pc;

        // ============================================================== //
        //  TEST 4 — ALU result corruption (Core A)
        //  alu_result during add $3,$1,$2 = 15.
        //  Forced value: 15 ^ 0xFFFF_FFFF = 0xFFFF_FFF0.
        //  Feeds both commit_reg_data (write_back_data) and commit_mem_addr.
        //  Both fields diverge → very high mismatch_field activity.
        // ============================================================== //
        do_reset;
        inj_cyc[3] = cycle_count;
        force dut.core_a.alu_result = dut.core_a.alu_result ^ 32'hFFFF_FFFF;
        poll_detection(3, inj_cyc[3]);
        release dut.core_a.alu_result;

        // ============================================================== //
        //  TEST 5 — Write-back data corruption (Core A)
        //  write_back_data = alu_result = 15 during add.
        //  Forced value: 15 ^ 0x8 = 7.
        //  Directly overrides commit_reg_data seen by comparator.
        // ============================================================== //
        do_reset;
        inj_cyc[4] = cycle_count;
        force dut.core_a.write_back_data = dut.core_a.write_back_data ^ 32'h0000_0008;
        poll_detection(4, inj_cyc[4]);
        release dut.core_a.write_back_data;

        // ============================================================== //
        //  TEST 6 — No fault (baseline)
        //  Both cores run identical and undisturbed for MAX_WAIT cycles.
        //  mismatch_now and mismatch_latched must remain 0.
        // ============================================================== //
        do_reset;
        inj_cyc[5] = -1;
        det_cyc[5] = -1;
        lat[5]     = -1;
        det_ok[5]  = 0;
        begin : baseline_check
            integer wc;
            wc = 0;
            while (wc < MAX_WAIT) begin
                @(posedge clk);
                #1;
                if (mismatch_now || mismatch_latched)
                    det_ok[5] = 1;   // spurious — should NOT happen
                wc = wc + 1;
            end
        end

        // ============================================================== //
        //  Print results table
        // ============================================================== //
        $display("");
        $display("============================================================");
        $display("  FuSa Lockstep CPU -- Fault Injection Campaign Results");
        $display("============================================================");
        $display(" #  | %-30s | Inj Cyc | Det Cyc | Latency", "Fault Description");
        $display("----+--------------------------------+---------+---------+--------");

        // Tests 1-5: injected faults
        $display(" 1  | %-30s |    %4d |    %4d | %2d cyc",
            "reg1 read bit-flip (Core A)", inj_cyc[0], det_cyc[0], lat[0]);
        $display(" 2  | %-30s |    %4d |    %4d | %2d cyc",
            "reg2 read bit-flip (Core A)", inj_cyc[1], det_cyc[1], lat[1]);
        $display(" 3  | %-30s |    %4d |    %4d | %2d cyc",
            "PC corruption (Core A)",      inj_cyc[2], det_cyc[2], lat[2]);
        $display(" 4  | %-30s |    %4d |    %4d | %2d cyc",
            "ALU result corruption",       inj_cyc[3], det_cyc[3], lat[3]);
        $display(" 5  | %-30s |    %4d |    %4d | %2d cyc",
            "WB data corruption",          inj_cyc[4], det_cyc[4], lat[4]);

        // Test 6: baseline
        if (det_ok[5] == 0)
            $display(" 6  | %-30s |       - |       - |      -",
                "No fault (baseline)");
        else
            $display(" 6  | %-30s |       - | SPURIOUS|      -",
                "No fault (baseline)");

        $display("----+--------------------------------+---------+---------+--------");

        begin : summary
            integer n_inj, n_det, max_lat, cov, i;
            n_inj   = 5;
            n_det   = 0;
            max_lat = 0;
            for (i = 0; i < 5; i = i + 1) begin
                if (det_ok[i]) begin
                    n_det = n_det + 1;
                    if (lat[i] > max_lat) max_lat = lat[i];
                end
            end
            cov = (n_det * 100) / n_inj;
            $display(" Detected: %0d/%0d injected faults   Coverage: %0d%%   Max latency: %0d cyc",
                     n_det, n_inj, cov, max_lat);
            if (det_ok[5])
                $display(" WARNING: Spurious mismatch in baseline (no-fault) run!");
        end

        $display("============================================================");
        $display("");

        $finish;
    end

endmodule
