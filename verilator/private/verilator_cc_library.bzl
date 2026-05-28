"""Rule definition for `verilator_cc_library`."""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(
    ":common.bzl",
    "add_common_verilator_args",
    "cc_compile_and_link_static_library",
    "collect_verilog_inputs",
    "copy_generated_cpp_and_hpp",
    "resolve_trace_mode",
    "timing_copts",
    "timing_deps",
    "trace_defines",
    "validate_verilator_options",
    "verilator_env",
    "verilator_no_timing_transition",
    "verilator_timing_transition",
)
load(
    ":hierarchical.bzl",
    "compile_hierarchical_verilator_library",
)
load(
    ":verilog_graph.bzl",
    "resolve_module_top",
    "verilator_verilog_graph_aspect",
)

def _verilator_cc_library_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]
    module_top = resolve_module_top(ctx.attr.module, ctx.attr.module_top, ctx.label)
    trace_mode = resolve_trace_mode(ctx.attr.trace, ctx.attr.trace_mode, ctx.label)
    if ctx.attr.hierarchical:
        if ctx.attr.systemc:
            fail("hierarchical Verilation currently supports only C++ output; set systemc = False.")
        return compile_hierarchical_verilator_library(ctx, verilator_toolchain, module_top, trace_mode)

    # Flat mode keeps the original behavior: flatten the Verilog graph, run
    # Verilator once, then compile the generated C++ as a single static library.
    verilog_inputs = collect_verilog_inputs(ctx.attr.module)
    verilator_output = ctx.actions.declare_directory(ctx.label.name + "-gen")
    prefix = "V" + module_top
    timing = ctx.attr.timing

    validate_verilator_options(verilator_toolchain, ctx.attr.vopts, ctx.label)

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--Mdir", verilator_output.path)
    args.add("--top-module", module_top)
    args.add("--prefix", prefix)
    if ctx.attr.systemc:
        if not verilator_toolchain.systemc:
            fail("SystemC output requested but toolchain does not provide SystemC. " +
                 "Either add systemc dependency and use '//verilator:verilator_toolchain_with_systemc', " +
                 "or set systemc=False to use the default toolchain")
        args.add("--sc")
    else:
        args.add("--cc")

    add_common_verilator_args(
        args,
        verilator_toolchain,
        timing = timing,
        trace_mode = trace_mode,
        includes = verilog_inputs.includes,
        verilog_files = verilog_inputs.verilog_files,
        vopts = ctx.attr.vopts,
    )

    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorCompile",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = verilog_inputs.verilog_files,
        outputs = [verilator_output],
        progress_message = "[Verilator] Compiling {}".format(ctx.label),
        env = verilator_env(verilator_toolchain),
    )

    copied_outputs = copy_generated_cpp_and_hpp(ctx, verilator_output)
    defines = trace_defines(trace_mode)
    deps = timing_deps(
        ctx,
        verilator_toolchain,
        timing = timing,
        systemc = ctx.attr.systemc and verilator_toolchain.systemc != None,
    )

    return cc_compile_and_link_static_library(
        ctx,
        srcs = [copied_outputs.cpp],
        hdrs = [copied_outputs.hpp],
        defines = defines,
        runfiles = verilog_inputs.runfiles,
        includes = [copied_outputs.hpp.path],
        deps = deps,
        extra_copts = timing_copts(ctx, timing),
    )

verilator_cc_library = rule(
    implementation = _verilator_cc_library_impl,
    attrs = {
        "copts": attr.string_list(
            doc = "List of additional compilation flags",
            default = [],
        ),
        "hierarchical": attr.bool(
            doc = "Enable automatic hierarchical Verilation using verilog_library top_module boundaries.",
            default = False,
        ),
        "module": attr.label(
            doc = "The top level module target to verilate.",
            providers = [VerilogInfo],
            mandatory = True,
            aspects = [verilator_verilog_graph_aspect],
        ),
        "module_top": attr.string(
            doc = "Optional top module override. Defaults to module[VerilogInfo].top_module when omitted.",
            default = "",
        ),
        "systemc": attr.bool(
            doc = "Generate SystemC code.",
            default = False,
        ),
        "timing": attr.bool(
            doc = "Enable Verilator timing support and link the timing runtime.",
            default = False,
        ),
        "trace": attr.bool(
            doc = "Deprecated compatibility alias for `trace_mode = \"vcd\"`.",
            default = False,
        ),
        "trace_mode": attr.string(
            doc = "Waveform trace mode: `none`, `vcd`, `fst`, or `saif`.",
            default = "none",
            values = ["none", "vcd", "fst", "saif"],
        ),
        "vopts": attr.string_list(
            doc = "Additional command line options to pass to Verilator",
            default = ["-Wall"],
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_cc_toolchain": attr.label(
            doc = "CC compiler.",
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
        ),
        "_copy_file": attr.label(
            doc = "A tool for copying a single file out of a tree artifact.",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_copy_file"),
        ),
        "_copy_tree": attr.label(
            doc = "A tool for copying a tree of files",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_copy_tree"),
        ),
        "_process_wrapper": attr.label(
            doc = "The Verilator process wrapper binary.",
            executable = True,
            cfg = "exec",
            default = Label("//verilator/private:verilator_process_wrapper"),
        ),
        "_verilated_runtime": attr.label(
            cfg = verilator_no_timing_transition,
            default = Label("//verilator:verilated_runtime"),
            providers = [CcInfo],
        ),
        "_verilated_timing_runtime": attr.label(
            cfg = verilator_timing_transition,
            default = Label("//verilator:verilated_runtime"),
            providers = [CcInfo],
        ),
    },
    provides = [
        CcInfo,
        DefaultInfo,
    ],
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "//verilator:toolchain_type",
    ],
    fragments = ["cpp"],
)
