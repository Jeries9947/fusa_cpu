// imem.v
module imem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    reg [31:0] mem [0:255];

    initial begin
        mem[0] = 32'h20010005; // addi $1, $0, 5
        mem[1] = 32'h2002000a; // addi $2, $0, 10
        mem[2] = 32'h00221820; // add  $3, $1, $2
        mem[3] = 32'hac030000; // sw   $3, 0($0)
        mem[4] = 32'h1000ffff; // beq  $0, $0, -1 (loop)
        // rest default 0
    end

    assign instr = mem[addr[9:2]]; // word addressed

endmodule
