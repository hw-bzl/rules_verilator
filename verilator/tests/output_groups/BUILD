load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "output_groups",
    srcs = ["output_groups.sv"],
    top_module = "output_groups",
)

verilator_cc_library(
    name = "output_groups_verilator",
    module = ":output_groups",
    vopts = [
        "--output-split",
        "20",
        "--output-groups",
        "2",
    ],
)

cc_test(
    name = "output_groups_test",
    srcs = ["output_groups_test.cc"],
    deps = [
        ":output_groups_verilator",
        "@googletest//:gtest_main",
    ],
)
