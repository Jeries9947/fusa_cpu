// tb_lockstep.sv
`timescale 1ns/1ps

module tb_lockstep;

    localparam logic [1:0] FAULT_NONE = 2'd0;
    localparam logic [1:0] FAULT_REG3 = 2'd1;
    localparam logic [1:0] FAULT_PC   = 2'd2;

    localparam int NUM_TESTS = 20;

    logic        clk;
    logic        reset;

    logic        fault_en;
    logic [1:0]  fault_sel;
    logic [31:0] fault_mask;
    logic        clear_latched;

    logic [31:0] pc0, pc1;
    logic [31:0] reg3_0, reg3_1;
    logic [31:0] mem0_0, mem0_1;
    logic        mismatch_now;
    logic        mismatch_latched;

    // Remaining lockstep_top outputs (monitored but not exercised in this TB)
    logic [31:0] a_pc_next,  b_pc_next;
    logic        a_reg_we,   b_reg_we;
    logic [4:0]  a_reg_addr, b_reg_addr;
    logic [31:0] a_reg_data, b_reg_data;
    logic        a_mem_we,   b_mem_we;
    logic [31:0] a_mem_addr, b_mem_addr;
    logic [31:0] a_mem_data, b_mem_data;
    logic [6:0]  mismatch_field;
    logic        stall_a, stall_b, stall_any, stall_latched;

    int i;
    int bit_index;
    int wait_cycles;
    int hold_cycles;
    int detected_count;
    int total_count;
    int detected;

    lockstep_top dut (
        .clk             (clk),
        .reset           (reset),
        .fault_en        (fault_en),
        .fault_sel       (fault_sel),
        .fault_mask      (fault_mask),
        .clear_latched   (clear_latched),
        .pc0             (pc0),
        .pc1             (pc1),
        .reg3_0          (reg3_0),
        .reg3_1          (reg3_1),
        .mem0_0          (mem0_0),
        .mem0_1          (mem0_1),
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

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        reset         = 1'b1;
        fault_en      = 1'b0;
        fault_sel     = FAULT_NONE;
        fault_mask    = 32'h00000000;
        clear_latched = 1'b0;

        detected_count = 0;
        total_count    = 0;

        #20;
        reset = 1'b0;

        #1;
        $dumpfile("lockstep.vcd");
        $dumpvars(0, tb_lockstep);

        $display("TB start at time %t", $time);

        repeat (10) begin
            @(posedge clk);
            $display("WARMUP t=%0t PC0=%08h PC1=%08h R3_0=%08h R3_1=%08h mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mismatch_now, mismatch_latched);
        end

        $display("=== Starting Random Bit-Flip Fault Campaign ===");

        for (i = 0; i < NUM_TESTS; i++) begin
            detected = 0;

            wait_cycles = $urandom_range(3, 10);
            repeat (wait_cycles) @(posedge clk);

            if ($urandom_range(0, 1) == 0)
                fault_sel = FAULT_REG3;
            else
                fault_sel = FAULT_PC;

            bit_index  = $urandom_range(0, 31);
            fault_mask = (32'h00000001 << bit_index);

            fault_en    = 1'b1;
            total_count = total_count + 1;

            $display("TEST %0d START t=%0t fault_sel=%0d bit=%0d mask=%08h PC0=%08h PC1=%08h R3_0=%08h R3_1=%08h",
                     i, $time, fault_sel, bit_index, fault_mask, pc0, pc1, reg3_0, reg3_1);

            hold_cycles = $urandom_range(1, 4);

            repeat (hold_cycles) begin
                @(posedge clk);

                if (mismatch_now || mismatch_latched)
                    detected = 1;

                $display("TEST %0d FI    t=%0t fault_sel=%0d bit=%0d PC0=%08h PC1=%08h R3_0=%08h R3_1=%08h mismatch_now=%b latched=%b",
                         i, $time, fault_sel, bit_index, pc0, pc1, reg3_0, reg3_1, mismatch_now, mismatch_latched);
            end

            fault_en   = 1'b0;
            fault_sel  = FAULT_NONE;
            fault_mask = 32'h00000000;

            @(posedge clk);
            if (mismatch_now || mismatch_latched)
                detected = 1;

            if (detected) begin
                detected_count = detected_count + 1;
                $display("TEST %0d RESULT: DETECTED", i);
            end else begin
                $display("TEST %0d RESULT: NOT DETECTED", i);
            end

            clear_latched = 1'b1;
            @(posedge clk);
            clear_latched = 1'b0;

            @(posedge clk);
            $display("TEST %0d CLEAR  t=%0t mismatch_now=%b latched=%b",
                     i, $time, mismatch_now, mismatch_latched);
        end

        $display("=== Fault Campaign Done ===");
        $display("Total faults    = %0d", total_count);
        $display("Detected faults = %0d", detected_count);
        $display("Coverage        = %0d / %0d", detected_count, total_count);

        $finish;
    end

endmodule
