"""Rule definition for the Verilator toolchain."""

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_cc//cc:defs.bzl", "CcInfo")

def _verilator_toolchain_impl(ctx):
    all_files = ctx.attr.verilator[DefaultInfo].default_runfiles.files

    return [platform_common.ToolchainInfo(
        verilator = ctx.executable.verilator,
        systemc = ctx.attr.systemc,
        deps = ctx.attr.deps,
        extra_vopts = ctx.attr.extra_vopts,
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
            doc = "Global Verilator dependencies to link into downstream targets.",
            providers = [CcInfo],
        ),
        "extra_vopts": attr.string_list(
            doc = "Extra flags to pass to Verilator compile actions.",
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
