"""Rule definition for `verilator_cc_library`."""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(":providers.bzl", "VerilatorFlatCcInfo", "VerilatorHierCcInfo")
load(":transitions.bzl", "verilator_settings_transition")
load(":verilator_cc_aspect.bzl", "verilator_cc_aspect", "verilator_hier_cc_aspect")

def _verilator_cc_library_impl(ctx):
    module = ctx.attr.module[0]

    if ctx.attr.hierarchical:
        info = module[VerilatorHierCcInfo]
    else:
        info = module[VerilatorFlatCcInfo]

    verilog_info = module[VerilogInfo]
    ordered_infos = verilog_info.deps.to_list() + [verilog_info]
    runfiles = []
    for dep_info in ordered_infos:
        runfiles.extend(dep_info.data.to_list())

    return [
        DefaultInfo(runfiles = ctx.runfiles(files = runfiles)),
        info.cc_info,
    ]

verilator_cc_library = rule(
    implementation = _verilator_cc_library_impl,
    attrs = {
        "data": attr.label_list(
            doc = "Data files needed at runtime.",
            allow_files = True,
        ),
        "hierarchical": attr.bool(
            doc = "Use hierarchical compilation (per-module). Default flat (single invocation).",
            default = False,
        ),
        "module": attr.label(
            doc = "The top level module target to verilate.",
            providers = [VerilogInfo],
            mandatory = True,
            aspects = [verilator_cc_aspect, verilator_hier_cc_aspect],
            cfg = verilator_settings_transition,
        ),
        "systemc": attr.bool(
            doc = "Generate SystemC code.",
            default = False,
        ),
        "trace": attr.bool(
            doc = "Enable tracing for Verilator.",
            default = False,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    provides = [CcInfo],
    toolchains = ["//verilator:toolchain_type"],
)
