# rules_verilator

[![BCR](https://img.shields.io/badge/BCR-rules_verilator-green?logo=bazel)](https://registry.bazel.build/modules/rules_verilator)
[![CI](https://github.com/MrAMS/bazel_rules_verilator/actions/workflows/ci.yml/badge.svg)](https://github.com/MrAMS/bazel_rules_verilator/actions/workflows/ci.yml)

Bazel rules for Verilator-based SystemVerilog simulation using the Bazel Central Registry (BCR) Verilator toolchain.

## Features

- Uses BCR Verilator for better reproducibility and version management
- Supports both C++ and SystemC output
- Support incremental hierarchical builds
- Optional waveform tracing support

## Installation

### Default C++ toolchain

Add the following to your `MODULE.bazel`:

```starlark
bazel_dep(name = "rules_verilator", version = "0.3.3")
register_toolchains(
    "@rules_verilator//verilator:verilator_toolchain",
)
```

The default toolchain supports C++ output only and does not require SystemC.

### With SystemC Support

If you need SystemC output, add the SystemC dependency and register the SystemC-enabled toolchain:

```starlark
bazel_dep(name = "rules_verilator", version = "0.3.3")

# Register the SystemC-enabled toolchain
register_toolchains(
    "@rules_verilator//verilator:verilator_toolchain_with_systemc",
)
```

## Usage

You can check `verilator/tests` for examples as well.

### Verilator C++ Library

```starlark
load("@rules_verilator//verilator:defs.bzl", "verilator_cc_library")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")

verilog_library(
    name = "my_module",
    srcs = ["my_top_module.sv"],
    top_module = "my_top_module",
)

verilator_cc_library(
    name = "my_verilated_lib",
    module = ":my_module",
    timing = True,  # Enable timing support (--timing)
    trace = True,   # Enable waveform tracing (--trace)
    vopts = [
        "-Wall",
        "--x-assign fast",
        "--x-initial fast",
    ],
)

cc_binary(
    name = "my_test",
    srcs = ["testbench.cpp"],
    deps = [":my_verilated_lib"],
)
```

`module_top` remains available as an override when you need to verilate a different top than the one declared on the `verilog_library`, but the recommended style is to put the canonical top in `verilog_library(top_module = ...)`.

### Verilator SystemC Library

```starlark
load("@rules_verilator//verilator:defs.bzl", "verilator_cc_library")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")

verilog_library(
    name = "my_module",
    srcs = ["my_top_module.sv"],
    top_module = "my_top_module",
)

verilator_cc_library(
    name = "my_verilated_sc_lib",
    module = ":my_module",
    systemc = True,  # Generate SystemC output
    timing = True,
    trace = True,
    vopts = ["-Wall"],
)

cc_binary(
    name = "my_sc_test",
    srcs = ["testbench_sc.cpp"],
    deps = [":my_verilated_sc_lib"],
)
```

### Hierarchical Verilation

For [verilator's hierarchical verilation](https://verilator.org/guide/latest/verilating.html#hierarchical-verilation), enable `hierarchical = True` on `verilator_cc_library`.

Hierarchical Verilation splits a large design into multiple Verilated libraries instead of compiling the whole RTL graph as one flat model. The top-level model then calls into the generated models for selected lower-level blocks. This usually helps when a design is large enough that flat Verilation becomes expensive in time or memory, and when incremental rebuilds should reuse cached results for unchanged blocks.

The trade-off is that hierarchical mode is **less globally optimized** than flat Verilation. It may reduce simulation performance, and it inherits Verilator's hierarchy-boundary restrictions. Use it when build scalability matters more than getting the most aggressive whole-design scheduling.

This rule discovers hierarchy automatically from `verilog_library(top_module = ...)` declarations. A library with a non-empty `top_module` becomes a hierarchy boundary. A library without `top_module` stays transparent and is compiled into the nearest ancestor boundary.

```starlark
load("@rules_verilator//verilator:defs.bzl", "verilator_cc_library")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")

verilog_library(
    name = "block_a_sv",
    srcs = ["block_a.sv"],
    top_module = "block_a",
)

verilog_library(
    name = "block_b_sv",
    srcs = ["block_b.sv"],
    top_module = "block_b",
)

verilog_library(
    name = "top_local_sv",
    srcs = ["top.sv"],
)

verilog_library(
    name = "full_design_sv",
    deps = [
        ":block_a_sv",
        ":block_b_sv",
        ":top_local_sv",
    ],
    top_module = "top",
)

verilator_cc_library(
    name = "top_verilated",
    module = ":full_design_sv",
    hierarchical = True, # Enable hierarchical verilation
)
```

How the top is chosen:

- `module_top` on `verilator_cc_library`, if set, overrides everything else.
- Otherwise the rule uses `module[VerilogInfo].top_module`.
- If neither is set, analysis fails.

How child libraries are treated:

- `top_module != ""`: the child becomes its own hierarchical node.
- `top_module == ""`: the child stays transparent and is merged into the nearest ancestor node.
- The root target is always represented by the resolved top of the current `verilator_cc_library`, even if that top came from `module_top` override.

Important behavior:

- Hierarchy recognition only looks at the current `module` graph. Other `verilator_cc_library` targets do not affect it.
- `hierarchical = True` changes the compile strategy for this target only. The same `verilog_library` graph can still be consumed by a separate flat `verilator_cc_library`.
- Rebuilds happen at hierarchy-node granularity: if one child node changes, unchanged sibling nodes can still be reused from cache, while the changed node and its ancestor chain are rebuilt.
- Use the dedicated `timing` attribute instead of passing `--timing` or `--no-timing` through `vopts`.
- `systemc = True` is supported only for flat Verilation today.
- The rule auto-generates the temporary `.vlt` control file. Users do not need to maintain it manually.

## Key Differences from rules_hdl

> [!TIP]
> This was a fork of the Verilator rules from [hdl/bazel_rules_hdl](https://github.com/hdl/bazel_rules_hdl)

- **No bundled Verilator**: Requires users to declare BCR Verilator dependency explicitly
- **Optional SystemC**: SystemC is not bundled; users add it only when needed
- **Bzlmod only**: Designed for MODULE.bazel, not legacy WORKSPACE
- **Focused scope**: Only Verilator rules, no synthesis/PnR tools
- **More feature**: Newer version of Verilator, supporting incremental hierarchical builds

## Requirements

- Bazel >=7.6.0, >=8.1.0, 9
- Verilator >= 5.046.bcr.3 from BCR
- SystemC 3.0.2 from BCR (optional, for SystemC output)

## License

Apache License 2.0 (inherited from bazel_rules_hdl)
