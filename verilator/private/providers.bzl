"""Providers shared across Verilator rules."""

VerilatorVerilogGraphInfo = provider(
    doc = "Verilog library graph retained for hierarchical Verilation.",
    fields = {
        "data": "List[File]: Local data files declared on this verilog_library.",
        "direct_deps": "List[VerilatorVerilogGraphInfo]: Direct verilog_library dependencies.",
        "hdrs": "List[File]: Local Verilog/SV headers declared on this library.",
        "includes": "List[str]: Local include search paths declared on this library.",
        "label": "Label: The verilog_library label that produced this node.",
        "postorder_libraries": "List[struct]: Transitive verilog_library entries in postorder, including this node.",
        "srcs": "List[File]: Local Verilog/SV source files declared on this library.",
        "top_module": "str: The library-local top module declaration.",
    },
)
