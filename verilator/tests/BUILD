# Copyright 2023 bazel_rules_hdl Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("//verilator:defs.bzl", "verilator_cc_library", "verilator_hierarchical_block_cc_library", "verilator_hierarchical_plan", "verilator_hierarchical_top_cc_library")
load("//verilog:defs.bzl", "verilog_library")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

verilog_library(
    name = "adder",
    srcs = ["adder.sv"],
)

verilator_cc_library(
    name = "adder_verilator",
    module = ":adder",
    module_top = "adder",
)

verilator_cc_library(
    name = "adder_systemc_verilator",
    module = ":adder",
    module_top = "adder",
    systemc = True,
    tags = ["manual"],
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

verilog_library(
    name = "load_and_count",
    srcs = ["load_and_count.sv"],
    data = ["test_data.dat"],
)

verilator_cc_library(
    name = "load_and_count_verilator",
    module = ":load_and_count",
    module_top = "load_and_count",
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

# Trace functionality test
verilator_cc_library(
    name = "adder_trace_verilator",
    module = ":adder",
    module_top = "adder",
    trace = True,
)

cc_test(
    name = "adder_trace_test",
    srcs = ["adder_trace_test.cc"],
    deps = [
        ":adder_trace_verilator",
        "@googletest//:gtest_main",
    ],
)

verilog_library(
    name = "hier_block_a_sv",
    srcs = ["hier_block_a.sv"],
)

verilog_library(
    name = "hier_block_b_sv",
    srcs = ["hier_block_b.sv"],
)

verilog_library(
    name = "hier_top_local_sv",
    srcs = ["hier_top.sv"],
)

verilog_library(
    name = "hier_full_design_sv",
    deps = [
        ":hier_block_a_sv",
        ":hier_block_b_sv",
        ":hier_top_local_sv",
    ],
)

verilator_hierarchical_plan(
    name = "hierarchical_plan",
    blocks = [
        "hier_block_a",
        "hier_block_b",
    ],
    module = ":hier_full_design_sv",
    module_top = "hier_top",
)

verilator_hierarchical_block_cc_library(
    name = "hier_block_a_verilator",
    block = "hier_block_a",
    module = ":hier_block_a_sv",
    plan = ":hierarchical_plan",
)

verilator_hierarchical_block_cc_library(
    name = "hier_block_b_verilator",
    block = "hier_block_b",
    module = ":hier_block_b_sv",
    plan = ":hierarchical_plan",
)

verilator_hierarchical_top_cc_library(
    name = "hier_top_verilator",
    block_deps = [
        ":hier_block_a_verilator",
        ":hier_block_b_verilator",
    ],
    module = ":hier_top_local_sv",
    plan = ":hierarchical_plan",
)

cc_test(
    name = "hierarchical_compile_test",
    srcs = ["hierarchical_compile_test.cc"],
    deps = [
        ":hier_top_verilator",
        "@googletest//:gtest_main",
    ],
)
