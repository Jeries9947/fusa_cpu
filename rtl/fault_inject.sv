// fault_inject.sv
// Generic RTL bit-flip fault injection module.
//
// When fault_en is low, the input signal passes through unchanged.
// When fault_en is high, the selected bits are flipped according to fault_mask.
//
// Example:
//   in_signal  = 32'h0000_000F
//   fault_mask = 32'h0000_0004
//   out_signal = 32'h0000_000B
//
// The module is parameterized by WIDTH, so it can be reused for
// 32-bit data paths, 5-bit register addresses, and 1-bit control signals.

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
