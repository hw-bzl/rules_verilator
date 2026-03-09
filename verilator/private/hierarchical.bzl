"""Hierarchical Verilator rule definitions."""

load("@rules_cc//cc:defs.bzl", "CcInfo")
load("//verilog:defs.bzl", "VerilogInfo")
load(
    ":common.bzl",
    "cc_compile_and_link_static_library",
    "collect_verilog_inputs",
    "copy_generated_cpp_and_hpp",
    "hierarchical_prefix",
    "only_sv",
    "verilator_env",
)
load(
    ":providers.bzl",
    "VerilatorHierBlockInfo",
    "VerilatorHierPlanInfo",
)

def _copy_file_from_tree(ctx, generated_dir, output, relative_paths):
    """Copy one file from a tree artifact, with optional fallbacks."""
    ctx.actions.run(
        executable = ctx.executable._copy_file,
        arguments = [generated_dir.path + "/" + path for path in relative_paths] + [output.path],
        inputs = [generated_dir],
        outputs = [output],
        mnemonic = "VerilatorCopyFile",
    )

def _collect_ordered_block_infos(block_deps, plan, plan_label):
    """Validate hierarchical block deps and return them in stable order."""
    block_infos = {dep[VerilatorHierBlockInfo].block: dep for dep in block_deps}
    if len(block_infos) != len(block_deps):
        fail("block_deps must be unique")
    for block in block_infos.keys():
        if block not in plan.block_args:
            fail("block '{}' is not declared in {}".format(block, plan_label))
    if len(block_infos) != len(plan.block_args):
        fail("block_deps must exactly match blocks declared in {}".format(plan_label))
    return [block_infos[block] for block in sorted(block_infos.keys())]

def _verilator_hierarchical_plan_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]
    verilog_inputs = collect_verilog_inputs(ctx.attr.module)

    blocks = ctx.attr.blocks
    if not blocks:
        fail("blocks must not be empty")
    if len(blocks) != len({block: True for block in blocks}.keys()):
        fail("blocks must be unique")
    if ctx.attr.module_top in blocks:
        fail("module_top must not also appear in blocks")

    control_file = ctx.actions.declare_file(ctx.label.name + ".hier.vlt")
    ctx.actions.write(
        output = control_file,
        content = "`verilator_config\n" + "".join(["hier_block -module \"{}\"\n".format(block) for block in blocks]),
    )

    generated_dir = ctx.actions.declare_directory(ctx.label.name + "-gen")
    prefix = hierarchical_prefix(ctx.attr.module_top)

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--cc")
    args.add("--make", "json")
    args.add("--hierarchical")
    args.add("--Mdir", generated_dir.path)
    args.add("--top-module", ctx.attr.module_top)
    args.add("--prefix", prefix)
    if ctx.attr.trace:
        args.add("--trace")
    args.add_all(verilog_inputs.includes, format_each = "-I%s")
    args.add(control_file.path)
    args.add_all(verilog_inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(verilator_toolchain.extra_vopts)
    args.add_all(ctx.attr.vopts, expand_directories = False)

    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorHierPlan",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = verilog_inputs.verilog_files + [control_file],
        outputs = [generated_dir],
        progress_message = "[Verilator] Discovering hierarchy for {}".format(ctx.label),
        env = verilator_env(verilator_toolchain),
    )

    block_args = {}
    block_outputs = []
    for block in blocks:
        block_args_file = ctx.actions.declare_file(ctx.label.name + "_" + block + "__hierMkJsonArgs.f")
        _copy_file_from_tree(
            ctx,
            generated_dir,
            block_args_file,
            [
                hierarchical_prefix(block) + "__hierMkJsonArgs.f",
                hierarchical_prefix(block) + "__hierCMakeArgs.f",
            ],
        )
        block_args[block] = block_args_file
        block_outputs.append(block_args_file)

    top_args = ctx.actions.declare_file(ctx.label.name + "_" + ctx.attr.module_top + "__hierMkJsonArgs.f")
    _copy_file_from_tree(
        ctx,
        generated_dir,
        top_args,
        [
            prefix + "__hierMkJsonArgs.f",
            prefix + "__hierCMakeArgs.f",
        ],
    )

    files = [control_file, top_args] + block_outputs
    return [
        DefaultInfo(files = depset(files)),
        VerilatorHierPlanInfo(
            block_args = block_args,
            module_top = ctx.attr.module_top,
            top_args = top_args,
            control_file = control_file,
            trace = ctx.attr.trace,
            vopts = ctx.attr.vopts,
        ),
    ]

