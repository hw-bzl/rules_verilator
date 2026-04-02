# rules_verilator

[![BCR](https://img.shields.io/badge/BCR-rules_verilator-green?logo=bazel)](https://registry.bazel.build/modules/rules_verilator)
[![CI](https://github.com/MrAMS/bazel_rules_verilator/actions/workflows/ci.yml/badge.svg)](https://github.com/MrAMS/bazel_rules_verilator/actions/workflows/ci.yml)

Bazel rules for Verilator-based SystemVerilog simulation using the Bazel Central Registry (BCR) Verilator toolchain.

## Features

- Uses BCR Verilator for better reproducibility and version management
- Supports both C++ and SystemC output
- Dual-mode compilation: flat (single invocation) and hierarchical (per-module)
- Optional waveform tracing support via per-target `trace` attribute
- Compatible with Bazel 7.5.0+

## Installation

```starlark
bazel_dep(name = "rules_verilator", version = "0.3.1")

bazel_dep(name = "rules_verilog", version = "1.1.1")
bazel_dep(name = "verilator", version = "5.044")
bazel_dep(name = "systemc", version = "3.0.2")
```

> [!TIP]
> Verilator and SystemC are not bundled with `rules_verilator`. Users must explicitly declare them in their own `MODULE.bazel`. SystemC is **optional** and only required if you set `systemc = True` in your `verilator_cc_library` targets.
>
> `rules_verilator` `0.3.0+` requires the refactored `rules_verilog` provider interface (`rules_verilog >= 1.1.1`).

## Usage

You can check `verilator/tests` for examples as well.

### Flat Compilation (Default)

A single Verilator invocation processes the top module and all transitive sources. Best for simulation performance.

```starlark
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("@rules_verilator//verilator:defs.bzl", "verilator_cc_library")

verilog_library(
    name = "adder",
    srcs = ["adder.sv"],
    top_module = "adder",
)

verilator_cc_library(
    name = "adder_v",
    module = ":adder",
)

cc_test(
    name = "adder_test",
    srcs = ["adder_test.cc"],
    deps = [":adder_v"],
)
```

The top module name is inferred from `VerilogInfo.top_module`.Override with `module_top`:

```starlark
verilator_cc_library(
    name = "nested_v",
    module = ":nested_modules",
    module_top = "nested_2",
)
```

### Hierarchical Compilation

Each `verilog_library` in the dependency tree is compiled independently via an aspect that propagates through `deps`. Best for incremental build performance on large designs.

```starlark
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("@rules_verilator//verilator:defs.bzl", "verilator_cc_library")

verilog_library(
    name = "block_a",
    srcs = ["block_a.sv"],
)

verilog_library(
    name = "block_b",
    srcs = ["block_b.sv"],
)

verilog_library(
    name = "top",
    srcs = ["top.sv"],
    deps = [":block_a", ":block_b"],
    top_module = "top",
)

verilator_cc_library(
    name = "top_v",
    module = ":top",
    hierarchical = True,
)

cc_test(
    name = "top_test",
    srcs = ["top_test.cc"],
    deps = [":top_v"],
)
```

No manual plan/block/top wiring needed -- the Bazel dependency graph is the hierarchy.

### Trace and SystemC

`trace` and `systemc` are per-target attributes propagated via private build settings and configuration transitions:

```starlark
verilator_cc_library(
    name = "adder_trace_v",
    module = ":adder",
    trace = True,
)

verilator_cc_library(
    name = "adder_sc_v",
    module = ":adder",
    systemc = True,
)
```

## API Reference

### `verilator_cc_library`

| Attribute | Type | Default | Description |
|---|---|---|---|
| `module` | `label` | mandatory | A `verilog_library` target providing `VerilogInfo`. |
| `module_top` | `string` | `""` | Override for the top module name. Inferred from `VerilogInfo.top` if empty. |
| `hierarchical` | `bool` | `False` | Use hierarchical compilation (per-module aspects). |
| `trace` | `bool` | `False` | Enable Verilator tracing (`--trace`, `-DVM_TRACE`). |
| `systemc` | `bool` | `False` | Generate SystemC output (`--sc`). Requires SystemC toolchain. |
| `copts` | `string_list` | `[]` | Additional C++ compilation flags. |
| `vopts` | `string_list` | `["-Wall"]` | Additional Verilator command line options. |
| `data` | `label_list` | `[]` | Data files needed at runtime. |
| `linkopts` | `string_list` | `[]` | Additional linker options. |

## Key Differences from rules_hdl

> [!TIP]
> This was a fork of the Verilator rules from [hdl/bazel_rules_hdl](https://github.com/hdl/bazel_rules_hdl)

- **No bundled Verilator**: Requires users to declare BCR Verilator dependency explicitly
- **Optional SystemC**: SystemC is not bundled; users add it only when needed
- **Bzlmod only**: Designed for MODULE.bazel, not legacy WORKSPACE
- **Focused scope**: Only Verilator rules, no synthesis/PnR tools
- **Dual-mode compilation**: Single `verilator_cc_library` rule supports both flat and hierarchical modes

## Requirements

- Bazel 7.5.0 or later
- Verilator 5.036+ from BCR
- SystemC 3.0.2 from BCR (optional, for SystemC output)

## License

Apache License 2.0 (inherited from bazel_rules_hdl)
