module hier_nested_leaf(
    input  logic [3:0] x,
    output logic [3:0] y
);
  assign y = x + 4'd2;
endmodule
