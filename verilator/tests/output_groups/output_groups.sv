// A pipeline of distinct stages, enough code for --output-split to split.
module output_groups_stage #(
    parameter int K = 0
) (
    input  logic        clk,
    input  logic [31:0] a,
    output logic [31:0] y
);
  always_ff @(posedge clk) y <= (a * (K + 3)) ^ ((a >> (K % 7)) + K);
endmodule

module output_groups (
    input  logic        clk,
    input  logic [31:0] a,
    output logic [31:0] y
);
  logic [31:0] t[65];
  assign t[0] = a;
  for (genvar i = 0; i < 64; i++) begin : g_stage
    output_groups_stage #(.K(i)) u_stage (
        .clk,
        .a(t[i]),
        .y(t[i+1])
    );
  end
  assign y = t[64];
endmodule
