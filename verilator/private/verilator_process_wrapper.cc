/**
 * @file verilator_process_wrapper.cc
 * @brief A process wrapper for the `VerilatorCompile` Bazel action.
 *
 * Wrapper flags (before `--`):
 *   --output_srcs=<dir>  Destination for generated C++ source files.
 *   --output_hdrs=<dir>  Destination for generated C++ header files.
 *
 * Everything after `--` is the verilator command line.  The wrapper
 * extracts `--Mdir <dir>` from the verilator args to know where
 * generated files land, then post-processes that directory to split
 * sources and headers into the declared output directories.
 */

#include <cstdlib>
#include <filesystem>
#include <iostream>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static bool ends_with_any(const std::string& name,
                          const std::vector<std::string>& suffixes) {
    for (const auto& s : suffixes) {
        if (name.size() >= s.size() &&
            name.compare(name.size() - s.size(), s.size(), s) == 0) {
            return true;
        }
    }
    return false;
}

static bool starts_with(const std::string& str, const std::string& prefix) {
    return str.size() >= prefix.size() &&
           str.compare(0, prefix.size(), prefix) == 0;
}

static int split_outputs(const std::string& mdir,
                         const std::string& output_srcs,
                         const std::string& output_hdrs) {
    if (mdir.empty() || (output_srcs.empty() && output_hdrs.empty())) {
        return 0;
    }

    fs::path dir_path(mdir);
    if (!fs::exists(dir_path) || !fs::is_directory(dir_path)) {
        std::cerr << "Error: --Mdir does not exist: " << mdir << std::endl;
        return 1;
    }

    if (!output_srcs.empty()) fs::create_directories(output_srcs);
    if (!output_hdrs.empty()) fs::create_directories(output_hdrs);

    const std::vector<std::string> src_ext = {".cc", ".cpp", ".c"};
    const std::vector<std::string> hdr_ext = {".h", ".hpp", ".hh"};

    for (const auto& entry : fs::directory_iterator(dir_path)) {
        if (!entry.is_regular_file()) continue;
        std::string name = entry.path().filename().string();

        if (!output_srcs.empty() && ends_with_any(name, src_ext)) {
            std::error_code ec;
            fs::copy_file(entry.path(), fs::path(output_srcs) / name,
                          fs::copy_options::overwrite_existing, ec);
            if (ec) {
                std::cerr << "Error: copy " << entry.path() << " -> "
                          << output_srcs << ": " << ec.message() << std::endl;
                return 1;
            }
        } else if (!output_hdrs.empty() && ends_with_any(name, hdr_ext)) {
            std::error_code ec;
            fs::copy_file(entry.path(), fs::path(output_hdrs) / name,
                          fs::copy_options::overwrite_existing, ec);
            if (ec) {
                std::cerr << "Error: copy " << entry.path() << " -> "
                          << output_hdrs << ": " << ec.message() << std::endl;
                return 1;
            }
        }
    }

    // Verify non-empty when requested.
    auto has_files = [](const std::string& dir) {
        for (const auto& e : fs::directory_iterator(dir)) {
            if (e.is_regular_file()) return true;
        }
        return false;
    };
    if (!output_srcs.empty() && !has_files(output_srcs)) {
        std::cerr << "Error: output_srcs is empty: " << output_srcs
                  << std::endl;
        return 1;
    }
    if (!output_hdrs.empty() && !has_files(output_hdrs)) {
        std::cerr << "Error: output_hdrs is empty: " << output_hdrs
                  << std::endl;
        return 1;
    }
    return 0;
}

int main(int argc, char* argv[]) {
    std::string output_srcs;
    std::string output_hdrs;
    std::vector<std::string> verilator_args;
    std::string mdir;

    bool after_delim = false;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];

        if (arg == "--") {
            after_delim = true;
            continue;
        }

        if (after_delim) {
            verilator_args.push_back(arg);
            if (arg == "--Mdir" && i + 1 < argc) {
                mdir = argv[i + 1];
            }
        } else if (starts_with(arg, "--output_srcs=")) {
            output_srcs = arg.substr(14);
        } else if (starts_with(arg, "--output_hdrs=")) {
            output_hdrs = arg.substr(14);
        } else {
            std::cerr << "Error: unknown wrapper flag: " << arg << std::endl;
            return 1;
        }
    }

    if (verilator_args.empty()) {
        std::cerr << "Error: no verilator command after '--'" << std::endl;
        return 1;
    }

    // Build and execute verilator command.
    std::string cmd;
    for (const auto& part : verilator_args) {
        cmd += part + " ";
    }
    int result = std::system(cmd.c_str());
    if (result != 0) {
        return 1;
    }

    // Split generated outputs into source and header directories.
    if (int rc = split_outputs(mdir, output_srcs, output_hdrs); rc != 0) {
        return rc;
    }

    return 0;
}
