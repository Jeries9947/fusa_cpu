// dmem.sv
module dmem (
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data,
    output logic [31:0] debug_mem0
);

    logic [31:0] mem [0:255];

    initial begin
        for (int i = 0; i < 256; i++)
            mem[i] = 32'b0;
    end

    always_ff @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= write_data;
    end

    always_comb begin
        if (mem_read)
            read_data = mem[addr[9:2]];
        else
            read_data = 32'b0;
    end

    assign debug_mem0 = mem[0];

endmodule
