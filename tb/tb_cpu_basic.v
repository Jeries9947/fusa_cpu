// tb_cpu_basic.v
`timescale 1ns/1ps

module tb_cpu_basic;
    reg clk;
    reg reset;
    wire [31:0] debug_pc;
    wire [31:0] debug_reg3;
    wire [31:0] debug_mem0;

    cpu_single_cycle uut (
        .clk        (clk),
        .reset      (reset),
        .debug_pc   (debug_pc),
        .debug_reg3 (debug_reg3),
        .debug_mem0 (debug_mem0)
    );

    // clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk; // 100 MHz
    end

    initial begin
        $dumpfile("cpu_basic.vcd");
        $dumpvars(0, tb_cpu_basic);

        reset = 1'b1;
        #20;
        reset = 1'b0;

        // run for some cycles
        #500;

        $display("PC = 0x%08h", debug_pc);
        $display("reg3 (should be 15) = 0x%08h", debug_reg3);
        $display("mem0 (should be 15) = 0x%08h", debug_mem0);

        $finish;
    end

endmodule
