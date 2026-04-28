// tb_cpu_basic.sv
`timescale 1ns/1ps

module tb_cpu_basic;
    logic        clk;
    logic        reset;
    logic [31:0] debug_pc;
    logic [31:0] debug_reg3;
    logic [31:0] debug_mem0;

    // Commit bus outputs (declared but not checked in this basic TB)
    logic [31:0] commit_pc_next;
    logic        commit_reg_we;
    logic [4:0]  commit_reg_addr;
    logic [31:0] commit_reg_data;
    logic        commit_mem_we;
    logic [31:0] commit_mem_addr;
    logic [31:0] commit_mem_data;

    cpu_single_cycle uut (
        .clk             (clk),
        .reset           (reset),
        .debug_pc        (debug_pc),
        .debug_reg3      (debug_reg3),
        .debug_mem0      (debug_mem0),
        .commit_pc_next  (commit_pc_next),
        .commit_reg_we   (commit_reg_we),
        .commit_reg_addr (commit_reg_addr),
        .commit_reg_data (commit_reg_data),
        .commit_mem_we   (commit_mem_we),
        .commit_mem_addr (commit_mem_addr),
        .commit_mem_data (commit_mem_data)
    );

    // Clock
    initial clk = 1'b0;
    always  #5 clk = ~clk; // 100 MHz

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
