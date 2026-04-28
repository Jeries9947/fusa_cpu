// fault_inject.sv
module fault_inject #(
    parameter int WIDTH = 32
)(
    input  logic [WIDTH-1:0] in_signal,
    input  logic             fault_en,
    input  logic [WIDTH-1:0] fault_mask,
    output logic [WIDTH-1:0] out_signal
);

    assign out_signal = fault_en ? (in_signal ^ fault_mask) : in_signal;

endmodule
