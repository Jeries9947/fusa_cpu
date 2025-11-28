// dmem.v
module dmem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output reg  [31:0] read_data,
    output wire [31:0] debug_mem0
);

    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'b0;
    end

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= write_data;
    end

    always @* begin
        if (mem_read)
            read_data = mem[addr[9:2]];
        else
            read_data = 32'b0;
    end
        assign debug_mem0 = mem[0];
endmodule


