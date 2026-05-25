"""Verilog graph collection helpers for Verilator rules."""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(":providers.bzl", "VerilatorVerilogGraphInfo")

def _library_key(label):
    return str(label)

def _collect_postorder_libraries(dep_infos, library):
    # Keep a stable postorder so later planning can assign children before their
    # parents without needing recursive analysis-time traversal.
    libraries = []
    seen_labels = {}
    for dep_info in dep_infos:
        for dep_library in dep_info.postorder_libraries:
            label_key = _library_key(dep_library.label)
            if label_key in seen_labels:
                continue
            seen_labels[label_key] = True
            libraries.append(dep_library)
    libraries.append(library)
    return libraries

def _new_library_entry(target, ctx, dep_infos, hdr_includes, pkg_includes):
    # Capture only the files declared directly on this verilog_library. The
    # hierarchical planner needs library boundaries, not the flattened view from
    # VerilogInfo.
    return struct(
        label = target.label,
        top_module = target[VerilogInfo].top_module,
        srcs = list(ctx.rule.files.srcs) if hasattr(ctx.rule.files, "srcs") else [],
        hdrs = list(ctx.rule.files.hdrs) if hasattr(ctx.rule.files, "hdrs") else [],
        data = list(ctx.rule.files.data) if hasattr(ctx.rule.files, "data") else [],
        includes = hdr_includes + pkg_includes,
        dep_labels = [dep.label for dep in dep_infos],
    )

def _verilator_verilog_graph_aspect_impl(target, ctx):
    if VerilogInfo not in target:
        return []

    dep_infos = []
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if VerilatorVerilogGraphInfo in dep:
                dep_infos.append(dep[VerilatorVerilogGraphInfo])

    hdr_includes = []
    if hasattr(ctx.rule.files, "hdrs"):
        hdr_includes = [f.dirname for f in ctx.rule.files.hdrs]

    pkg_includes = []
    if hasattr(ctx.rule.attr, "includes"):
        if ctx.label.package:
            pkg_includes = [ctx.label.package + "/" + inc if inc else ctx.label.package for inc in ctx.rule.attr.includes]
        else:
            pkg_includes = [inc for inc in ctx.rule.attr.includes if inc]

    library = _new_library_entry(target, ctx, dep_infos, hdr_includes, pkg_includes)

    return [VerilatorVerilogGraphInfo(
        label = target.label,
        top_module = target[VerilogInfo].top_module,
        srcs = library.srcs,
        hdrs = library.hdrs,
        data = library.data,
        includes = library.includes,
        direct_deps = dep_infos,
        postorder_libraries = _collect_postorder_libraries(dep_infos, library),
    )]

verilator_verilog_graph_aspect = aspect(
    implementation = _verilator_verilog_graph_aspect_impl,
    attr_aspects = ["deps"],
)

def resolve_module_top(module, module_top_attr, owner_label):
    # `module_top` remains as an explicit override for compatibility, but the
    # canonical source is `verilog_library(top_module = ...)`.
    module_top = module_top_attr if module_top_attr else module[VerilogInfo].top_module
    if not module_top:
        fail(
            "{} requires a top module. Set `module_top` on the rule or `top_module` on {}.".format(
                owner_label,
                module.label,
            ),
        )
    return module_top
