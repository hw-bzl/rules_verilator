module include_top (
    input logic [7:0] in_val,
    output logic [7:0] out_val
);

include_leaf u_include_leaf (
    .in_val(in_val),
    .out_val(out_val)
);

endmodule
