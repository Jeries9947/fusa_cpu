// register_file.v
module register_file (
    input  wire        clk,
    input  wire        reset,
    input  wire        reg_write,
    input  wire [4:0]  rs_addr,
    input  wire [4:0]  rt_addr,
    input  wire [4:0]  rd_addr,
    input  wire [31:0] write_data,
    output wire [31:0] rs_data,
    output wire [31:0] rt_data,
    output wire [31:0] debug_reg3
);

    reg [31:0] regs [0:31];
    integer i;

    // Optional reset to zero
    always @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (reg_write && (rd_addr != 5'd0))
                regs[rd_addr] <= write_data;
        end
    end

    assign rs_data = (rs_addr == 5'd0) ? 32'b0 : regs[rs_addr];
    assign rt_data = (rt_addr == 5'd0) ? 32'b0 : regs[rt_addr];
    assign debug_reg3 = regs[3];
endmodule



