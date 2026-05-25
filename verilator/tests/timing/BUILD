load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "timing_tb_sv",
    srcs = ["timing_tb.sv"],
    top_module = "timing_tb",
)

verilator_cc_library(
    name = "timing_tb_verilator",
    module = ":timing_tb_sv",
    timing = True,
    vopts = [
        "-Wall",
    ],
)

verilator_cc_library(
    name = "timing_tb_main_verilator",
    module = ":timing_tb_sv",
    timing = True,
    vopts = [
        "-Wall",
        "--main",
    ],
)

cc_test(
    name = "timing_tb_test",
    srcs = ["timing_tb_test.cc"],
    deps = [
        ":timing_tb_verilator",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "timing_tb_main_test",
    srcs = ["timing_tb_main_test.cc"],
    deps = [":timing_tb_main_verilator"],
)
