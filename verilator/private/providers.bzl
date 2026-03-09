"""Providers shared across Verilator rules."""

VerilatorHierPlanInfo = provider(
    doc = "Hierarchical Verilator discovery outputs shared by block/top rules.",
    fields = {
        "block_args": "A dict mapping hierarchical block names to args files.",
        "control_file": "Auto-generated .vlt file shared by all hierarchical actions.",
        "module_top": "Top module name for the hierarchical design.",
        "top_args": "Args file for the hierarchical top compilation.",
        "trace": "Whether tracing is enabled.",
        "vopts": "User-provided Verilator options shared by all hierarchical actions.",
    },
)

VerilatorHierBlockInfo = provider(
    doc = "Outputs produced by a compiled hierarchical child block.",
    fields = {
        "block": "Hierarchical block name.",
        "wrapper_sv": "Generated wrapper SystemVerilog file consumed by the top rule.",
    },
)
