module hier_top(
    input  logic [3:0] x,
    output logic [4:0] sum,
    output logic [3:0] passthrough
);
  logic [3:0] block_a_y;
  logic [3:0] block_b_y;

  hier_block_a u_block_a(
      .x(x),
      .y(block_a_y)
  );

  hier_block_b u_block_b(
      .x(x),
      .y(block_b_y)
  );

  assign sum = block_a_y + block_b_y;
  assign passthrough = block_a_y;
endmodule
