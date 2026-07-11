"""Internal helpers for hierarchical Verilator builds."""

load(
    ":common.bzl",
    "add_common_verilator_args",
    "cc_compile_and_link_static_library",
    "collect_verilog_inputs",
    "copy_generated_cpp_and_hpp",
    "hierarchical_prefix",
    "only_sv",
    "timing_copts",
    "timing_deps",
    "trace_defines",
    "validate_verilator_options",
    "verilator_env",
)
load(":hierarchy_plan.bzl", "build_hierarchy_plan")
load(":providers.bzl", "VerilatorVerilogGraphInfo")

def _copy_file_from_tree(ctx, generated_dir, output, relative_paths):
    # Verilator emits per-node metadata into a tree artifact. Extract the single
    # generated file we need so later actions can depend on ordinary files.
    ctx.actions.run(
        executable = ctx.executable._copy_file,
        arguments = [generated_dir.path + "/" + path for path in relative_paths] + [output.path],
        inputs = [generated_dir],
        outputs = [output],
        mnemonic = "VerilatorCopyFile",
    )

def _run_hierarchical_discovery(ctx, verilator_toolchain, root_module_top, node_plan, trace_mode):
    # Run Verilator once in discovery mode to ask it how to compile each
    # hierarchical node. The resulting `__hierMkJsonArgs.f` files drive all
    # subsequent per-node compile actions.
    verilog_inputs = collect_verilog_inputs(ctx.attr.module)
    validate_verilator_options(verilator_toolchain, ctx.attr.vopts, ctx.label)

    block_names = [name for name in node_plan.node_names if name != root_module_top]
    control_file = ctx.actions.declare_file(ctx.label.name + ".hier.vlt")
    ctx.actions.write(
        output = control_file,
        content = "`verilator_config\n" + "".join(["hier_block -module \"{}\"\n".format(name) for name in block_names]),
    )

    generated_dir = ctx.actions.declare_directory(ctx.label.name + "_hier_plan_gen")
    prefix = hierarchical_prefix(root_module_top)

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    args.add("--cc")
    args.add("--make", "json")
    args.add("--hierarchical")
    args.add("--Mdir", generated_dir.path)
    args.add("--top-module", root_module_top)
    args.add("--prefix", prefix)
    args.add(control_file.path)
    add_common_verilator_args(
        args,
        verilator_toolchain,
        timing = ctx.attr.timing,
        trace_mode = trace_mode,
        includes = verilog_inputs.includes,
        verilog_files = verilog_inputs.verilog_files,
        vopts = ctx.attr.vopts,
    )

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

    args_files = {}
    for node_name in node_plan.node_names:
        args_file = ctx.actions.declare_file(ctx.label.name + "_" + node_name + "__hierMkJsonArgs.f")
        _copy_file_from_tree(
            ctx,
            generated_dir,
            args_file,
            [
                hierarchical_prefix(node_name) + "__hierMkJsonArgs.f",
                hierarchical_prefix(node_name) + "__hierCMakeArgs.f",
            ],
        )
        args_files[node_name] = args_file

    return struct(
        args_files = args_files,
        control_file = control_file,
    )

def _compile_hierarchy_node(ctx, verilator_toolchain, root_module_top, node_name, node, child_results, discovery, trace_mode):
    generated_dir = ctx.actions.declare_directory(ctx.label.name + "_" + node_name + "_gen")
    output_stem = ctx.label.name + "_" + node_name
    is_root = node_name == root_module_top

    args = ctx.actions.args()
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    if is_root:
        # The root compile still owns the final top-level entry point and emits
        # the public wrapper used by downstream C++ targets.
        args.add("--cc")
        args.add("--make", "json")
        args.add("--top-module", root_module_top)
        args.add("--prefix", hierarchical_prefix(root_module_top))
    args.add("--Mdir", generated_dir.path)
    args.add("-f", discovery.args_files[node_name].path)
    args.add_all([child.wrapper_sv for child in child_results], expand_directories = True, map_each = only_sv)
    add_common_verilator_args(
        args,
        verilator_toolchain,
        timing = ctx.attr.timing,
        trace_mode = trace_mode,
        includes = node["includes"],
        verilog_files = node["compile_files"],
        vopts = ctx.attr.vopts,
    )

    # Per-node hierarchical compiles consume generated child wrapper SV files.
    # Keep these after common/user vopts so the default -Wall cannot re-enable
    # warnings from Verilator-generated wrappers.
    args.add("-Wno-DECLFILENAME")
    args.add("-Wno-UNUSEDSIGNAL")

    inputs = list(node["compile_files"]) + [discovery.args_files[node_name], discovery.control_file]
    inputs.extend([child.wrapper_sv for child in child_results])
    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorHierCompile",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = inputs,
        outputs = [generated_dir],
        progress_message = "[Verilator] Compiling hierarchical node {} for {}".format(node_name, ctx.label),
        env = verilator_env(verilator_toolchain),
    )

    wrapper_sv = None
    if not is_root:
        wrapper_sv = ctx.actions.declare_file(output_stem + "/" + node_name + ".sv")
        _copy_file_from_tree(
            ctx,
            generated_dir,
            wrapper_sv,
            [node_name + ".sv"],
        )

    copied_outputs = copy_generated_cpp_and_hpp(ctx, generated_dir, output_stem = output_stem)
    defines = trace_defines(trace_mode)
    deps = timing_deps(
        ctx,
        verilator_toolchain,
        timing = ctx.attr.timing,
        systemc = False,
    )
    runfiles = list(node["runfiles"])
    for child in child_results:
        runfiles.extend(child.default_info.default_runfiles.files.to_list())

    providers = cc_compile_and_link_static_library(
        ctx,
        name = output_stem,
        srcs = [copied_outputs.cpp],
        hdrs = [copied_outputs.hpp],
        defines = defines,
        runfiles = runfiles,
        includes = [copied_outputs.hpp.path],
        compile_deps = deps,
        link_deps = deps + [child.cc_info for child in child_results],
        extra_copts = timing_copts(ctx, ctx.attr.timing),
    )
    return struct(
        cc_info = providers[1],
        default_info = providers[0],
        wrapper_sv = wrapper_sv,
    )

def compile_hierarchical_verilator_library(ctx, verilator_toolchain, root_module_top, trace_mode):
    """Compile a verilog_library graph using automatic hierarchy discovery.

    Args:
        ctx: Rule context for the owning `verilator_cc_library`.
        verilator_toolchain: The resolved Verilator toolchain info.
        root_module_top: The resolved root top module name for this build.
        trace_mode: The selected trace mode for all discovery and node compile actions.

    Returns:
        A `[DefaultInfo, CcInfo]` pair for the root hierarchical library.
    """
    graph_info = ctx.attr.module[VerilatorVerilogGraphInfo]
    node_plan = build_hierarchy_plan(graph_info, root_module_top)
    discovery = _run_hierarchical_discovery(ctx, verilator_toolchain, root_module_top, node_plan, trace_mode)

    compiled_nodes = {}

    # `node_names` is postorder, so children are always compiled before the
    # parent that links against them.
    for node_name in node_plan.node_names:
        node = node_plan.nodes[node_name]
        child_results = [compiled_nodes[child_name] for child_name in node["children"]]
        compiled_nodes[node_name] = _compile_hierarchy_node(
            ctx,
            verilator_toolchain,
            root_module_top,
            node_name,
            node,
            child_results,
            discovery,
            trace_mode,
        )

    root_result = compiled_nodes[root_module_top]
    return [
        root_result.default_info,
        root_result.cc_info,
    ]
