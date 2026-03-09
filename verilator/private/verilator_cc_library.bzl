"""Rule definition for `verilator_cc_library`."""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("//verilog:defs.bzl", "VerilogInfo")
load(
    ":common.bzl",
    "cc_compile_and_link_static_library",
    "collect_verilog_inputs",
    "copy_generated_cpp_and_hpp",
    "only_sv",
    "verilator_env",
)

def _verilator_cc_library_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]

    verilog_inputs = collect_verilog_inputs(ctx.attr.module)
    verilator_output = ctx.actions.declare_directory(ctx.label.name + "-gen")
    prefix = "V" + ctx.attr.module_top

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--Mdir", verilator_output.path)
    args.add("--top-module", ctx.attr.module_top)
    args.add("--prefix", prefix)
    if ctx.attr.trace:
        args.add("--trace")
    if ctx.attr.systemc:
        if not verilator_toolchain.systemc:
            fail("SystemC output requested but toolchain does not provide SystemC. " +
                 "Either add systemc dependency and use '//verilator:verilator_toolchain_with_systemc', " +
                 "or set systemc=False to use the default toolchain")
        args.add("--sc")
    else:
        args.add("--cc")

    args.add_all(verilog_inputs.includes, format_each = "-I%s")
    args.add_all(verilog_inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(verilator_toolchain.extra_vopts)
    args.add_all(ctx.attr.vopts, expand_directories = False)

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
    defines = ["VM_TRACE"] if ctx.attr.trace else []
    deps = verilator_toolchain.deps
    if ctx.attr.systemc and verilator_toolchain.systemc:
        deps = deps + [verilator_toolchain.systemc]

    return cc_compile_and_link_static_library(
        ctx,
        srcs = [copied_outputs.cpp],
        hdrs = [copied_outputs.hpp],
        defines = defines,
        runfiles = verilog_inputs.runfiles,
        includes = [copied_outputs.hpp.path],
        deps = deps,
    )

verilator_cc_library = rule(
    implementation = _verilator_cc_library_impl,
    attrs = {
        "copts": attr.string_list(
            doc = "List of additional compilation flags",
            default = [],
        ),
        "module": attr.label(
            doc = "The top level module target to verilate.",
            providers = [VerilogInfo],
            mandatory = True,
        ),
        "module_top": attr.string(
            doc = "The name of the verilog module to verilate.",
            mandatory = True,
        ),
        "systemc": attr.bool(
            doc = "Generate SystemC code.",
            default = False,
        ),
        "trace": attr.bool(
            doc = "Enable tracing for Verilator",
            default = False,
        ),
        "vopts": attr.string_list(
            doc = "Additional command line options to pass to Verilator",
            default = ["-Wall"],
        ),
        "_cc_toolchain": attr.label(
            doc = "CC compiler.",
            default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
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
