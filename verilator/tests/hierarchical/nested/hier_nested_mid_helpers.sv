module hier_nested_mid_helpers(
    input  logic [3:0] x,
    output logic [3:0] y
);
  assign y = x ^ 4'h3;
endmodule
