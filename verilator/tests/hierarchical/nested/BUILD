load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "hier_nested_leaf_sv",
    srcs = ["hier_nested_leaf.sv"],
    top_module = "hier_nested_leaf",
)

verilog_library(
    name = "hier_nested_mid_helpers_sv",
    srcs = ["hier_nested_mid_helpers.sv"],
)

verilog_library(
    name = "hier_nested_mid_sv",
    srcs = ["hier_nested_mid.sv"],
    top_module = "hier_nested_mid",
    deps = [
        ":hier_nested_leaf_sv",
        ":hier_nested_mid_helpers_sv",
    ],
)

verilog_library(
    name = "hier_nested_top_local_sv",
    srcs = ["hier_nested_top.sv"],
)

verilog_library(
    name = "hier_nested_design_sv",
    top_module = "hier_nested_top",
    deps = [
        ":hier_nested_mid_sv",
        ":hier_nested_top_local_sv",
    ],
)

verilator_cc_library(
    name = "hier_nested_top_verilator",
    hierarchical = True,
    module = ":hier_nested_design_sv",
)

cc_test(
    name = "hierarchical_nested_compile_test",
    srcs = ["hierarchical_nested_compile_test.cc"],
    deps = [
        ":hier_nested_top_verilator",
        "@googletest//:gtest_main",
    ],
)
