module sign_extend (
    input  wire [15:0] imm,
    input  wire        imm_unsigned,   // 1: zero-extend, 0: sign-extend
    output wire [31:0] imm_ext
);
    assign imm_ext =
        imm_unsigned ? {16'b0, imm} :          // zero-extend
                       {{16{imm[15]}}, imm};    // sign-extend
endmodule

