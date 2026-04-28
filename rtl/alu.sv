// alu.sv
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_ctrl,
    output logic [31:0] result,
    output logic        zero
);

    always_comb begin
        case (alu_ctrl)
            4'b0000: result = a + b;    // ADD
            4'b0001: result = a - b;    // SUB  (for BEQ/BNE compare)
            4'b0010: result = a & b;    // AND
            4'b0011: result = a | b;    // OR
            default: result = 32'b0;
        endcase
    end

    assign zero = (result == 32'b0);

endmodule
