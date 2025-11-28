// control_unit.v
module control_unit (
    input  wire [5:0] opcode,
    input  wire [5:0] funct,
    output reg        reg_write,
    output reg        reg_dst,        // 1: rd, 0: rt
    output reg        alu_src_imm,    // 1: immediate, 0: rt
    output reg        imm_unsigned,   // 1: zero extend, 0: sign extend
    output reg        mem_to_reg,     // 1: data memory, 0: ALU result
    output reg        mem_read,
    output reg        mem_write,
    output reg        branch_eq,
    output reg        branch_ne,
    output reg        jump,
    output reg [3:0]  alu_ctrl
);
    always @* begin
        // default values
        reg_write    = 1'b0;
        reg_dst      = 1'b0;
        alu_src_imm  = 1'b0;
        imm_unsigned = 1'b0;
        mem_to_reg   = 1'b0;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        branch_eq    = 1'b0;
        branch_ne    = 1'b0;
        jump         = 1'b0;
        alu_ctrl     = 4'b0000; // default ADD

        case (opcode)
            6'b000000: begin
                // R type
                reg_write   = 1'b1;
                reg_dst     = 1'b1;
                alu_src_imm = 1'b0;
                case (funct)
                    6'd32: alu_ctrl = 4'b0000; // ADD
                    6'd34: alu_ctrl = 4'b0001; // SUB
                    6'd36: alu_ctrl = 4'b0010; // AND
                    6'd37: alu_ctrl = 4'b0011; // OR
                    default: reg_write = 1'b0; // unknown funct
                endcase
            end

            6'd8: begin
                // ADDI
                reg_write   = 1'b1;
                reg_dst     = 1'b0;
                alu_src_imm = 1'b1;
                alu_ctrl    = 4'b0000;
            end

            6'd12: begin
                // ANDI (zero extend)
                reg_write    = 1'b1;
                reg_dst      = 1'b0;
                alu_src_imm  = 1'b1;
                imm_unsigned = 1'b1;
                alu_ctrl     = 4'b0010;
            end

            6'd13: begin
                // ORI (zero extend)
                reg_write    = 1'b1;
                reg_dst      = 1'b0;
                alu_src_imm  = 1'b1;
                imm_unsigned = 1'b1;
                alu_ctrl     = 4'b0011;
            end

            6'd35: begin
                // LW
                reg_write   = 1'b1;
                reg_dst     = 1'b0;
                alu_src_imm = 1'b1;
                mem_to_reg  = 1'b1;
                mem_read    = 1'b1;
                alu_ctrl    = 4'b0000; // ADD base + offset
            end

            6'd43: begin
                // SW
                reg_write   = 1'b0;
                alu_src_imm = 1'b1;
                mem_write   = 1'b1;
                alu_ctrl    = 4'b0000;
            end

            6'd4: begin
                // BEQ
                branch_eq   = 1'b1;
                alu_src_imm = 1'b0;
                alu_ctrl    = 4'b0001; // SUB for compare
            end

            6'd5: begin
                // BNE
                branch_ne   = 1'b1;
                alu_src_imm = 1'b0;
                alu_ctrl    = 4'b0001;
            end

            6'd2: begin
                // J
                jump = 1'b1;
            end

            default: begin
                // unsupported opcode => NOP
            end
        endcase
    end

endmodule