def _verilator_hierarchical_block_cc_library_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]
    plan = ctx.attr.plan[VerilatorHierPlanInfo]
    if ctx.attr.block not in plan.block_args:
        fail("block '{}' is not declared in {}".format(ctx.attr.block, ctx.attr.plan.label))

    verilog_inputs = collect_verilog_inputs(ctx.attr.module)
    generated_dir = ctx.actions.declare_directory(ctx.label.name + "-gen")
    wrapper_sv = ctx.actions.declare_file(ctx.label.name + "/" + ctx.attr.block + ".sv")

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--Mdir", generated_dir.path)
    if plan.trace:
        args.add("--trace")
    args.add("-f", plan.block_args[ctx.attr.block].path)
    args.add_all(verilog_inputs.includes, format_each = "-I%s")
    args.add_all(verilog_inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(verilator_toolchain.extra_vopts)
    args.add_all(plan.vopts, expand_directories = False)

    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorHierBlockCompile",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = verilog_inputs.verilog_files + [plan.block_args[ctx.attr.block], plan.control_file],
        outputs = [generated_dir],
        progress_message = "[Verilator] Compiling hierarchical block {}".format(ctx.label),
        env = verilator_env(verilator_toolchain),
    )

    _copy_file_from_tree(
        ctx,
        generated_dir,
        wrapper_sv,
        [ctx.attr.block + ".sv"],
    )

    copied_outputs = copy_generated_cpp_and_hpp(ctx, generated_dir)
    defines = ["VM_TRACE"] if plan.trace else []
    compile_and_link_outputs = cc_compile_and_link_static_library(
        ctx,
        srcs = [copied_outputs.cpp],
        hdrs = [copied_outputs.hpp],
        defines = defines,
        runfiles = verilog_inputs.runfiles,
        includes = [copied_outputs.hpp.path],
        deps = verilator_toolchain.deps,
    )

    return compile_and_link_outputs + [
        VerilatorHierBlockInfo(
            block = ctx.attr.block,
            wrapper_sv = wrapper_sv,
        ),
    ]

def _verilator_hierarchical_top_cc_library_impl(ctx):
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]
    plan = ctx.attr.plan[VerilatorHierPlanInfo]
    verilog_inputs = collect_verilog_inputs(ctx.attr.module)
    generated_dir = ctx.actions.declare_directory(ctx.label.name + "-gen")
    prefix = hierarchical_prefix(plan.module_top)

    ordered_block_infos = _collect_ordered_block_infos(
        ctx.attr.block_deps,
        plan,
        ctx.attr.plan.label,
    )
    block_link_deps = ordered_block_infos
    block_wrappers = [info[VerilatorHierBlockInfo].wrapper_sv for info in ordered_block_infos]
    block_runfiles = []
    for info in ordered_block_infos:
        block_runfiles.extend(info[DefaultInfo].default_runfiles.files.to_list())

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--cc")
    args.add("--make", "json")
    args.add("--Mdir", generated_dir.path)
    args.add("--top-module", plan.module_top)
    args.add("--prefix", prefix)
    if plan.trace:
        args.add("--trace")
    args.add("-f", plan.top_args.path)
    args.add_all(verilog_inputs.includes, format_each = "-I%s")
    args.add_all(block_wrappers, expand_directories = True, map_each = only_sv)
    args.add_all(verilog_inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(verilator_toolchain.extra_vopts)
    args.add_all(plan.vopts, expand_directories = False)
    args.add("-Wno-DECLFILENAME")
    args.add("-Wno-UNUSEDSIGNAL")

    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorHierTopCompile",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = verilog_inputs.verilog_files + block_wrappers + [plan.top_args, plan.control_file],
        outputs = [generated_dir],
        progress_message = "[Verilator] Compiling hierarchical top {}".format(ctx.label),
        env = verilator_env(verilator_toolchain),
    )

    copied_outputs = copy_generated_cpp_and_hpp(ctx, generated_dir)
    defines = ["VM_TRACE"] if plan.trace else []
    compile_and_link_deps = verilator_toolchain.deps
    return cc_compile_and_link_static_library(
        ctx,
        srcs = [copied_outputs.cpp],
        hdrs = [copied_outputs.hpp],
        defines = defines,
        runfiles = verilog_inputs.runfiles + block_runfiles,
        includes = [copied_outputs.hpp.path],
        compile_deps = compile_and_link_deps,
        link_deps = compile_and_link_deps + block_link_deps,
    )

