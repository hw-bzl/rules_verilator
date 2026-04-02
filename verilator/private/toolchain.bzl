"""Rule definition for the Verilator toolchain."""

load("@rules_cc//cc:defs.bzl", "CcInfo")

def _verilator_toolchain_impl(ctx):
    all_files = ctx.attr.verilator[DefaultInfo].default_runfiles.files

    return [platform_common.ToolchainInfo(
        label = ctx.label,
        verilator = ctx.executable.verilator,
        libverilator = ctx.attr.libverilator,
        systemc = ctx.attr.systemc,
        deps = ctx.attr.deps,
        copts = ctx.attr.copts,
        linkopts = ctx.attr.linkopts,
        vopts = ctx.attr.vopts,
        all_files = all_files,
    )]

verilator_toolchain = rule(
    doc = "Define a Verilator toolchain.",
    implementation = _verilator_toolchain_impl,
    attrs = {
        "copts": attr.string_list(
            doc = "Flags to pass to the compile actions of Verilated code.",
        ),
        "deps": attr.label_list(
            doc = "Global Verilator dependencies to link into downstream targets.",
            providers = [CcInfo],
        ),
        "libverilator": attr.label(
            doc = "The Verilator C++ runtime library.",
            providers = [CcInfo],
            mandatory = True,
        ),
        "linkopts": attr.string_list(
            doc = "Flags to pass to the link actions of Verilated code.",
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
        "vopts": attr.string_list(
            doc = "Flags to pass to Verilator compile actions in addition to internal flags defined by rules.",
            default = ["-Wall"],
        ),
    },
)
