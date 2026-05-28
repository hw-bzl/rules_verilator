load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "hier_block_a_sv",
    srcs = ["hier_block_a.sv"],
    top_module = "hier_block_a",
)

verilog_library(
    name = "hier_block_b_sv",
    srcs = ["hier_block_b.sv"],
    top_module = "hier_block_b",
)

verilog_library(
    name = "hier_top_local_sv",
    srcs = ["hier_top.sv"],
)

verilog_library(
    name = "hier_full_design_sv",
    top_module = "hier_top",
    deps = [
        ":hier_block_a_sv",
        ":hier_block_b_sv",
        ":hier_top_local_sv",
    ],
)

verilog_library(
    name = "hier_full_design_override_sv",
    deps = [
        ":hier_block_a_sv",
        ":hier_block_b_sv",
        ":hier_top_local_sv",
    ],
)

verilator_cc_library(
    name = "hier_top_verilator",
    hierarchical = True,
    module = ":hier_full_design_sv",
)

cc_test(
    name = "hierarchical_compile_test",
    srcs = ["hierarchical_compile_test.cc"],
    deps = [
        ":hier_top_verilator",
        "@googletest//:gtest_main",
    ],
)

verilator_cc_library(
    name = "hier_top_override_verilator",
    hierarchical = True,
    module = ":hier_full_design_override_sv",
    module_top = "hier_top",
)

cc_test(
    name = "hierarchical_override_compile_test",
    srcs = ["hierarchical_compile_test.cc"],
    deps = [
        ":hier_top_override_verilator",
        "@googletest//:gtest_main",
    ],
)