verilator_hierarchical_plan = rule(
    doc = "Create shared discovery outputs for hierarchical Verilation.",
    implementation = _verilator_hierarchical_plan_impl,
    attrs = {
        "blocks": attr.string_list(
            doc = "Hierarchical child module names to compile as independent blocks.",
            mandatory = True,
        ),
        "module": attr.label(
            doc = "Full design graph used for hierarchical discovery.",
            providers = [VerilogInfo],
            mandatory = True,
        ),
        "module_top": attr.string(
            doc = "Top module name for hierarchical Verilation.",
            mandatory = True,
        ),
        "trace": attr.bool(
            doc = "Enable tracing for all hierarchical compilations.",
            default = False,
        ),
        "vopts": attr.string_list(
            doc = "Additional command line options to pass to Verilator discovery.",
            default = ["-Wall"],
        ),
        "_copy_file": attr.label(
            doc = "A tool for copying a single file out of a tree artifact.",
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_copy_file"),
        ),
        "_process_wrapper": attr.label(
            doc = "The Verilator process wrapper binary.",
            executable = True,
            cfg = "exec",
            default = Label("//verilator/private:verilator_process_wrapper"),
        ),
    },
    provides = [DefaultInfo, VerilatorHierPlanInfo],
    toolchains = ["//verilator:toolchain_type"],
)

verilator_hierarchical_block_cc_library = rule(
    doc = "Compile a hierarchical child block into a standalone C++ static library.",
    implementation = _verilator_hierarchical_block_cc_library_impl,
    attrs = {
        "block": attr.string(
            doc = "Hierarchical block name as declared in the plan.",
            mandatory = True,
        ),
        "copts": attr.string_list(
            doc = "List of additional compilation flags",
            default = [],
        ),
        "module": attr.label(
            doc = "The Verilog sources for this hierarchical block and its local deps.",
            providers = [VerilogInfo],
            mandatory = True,
        ),
        "plan": attr.label(
            doc = "The shared hierarchical discovery target.",
            providers = [VerilatorHierPlanInfo],
            mandatory = True,
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
    },
    provides = [CcInfo, DefaultInfo, VerilatorHierBlockInfo],
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "//verilator:toolchain_type",
    ],
    fragments = ["cpp"],
)

verilator_hierarchical_top_cc_library = rule(
    doc = "Compile the hierarchical top wrapper and link child block libraries transitively.",
    implementation = _verilator_hierarchical_top_cc_library_impl,
    attrs = {
        "block_deps": attr.label_list(
            doc = "Hierarchical child block libraries linked into the top library.",
            providers = [CcInfo, VerilatorHierBlockInfo],
            mandatory = True,
        ),
        "copts": attr.string_list(
            doc = "List of additional compilation flags",
            default = [],
        ),
        "module": attr.label(
            doc = "Top-local Verilog sources for the hierarchical wrapper.",
            providers = [VerilogInfo],
            mandatory = True,
        ),
        "plan": attr.label(
            doc = "The shared hierarchical discovery target.",
            providers = [VerilatorHierPlanInfo],
            mandatory = True,
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
    provides = [CcInfo, DefaultInfo],
    toolchains = [
        "@bazel_tools//tools/cpp:toolchain_type",
        "//verilator:toolchain_type",
    ],
    fragments = ["cpp"],
)
