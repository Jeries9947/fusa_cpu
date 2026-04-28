// register_file.sv
module register_file (
    input  logic        clk,
    input  logic        reset,
    input  logic        reg_write,
    input  logic [4:0]  rs_addr,
    input  logic [4:0]  rt_addr,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] write_data,
    output logic [31:0] rs_data,
    output logic [31:0] rt_data,
    output logic [31:0] debug_reg3
);

    logic [31:0] regs [0:31];

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 32; i++)
                regs[i] <= 32'b0;
        end else begin
            if (reg_write && (rd_addr != 5'd0))
                regs[rd_addr] <= write_data;
        end
    end

    assign rs_data    = (rs_addr == 5'd0) ? 32'b0 : regs[rs_addr];
    assign rt_data    = (rt_addr == 5'd0) ? 32'b0 : regs[rt_addr];
    assign debug_reg3 = regs[3];

endmodule
