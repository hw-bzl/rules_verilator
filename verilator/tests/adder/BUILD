load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_verilog//verilog:defs.bzl", "verilog_library")
load("//verilator:defs.bzl", "verilator_cc_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "adder",
    srcs = ["adder.sv"],
    top_module = "adder",
)

verilator_cc_library(
    name = "adder_verilator",
    module = ":adder",
)

verilator_cc_library(
    name = "adder_systemc_verilator",
    module = ":adder",
    systemc = True,
    tags = ["manual"],
)

verilator_cc_library(
    name = "adder_trace_verilator",
    module = ":adder",
    trace = True,
)

cc_test(
    name = "adder_test",
    srcs = ["adder_test.cc"],
    deps = [
        ":adder_verilator",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "adder_systemc_test",
    srcs = ["adder_systemc_test.cc"],
    tags = ["manual"],
    deps = [
        ":adder_systemc_verilator",
        "@googletest//:gtest_main",
    ],
)

cc_test(
    name = "adder_trace_test",
    srcs = ["adder_trace_test.cc"],
    deps = [
        ":adder_trace_verilator",
        "@googletest//:gtest_main",
    ],
)
