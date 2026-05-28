load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "include_leaf_sv",
    srcs = ["include_leaf.sv"],
    hdrs = ["include_defs/include_leaf_defs.svh"],
)

verilog_library(
    name = "include_top_sv",
    srcs = ["include_top.sv"],
    top_module = "include_top",
    deps = [":include_leaf_sv"],
)

verilator_cc_library(
    name = "include_top_verilator",
    module = ":include_top_sv",
)

cc_test(
    name = "include_top_test",
    srcs = ["include_top_test.cc"],
    deps = [
        ":include_top_verilator",
        "@googletest//:gtest_main",
    ],
)
