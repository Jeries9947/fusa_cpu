// sign_extend.v
module sign_extend (
    input  wire [15:0] imm,
    output wire [31:0] imm_ext
);
    assign imm_ext = {{16{imm[15]}}, imm};
endmodule
