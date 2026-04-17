// tb_lockstep.v
`timescale 1ns/1ps

module tb_lockstep;
    reg clk;
    reg reset;
    reg fault_en;

    wire [31:0] pc0, pc1;
    wire [31:0] reg3_0, reg3_1;
    wire [31:0] mem0_0, mem0_1;
    wire        mismatch_now;
    wire        mismatch_latched;

    lockstep_top dut (
        .clk              (clk),
        .reset            (reset),
        .fault_en         (fault_en),
        .pc0              (pc0),
        .pc1              (pc1),
        .reg3_0           (reg3_0),
        .reg3_1           (reg3_1),
        .mem0_0           (mem0_0),
        .mem0_1           (mem0_1),
        .mismatch_now     (mismatch_now),
        .mismatch_latched (mismatch_latched)
    );

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Main stimulus
    initial begin
        reset    = 1'b1;
        fault_en = 1'b0;

        #20;
        reset = 1'b0;

        #1;
        $dumpfile("lockstep.vcd");
        $dumpvars(0, tb_lockstep);

        $display("TB start at time %t", $time);

        // Run correctly for a few cycles
        repeat (10) begin
            @(posedge clk);
            $display("NO FI  t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        // Turn fault injection ON
        $display("=== Injecting fault into reg3_1 at time %t ===", $time);
        fault_en = 1'b1;

        repeat (10) begin
            @(posedge clk);
            $display("FI ON  t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        // Turn fault injection OFF
        fault_en = 1'b0;
        $display("=== Released fault at time %t ===", $time);

        repeat (10) begin
            @(posedge clk);
            $display("POST FI t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        $display("Final: mismatch_latched = %b at time %t", mismatch_latched, $time);
        $finish;
    end

endmodule