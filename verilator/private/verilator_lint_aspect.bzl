"""Aspect that runs `verilator --lint-only` on targets providing `VerilogInfo`."""

load("@rules_verilog//verilog:defs.bzl", "VerilogInfo")
load(
    ":common.bzl",
    "collect_verilog_inputs",
    "only_sv",
    "verilator_env",
)

_SKIP_TAGS = ("no-lint", "no-verilator-lint")

def _has_skip_tag(ctx):
    if not hasattr(ctx.rule.attr, "tags"):
        return False
    for tag in ctx.rule.attr.tags:
        if tag.replace("_", "-") in _SKIP_TAGS:
            return True
    return False

def _verilator_lint_aspect_impl(target, ctx):
    if VerilogInfo not in target:
        return []
    if _has_skip_tag(ctx):
        return []
    top = target[VerilogInfo].top_module
    if not top:
        # A verilog_library without a top_module declaration cannot be linted in
        # isolation. Skip silently so the aspect can safely fan out across //...
        return []

    toolchain = ctx.toolchains["//verilator:toolchain_type"]
    inputs = collect_verilog_inputs(target)

    marker = ctx.actions.declare_file(target.label.name + ".verilator_lint")
    args = ctx.actions.args()
    args.add("--marker", marker)
    args.add(toolchain.verilator)
    args.add("--no-std")
    args.add("--lint-only")
    args.add("--top-module", top)
    args.add_all(inputs.includes, format_each = "-I%s")
    args.add_all(inputs.verilog_files, expand_directories = True, map_each = only_sv)
    args.add_all(toolchain.lint_vopts)

    ctx.actions.run(
        executable = ctx.executable._lint_wrapper,
        arguments = [args],
        outputs = [marker],
        inputs = inputs.verilog_files,
        tools = toolchain.all_files,
        mnemonic = "VerilatorLint",
        progress_message = "[Verilator] Linting {}".format(target.label),
        env = verilator_env(toolchain),
    )
    return [OutputGroupInfo(verilator_lint_checks = depset([marker]))]

verilator_lint_aspect = aspect(
    implementation = _verilator_lint_aspect_impl,
    required_providers = [VerilogInfo],
    attrs = {
        "_lint_wrapper": attr.label(
            cfg = "exec",
            executable = True,
            default = Label("//verilator/private:verilator_lint_wrapper"),
        ),
    },
    toolchains = ["//verilator:toolchain_type"],
)
