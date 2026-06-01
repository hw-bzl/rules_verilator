"""Rule definition for the Verilator toolchain."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc:defs.bzl", "CcInfo")
load(":common.bzl", "reject_managed_vopts")

def _verilator_toolchain_impl(ctx):
    all_files = ctx.attr.verilator[DefaultInfo].default_runfiles.files
    reject_managed_vopts(ctx.attr.lint_vopts, "verilator_toolchain.lint_vopts")

    return [platform_common.ToolchainInfo(
        verilator = ctx.executable.verilator,
        systemc = ctx.attr.systemc,
        deps = ctx.attr.deps,
        extra_vopts = ctx.attr.extra_vopts,
        lint_vopts = ctx.attr.lint_vopts,
        all_files = all_files,
        _avoid_nondeterministic_outputs = ctx.attr.avoid_nondeterministic_outputs[BuildSettingInfo].value,
    )]

verilator_toolchain = rule(
    doc = "Define a Verilator toolchain.",
    implementation = _verilator_toolchain_impl,
    attrs = {
        "avoid_nondeterministic_outputs": attr.label(
            default = Label("//verilator/settings:avoid_nondeterministic_outputs"),
        ),
        "deps": attr.label_list(
            doc = "Additional common dependencies to link into downstream targets.",
            providers = [CcInfo],
        ),
        "extra_vopts": attr.string_list(
            doc = "Extra flags to pass to Verilator compile actions.",
        ),
        "lint_vopts": attr.string_list(
            doc = "Default flags passed to `verilator --lint-only` by `verilator_lint_aspect` " +
                  "and by `verilator_lint_test` when its target is a bare `verilog_library`.",
            default = ["-Wall"],
        ),
        "systemc": attr.label(
            doc = "SystemC dependency to link into downstream targets.",
            providers = [CcInfo],
            mandatory = False,
        ),
        "verilator": attr.label(
            doc = "The Verilator binary.",
            executable = True,
            cfg = "exec",
            mandatory = True,
        ),
    },
)
