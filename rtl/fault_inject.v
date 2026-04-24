module fault_inject #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] in_signal,
    input  wire             fault_en,
    input  wire [WIDTH-1:0] fault_mask,
    output wire [WIDTH-1:0] out_signal
);

assign out_signal = fault_en ? (in_signal ^ fault_mask) : in_signal;

endmodule