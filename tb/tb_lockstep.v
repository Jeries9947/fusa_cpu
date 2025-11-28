// tb_lockstep.v
`timescale 1ns/1ps

module tb_lockstep;
    reg clk;
    reg reset;

    wire [31:0] pc0, pc1;
    wire [31:0] reg3_0, reg3_1;
    wire [31:0] mem0_0, mem0_1;
    wire        mismatch_now;
    wire        mismatch_latched;

    lockstep_top dut (
        .clk              (clk),
        .reset            (reset),
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
        forever #5 clk = ~clk; // 100 MHz
    end

    // Main stimulus + fault injection
    initial begin
        $dumpfile("lockstep.vcd");
        $dumpvars(0, tb_lockstep);

        $display("TB start at time %t", $time);

        reset = 1'b1;
        #20;
        reset = 1'b0;

        // Let both cores run correctly for a few cycles
        repeat (10) begin
            @(posedge clk);
            $display("NO FI  t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        // Inject a fault at the observable output of core1 (reg3_1)
        $display("=== Injecting fault into reg3_1 at time %t ===", $time);
        force reg3_1 = 32'hDEAD_BEEF;

        // Run a few more cycles to see comparator flag it
        repeat (10) begin
            @(posedge clk);
            $display("FI ON  t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        // Release the fault on the observable signal
        release reg3_1;
        $display("=== Released fault at time %t ===", $time);

        // Run a bit more to show the sticky flag stays 1
        repeat (10) begin
            @(posedge clk);
            $display("POST FI t=%0t  PC0=%08h PC1=%08h  R3_0=%08h R3_1=%08h  M0_0=%08h M0_1=%08h  mismatch_now=%b latched=%b",
                     $time, pc0, pc1, reg3_0, reg3_1, mem0_0, mem0_1, mismatch_now, mismatch_latched);
        end

        $display("Final: mismatch_latched = %b at time %t", mismatch_latched, $time);
        $finish;
    end

endmodule
