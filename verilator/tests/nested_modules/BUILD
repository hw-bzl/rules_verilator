load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "nested_modules",
    srcs = [
        "nested_module_0.sv",
        "nested_module_1.sv",
        "nested_module_2.sv",
    ],
)

verilator_cc_library(
    name = "nested_module_verilator",
    module = ":nested_modules",
    module_top = "nested_module_2",
)

cc_test(
    name = "nested_module_test",
    srcs = ["nested_module_test.cc"],
    deps = [
        ":nested_module_verilator",
        "@googletest//:gtest_main",
    ],
)
