`timescale 1ns/1ps

module tb_lockstep;

    localparam FAULT_NONE = 2'd0;
    localparam FAULT_REG3 = 2'd1;
    localparam FAULT_PC   = 2'd2;

    localparam NUM_TESTS  = 20;

    reg clk;
    reg reset;

    reg        fault_en;
    reg [1:0]  fault_sel;
    reg [31:0] fault_mask;
    reg        clear_latched;

    wire [31:0] pc0, pc1;
    wire [31:0] reg3_0, reg3_1;
    wire [31:0] mem0_0, mem0_1;
    wire        mismatch_now;
    wire        mismatch_latched;

    integer i;
    integer bit_index;
    integer wait_cycles;
    integer hold_cycles;
    integer detected_count;
    integer total_count;
    integer detected;

    lockstep_top dut (
        .clk              (clk),
        .reset            (reset),
        .fault_en         (fault_en),
        .fault_sel        (fault_sel),
        .fault_mask       (fault_mask),
        .clear_latched    (clear_latched),
        .pc0              (pc0),
        .pc1              (pc1),
        .reg3_0           (reg3_0),
        .reg3_1           (reg3_1),
        .mem0_0           (mem0_0),
        .mem0_1           (mem0_1),
        .mismatch_now     (mismatch_now),
        .mismatch_latched (mismatch_latched)
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

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            detected = 0;

            wait_cycles = $urandom_range(3, 10);
            repeat (wait_cycles) @(posedge clk);

            if ($urandom_range(0, 1) == 0)
                fault_sel = FAULT_REG3;
            else
                fault_sel = FAULT_PC;

            bit_index  = $urandom_range(0, 31);
            fault_mask = (32'h00000001 << bit_index);

            fault_en = 1'b1;
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