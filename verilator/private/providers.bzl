"""Providers shared across Verilator rules."""

VerilatorFlatCcInfo = provider(
    doc = "Outputs from flat (single-invocation) Verilator compilation.",
    fields = {
        "cc_info": "CcInfo with compilation context and linking context.",
        "module_name": "Name of the top Verilog module.",
    },
)

VerilatorHierCcInfo = provider(
    doc = "Outputs from hierarchical (per-module) Verilator compilation.",
    fields = {
        "cc_info": "CcInfo with compilation context and linking context.",
        "module_name": "Name of the Verilog module at this dep node.",
    },
)
