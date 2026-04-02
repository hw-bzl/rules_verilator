"""Shared helper functions for Verilator rules."""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")

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
