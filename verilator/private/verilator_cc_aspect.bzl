"""Flat and hierarchical Verilator compilation aspects."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@bazel_tools//tools/cpp:toolchain_utils.bzl", "find_cpp_toolchain")
load("@rules_cc//cc:defs.bzl", "CcInfo")
load("@rules_cc//cc/common:cc_common.bzl", "cc_common")
load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(":providers.bzl", "VerilatorFlatCcInfo", "VerilatorHierCcInfo")

_SV_SRC = ["sv", "v"]
_RUNFILES = ["dat", "mem"]

def only_sv(f):
    """Return the path for SystemVerilog sources, or None otherwise."""
    if f.extension in _SV_SRC:
        return f.path
    return None

def _dedupe_preserve_order(items):
    """Return unique non-empty strings while preserving first-seen order."""
    seen = {}
    deduped = []
    for item in items:
        if not item or item in seen:
            continue
        seen[item] = True
        deduped.append(item)
    return deduped

def collect_verilog_inputs(module):
    """Flatten transitive Verilog inputs from `VerilogInfo`.

    Args:
        module: A target providing `VerilogInfo`.

    Returns:
        A struct with `includes`, `runfiles`, and flattened `verilog_files`.
    """
    info = module[VerilogInfo]
    ordered_infos = info.deps.to_list() + [info]

    all_includes = []
    all_files = []
    for dep_info in ordered_infos:
        all_includes.extend(dep_info.includes.to_list())
        all_files.extend(dep_info.srcs.to_list())
        all_files.extend(dep_info.hdrs.to_list())
        all_files.extend(dep_info.data.to_list())

    runfiles = []
    verilog_files = []
    for file in all_files:
        if file.extension in _RUNFILES:
            runfiles.append(file)
        else:
            verilog_files.append(file)

    return struct(
        includes = _dedupe_preserve_order(all_includes),
        runfiles = runfiles,
        verilog_files = verilog_files,
    )

def _verilate_and_compile(target, ctx, out_prefix, hierarchical, extra_compilation_contexts = []):
    """Shared pipeline: run Verilator, split outputs, compile C++.

    Args:
        target: The VerilogInfo target the aspect is applied to.
        ctx: The aspect context.
        out_prefix: Directory/name prefix for outputs (e.g. "adder_VF").
        hierarchical: Whether to pass --hierarchical to Verilator.
        extra_compilation_contexts: Additional CcCompilationContexts to
            include when compiling the generated C++ (e.g. from dep aspects).

    Returns:
        A struct with compilation_context, compilation_outputs, and
        module_name.
    """
    verilator_toolchain = ctx.toolchains["//verilator:toolchain_type"]
    cc_toolchain = find_cpp_toolchain(ctx)
    feature_configuration = cc_common.configure_features(
        ctx = ctx,
        cc_toolchain = cc_toolchain,
        requested_features = ctx.features,
        unsupported_features = ctx.disabled_features,
    )

    info = target[VerilogInfo]
    module_name = info.top_module
    if not module_name:
        fail("`verilog_library.top_module` is required to verilate. Please update `{}`".format(
            target.label,
        ))
    prefix = "V" + module_name

    trace = ctx.attr._trace[BuildSettingInfo].value
    systemc = ctx.attr._systemc[BuildSettingInfo].value

    verilog_inputs = collect_verilog_inputs(target)

    generated_cpp = ctx.actions.declare_directory(out_prefix + "/cpp")
    generated_hpp = ctx.actions.declare_directory(out_prefix + "/hpp")

    args = ctx.actions.args()
    args.add(generated_cpp.path, format = "--output_srcs=%s")
    args.add(generated_hpp.path, format = "--output_hdrs=%s")
    args.add("--")
    args.add(verilator_toolchain.verilator)
    args.add("--no-std")
    if hierarchical:
        args.add("--hierarchical")
    args.add("--Mdir", generated_cpp.dirname)
    args.add("--top-module", module_name)
    args.add("--prefix", prefix)
    if trace:
        args.add("--trace")
    if systemc:
        args.add("--sc")
    else:
        args.add("--cc")
    args.add_all(verilog_inputs.includes, format_each = "-I%s")
    args.add_all(verilog_inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(verilator_toolchain.vopts)

    mode_label = "Hierarchical" if hierarchical else "Flat"
    ctx.actions.run(
        arguments = [args],
        mnemonic = "VerilatorCompile",
        executable = ctx.executable._process_wrapper,
        tools = verilator_toolchain.all_files,
        inputs = verilog_inputs.verilog_files,
        outputs = [generated_cpp, generated_hpp],
        progress_message = "[Verilator] {} compile {}".format(mode_label, ctx.label),
    )

    defines = ["VM_TRACE"] if trace else []
    libverilator = verilator_toolchain.libverilator
    compilation_contexts = [libverilator[CcInfo].compilation_context]
    if systemc and verilator_toolchain.systemc:
        compilation_contexts.append(verilator_toolchain.systemc[CcInfo].compilation_context)
    compilation_contexts.extend(extra_compilation_contexts)

    compilation_context, compilation_outputs = cc_common.compile(
        name = out_prefix,
        actions = ctx.actions,
        feature_configuration = feature_configuration,
        cc_toolchain = cc_toolchain,
        srcs = [generated_cpp],
        includes = [generated_hpp.path],
        defines = defines,
        public_hdrs = [generated_hpp],
        compilation_contexts = compilation_contexts,
        user_compile_flags = verilator_toolchain.copts,
    )

    return struct(
        compilation_context = compilation_context,
        compilation_outputs = compilation_outputs,
        module_name = module_name,
        cc_toolchain = cc_toolchain,
        feature_configuration = feature_configuration,
        verilator_toolchain = verilator_toolchain,
        systemc = systemc,
    )

def _link(ctx, result, compilation_outputs, name):
    """Create a CcInfo with linking context from compilation outputs.

    Args:
        ctx: The aspect context.
        result: The struct returned by _verilate_and_compile.
        compilation_outputs: The CcCompilationOutputs to link (may be
            merged outputs for hierarchical).
        name: Unique name for the archive (must differ between aspects
            on the same target).

    Returns:
        A CcInfo with the compilation context and linking context.
    """
    vt = result.verilator_toolchain
    linking_contexts = [vt.libverilator[CcInfo].linking_context]
    if result.systemc and vt.systemc:
        linking_contexts.append(vt.systemc[CcInfo].linking_context)
    for dep in vt.deps:
        linking_contexts.append(dep[CcInfo].linking_context)

    linking_context, _linking_output = cc_common.create_linking_context_from_compilation_outputs(
        actions = ctx.actions,
        feature_configuration = result.feature_configuration,
        cc_toolchain = result.cc_toolchain,
        compilation_outputs = compilation_outputs,
        linking_contexts = linking_contexts,
        name = name,
        disallow_dynamic_library = True,
        user_link_flags = result.verilator_toolchain.linkopts,
    )

    return CcInfo(
        compilation_context = result.compilation_context,
        linking_context = linking_context,
    )

def _verilator_cc_aspect_impl(target, ctx):
    out_prefix = ctx.label.name + "_VF"
    result = _verilate_and_compile(
        target,
        ctx,
        out_prefix = out_prefix,
        hierarchical = False,
    )
    cc_info = _link(ctx, result, result.compilation_outputs, name = out_prefix)
    return [
        VerilatorFlatCcInfo(
            cc_info = cc_info,
            module_name = result.module_name,
        ),
    ]

_ASPECT_ATTRS = {
    "_cc_toolchain": attr.label(
        default = Label("@bazel_tools//tools/cpp:current_cc_toolchain"),
    ),
    "_process_wrapper": attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//verilator/private:verilator_process_wrapper"),
    ),
    "_systemc": attr.label(
        default = Label("//verilator/private:_systemc"),
    ),
    "_trace": attr.label(
        default = Label("//verilator/private:_trace"),
    ),
}

_ASPECT_TOOLCHAINS = [
    "//verilator:toolchain_type",
    "@rules_cc//cc:toolchain_type",
]

verilator_cc_aspect = aspect(
    implementation = _verilator_cc_aspect_impl,
    attr_aspects = [],
    required_providers = [VerilogInfo],
    attrs = _ASPECT_ATTRS,
    toolchains = _ASPECT_TOOLCHAINS,
    fragments = ["cpp"],
    provides = [VerilatorFlatCcInfo],
)

def _verilator_hier_cc_aspect_impl(target, ctx):
    dep_cc_infos = []
    extra_contexts = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if VerilatorHierCcInfo in dep:
                dep_info = dep[VerilatorHierCcInfo]
                dep_cc_infos.append(dep_info.cc_info)
                extra_contexts.append(dep_info.cc_info.compilation_context)

    out_prefix = ctx.label.name + "_VH"
    result = _verilate_and_compile(
        target,
        ctx,
        out_prefix = out_prefix,
        hierarchical = True,
        extra_compilation_contexts = extra_contexts,
    )

    this_cc_info = _link(ctx, result, result.compilation_outputs, name = out_prefix)
    merged_cc_info = cc_common.merge_cc_infos(cc_infos = [this_cc_info] + dep_cc_infos)

    return [
        VerilatorHierCcInfo(
            cc_info = merged_cc_info,
            module_name = result.module_name,
        ),
    ]

verilator_hier_cc_aspect = aspect(
    implementation = _verilator_hier_cc_aspect_impl,
    attr_aspects = ["deps"],
    required_providers = [VerilogInfo],
    attrs = _ASPECT_ATTRS,
    toolchains = _ASPECT_TOOLCHAINS,
    fragments = ["cpp"],
    provides = [VerilatorHierCcInfo],
)
