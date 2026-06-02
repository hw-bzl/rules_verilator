module hier_nested_top(
    input  logic [3:0] x,
    output logic [4:0] y
);
  hier_nested_mid u_mid(
      .x(x),
      .y(y)
  );
endmodule
