`include "include_leaf_defs.svh"

module include_leaf (
    input logic [7:0] in_val,
    output logic [7:0] out_val
);

assign out_val = in_val + `INCLUDE_LEAF_OFFSET;

endmodule
