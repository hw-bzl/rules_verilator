/**
 * @file verilator_lint_wrapper.cc
 * @brief Process wrapper for the `VerilatorLint` Bazel action.
 *
 * Usage: verilator_lint_wrapper --marker <path> <verilator> [verilator args...]
 *
 * Captures the Verilator invocation's stdout+stderr to the marker file. On
 * success (exit 0) the marker is truncated to zero bytes so the artifact is
 * deterministic and no output reaches the build log. On failure the captured
 * log is replayed to stderr and Verilator's exit code is propagated, so Bazel
 * surfaces the diagnostics that explain the failure and only the failure.
 */

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

int main(int argc, char* argv[]) {
    std::string marker_path{};
    std::vector<std::string> command{};

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--marker" && i + 1 < argc) {
            marker_path = argv[++i];
            continue;
        }
        command.push_back(arg);
    }

    if (marker_path.empty()) {
        std::cerr << "verilator_lint_wrapper: missing --marker <path>"
                  << std::endl;
        return 1;
    }
    if (command.empty()) {
        std::cerr << "verilator_lint_wrapper: no verilator command provided"
                  << std::endl;
        return 1;
    }

    // Redirect Verilator's stdout+stderr into the marker file. The unquoted
    // form keeps `std::system` portable across POSIX sh and Windows cmd.exe,
    // matching the project convention that Bazel-out paths contain no spaces
    // or shell metachars.
    std::string cmd{};
    for (const std::string& part : command) {
        cmd += part + " ";
    }
    cmd += "> " + marker_path + " 2>&1";

    int result = std::system(cmd.c_str());
    if (result != 0) {
        std::ifstream log(marker_path);
        if (log.is_open()) {
            std::cerr << log.rdbuf();
        } else {
            std::cerr << "verilator_lint_wrapper: failed to read captured log "
                      << marker_path << std::endl;
        }
        return result;
    }

    // Truncate so the marker is always zero-bytes on success.
    std::ofstream marker(marker_path, std::ios::trunc);
    if (!marker.is_open()) {
        std::cerr << "verilator_lint_wrapper: failed to write marker "
                  << marker_path << std::endl;
        return 1;
    }
    return 0;
}
