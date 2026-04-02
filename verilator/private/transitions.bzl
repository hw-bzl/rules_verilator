"""Transitions for propagating verilator_cc_library settings to aspects."""

TRACE = str(Label("//verilator/private:_trace"))
SYSTEMC = str(Label("//verilator/private:_systemc"))

def _verilator_settings_transition_impl(_settings, attr):
    return {
        TRACE: attr.trace,
        SYSTEMC: attr.systemc,
    }

verilator_settings_transition = transition(
    implementation = _verilator_settings_transition_impl,
    inputs = [],
    outputs = [
        TRACE,
        SYSTEMC,
    ],
)
