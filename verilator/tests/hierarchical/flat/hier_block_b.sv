module hier_block_b(
    input  logic [3:0] x,
    output logic [3:0] y
);
  assign y = x ^ 4'hf;
endmodule
