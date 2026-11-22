load("@rules_cc//cc:cc_test.bzl", "cc_test")

package(
    default_applicable_licenses = ["//:package_license"],
    default_visibility = ["//visibility:private"],
)

cc_test(
    name = "copy_tree_test",
    srcs = ["copy_tree_test.cc"],
    args = ["$(rlocationpath //verilator/private:verilator_copy_tree)"],
    data = [
        "//verilator/private:verilator_copy_tree",
    ] + glob(["testdata/**"]),
    deps = [
        "@googletest//:gtest",
        "@rules_cc//cc/runfiles",
    ],
)
