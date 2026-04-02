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
#
# Original implementation by Kevin Kiningham (@kkiningh) in kkiningh/rules_verilator.
# Ported to bazel_rules_hdl by Stephen Tridgell (@stridge-cruxml)

"""Public entrypoints for Verilator rules."""

load(
    "//verilator/private:toolchain.bzl",
    _verilator_toolchain = "verilator_toolchain",
)
load(
    "//verilator/private:verilator_cc_library.bzl",
    _verilator_cc_library = "verilator_cc_library",
)

verilator_cc_library = _verilator_cc_library
verilator_toolchain = _verilator_toolchain
