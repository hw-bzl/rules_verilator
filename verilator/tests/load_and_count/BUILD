load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "load_and_count",
    srcs = ["load_and_count.sv"],
    data = ["test_data.dat"],
    top_module = "load_and_count",
)

verilator_cc_library(
    name = "load_and_count_verilator",
    module = ":load_and_count",
)

cc_test(
    name = "load_and_count_test",
    srcs = ["load_and_count_test.cc"],
    data = ["test_data.dat"],
    deps = [
        ":load_and_count_verilator",
        "@googletest//:gtest_main",
    ],
)
