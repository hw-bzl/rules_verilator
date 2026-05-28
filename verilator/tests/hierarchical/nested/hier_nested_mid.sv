module hier_nested_mid(
    input  logic [3:0] x,
    output logic [4:0] y
);
  logic [3:0] leaf_y;
  logic [3:0] helper_y;

  hier_nested_leaf u_leaf(
      .x(x),
      .y(leaf_y)
  );

  hier_nested_mid_helpers u_helper(
      .x(x),
      .y(helper_y)
  );

  assign y = leaf_y + helper_y;
endmodule
