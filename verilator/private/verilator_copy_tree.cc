/**
 * @file verilator_copy_tree.cc
 * @brief A tool for copying generated verilator outputs into unique source and header directories.
 */

#include <sys/stat.h>

#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iostream>
#include <map>
#include <set>
#include <string>
#include <vector>

#ifdef _WIN32
#include <direct.h>
#define mkdir(dir, mode) _mkdir(dir)
#else
#include <unistd.h>
#endif

void create_directory(const std::string& path) {
    if (mkdir(path.c_str(), 0700) != 0 && errno != EEXIST) {
        std::cerr << "Error creating directory: " << path << std::endl;
        std::exit(1);
    }
}

void copy_file(const std::string& src, const std::string& dest) {
    std::ifstream src_stream(src, std::ios::binary);
    std::ofstream dest_stream(dest, std::ios::binary);
    if (!src_stream || !dest_stream) {
        std::cerr << "Error copying " << src << " to " << dest << std::endl;
        return;
    }
    dest_stream << src_stream.rdbuf();
}

std::string file_name(const std::string& path) {
    return path.substr(path.find_last_of("/\\") + 1);
}

bool has_suffix(const std::string& s, const std::string& suffix) {
    return s.size() >= suffix.size() &&
           s.compare(s.size() - suffix.size(), suffix.size(), suffix) == 0;
}

// What Verilator's `<prefix>_classes.mk` tells `verilated.mk` to compile.
struct ClassesMk {
    bool parallel_builds = false;
    // In `verilated.mk`'s order: VM_FAST, then VM_SLOW.
    std::vector<std::string> classes = {};
};

[[noreturn]] void classes_mk_error(const std::string& path,
                                   const std::string& message) {
    std::cerr << path << ": " << message << std::endl;
    std::exit(1);
}

const std::string kParallelBuilds = "VM_PARALLEL_BUILDS";
const std::vector<std::string> kClassLists = {
    "VM_CLASSES_FAST", "VM_SUPPORT_FAST", "VM_CLASSES_SLOW", "VM_SUPPORT_SLOW"};
// Verilator declares each of these, an empty class list included.
const std::vector<std::string> kDeclared = [] {
    std::vector<std::string> result = {kParallelBuilds};
    result.insert(result.end(), kClassLists.begin(), kClassLists.end());
    return result;
}();
// Every variable Verilator writes into classes.mk, from the oldest supported
// release on. Any other name, such as one of `verilated.mk`'s own, could change
// what make builds.
const std::set<std::string> kWritten = [] {
    std::set<std::string> result(kDeclared.begin(), kDeclared.end());
    result.insert({"VM_C11", "VM_TIMING", "VM_COVERAGE", "VM_TRACE",
                   "VM_TRACE_FST", "VM_TRACE_SAIF", "VM_TRACE_VCD", "VM_VPI",
                   "VM_GLOBAL_FAST", "VM_GLOBAL_SLOW"});
    return result;
}();

// ASCII only, whatever the locale.
bool is_name_char(char c) {
    return (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
           (c >= '0' && c <= '9') || c == '_';
}

// A printable non-space character that make reads literally in a value.
bool is_value_char(char c) {
    return c > ' ' && c < 0x7f && c != '$' && c != '#';
}

struct ClassesMkReader {
    std::string path = {};
    ClassesMk result = {};
    std::vector<std::vector<std::string>> lists =
        std::vector<std::vector<std::string>>(kClassLists.size());
    std::set<std::string> declared = {};
    std::set<std::string> classes = {};
};

// Accepts only the line shapes Verilator writes: a blank line, a comment,
// `NAME = VALUE` and `NAME += CLASS...` for a NAME in `kWritten`. Anything
// else could be read by make unlike here, so it fails, as does a class listed
// twice.
void read_classes_mk_line(const std::string& line, ClassesMkReader* reader) {
    if (line.empty() || line[0] == '#') {
        return;
    }
    const std::string unsupported = "not in the form Verilator writes: " + line;
    const size_t space = line.find(' ');
    const std::string name = line.substr(0, space);
    if (space == std::string::npos || name.empty() ||
        !std::all_of(name.begin(), name.end(), is_name_char)) {
        classes_mk_error(reader->path, unsupported);
    }
    if (kWritten.count(name) == 0) {
        classes_mk_error(reader->path,
                         name + " is not a variable Verilator writes: " + line);
    }
    const auto list = std::find(kClassLists.begin(), kClassLists.end(), name);
    const std::string assign = " = ";
    if (line.compare(space, assign.size(), assign) == 0) {
        const std::string value = line.substr(space + assign.size());
        // `=` would replace a class list rather than append to it.
        if (value.empty() || list != kClassLists.end() ||
            !std::all_of(value.begin(), value.end(), is_value_char)) {
            classes_mk_error(reader->path, unsupported);
        }
        if (name == kParallelBuilds) {
            // `verilated.mk` tests `ifneq ($(VM_PARALLEL_BUILDS),1)`.
            reader->result.parallel_builds = value == "1";
            reader->declared.insert(name);
        }
        return;
    }
    const std::string append = " +=";
    const size_t entries = space + append.size();
    if (line.compare(space, append.size(), append) != 0 ||
        (entries < line.size() && line[entries] != ' ') ||
        name == kParallelBuilds) {
        classes_mk_error(reader->path, unsupported);
    }
    size_t pos = entries;
    while ((pos = line.find_first_not_of(' ', pos)) != std::string::npos) {
        const size_t end = std::min(line.find(' ', pos), line.size());
        const std::string c = line.substr(pos, end - pos);
        pos = end;
        if (!std::all_of(c.begin(), c.end(), is_name_char)) {
            classes_mk_error(reader->path, unsupported);
        }
        if (list == kClassLists.end()) {
            continue;
        }
        if (!reader->classes.insert(c).second) {
            classes_mk_error(reader->path,
                             "lists " + c + " more than once: " + line);
        }
        reader->lists[list - kClassLists.begin()].push_back(c);
    }
    if (list != kClassLists.end()) {
        reader->declared.insert(name);
    }
}

ClassesMk parse_classes_mk(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    if (!in) {
        classes_mk_error(path, "cannot read");
    }
    ClassesMkReader reader = {};
    reader.path = path;
    std::string logical = {};
    for (std::string line; std::getline(in, line);) {
        // make reads a CRLF line as if it ended in LF.
        if (!line.empty() && line.back() == '\r') {
            line.pop_back();
        }
        if (!line.empty() && line.back() == '\\') {
            line.pop_back();
            logical += line + " ";
            continue;
        }
        read_classes_mk_line(logical + line, &reader);
        logical.clear();
    }
    if (!logical.empty()) {
        classes_mk_error(path, "ends in a continuation line");
    }
    std::string missing = {};
    for (const std::string& var : kDeclared) {
        if (reader.declared.count(var) == 0) {
            missing += " " + var;
        }
    }
    if (!missing.empty()) {
        classes_mk_error(path, "does not declare" + missing);
    }
    for (const std::vector<std::string>& list : reader.lists) {
        reader.result.classes.insert(reader.result.classes.end(), list.begin(),
                                     list.end());
    }
    return reader.result;
}

// The `.cpp` files a source includes, as an `--output-groups` group file does.
std::set<std::string> included_cpps(const std::string& path) {
    std::ifstream in(path);
    std::set<std::string> result = {};
    const std::string directive = "#include \"";
    for (std::string line; std::getline(in, line);) {
        if (line.compare(0, directive.size(), directive) != 0) {
            continue;
        }
        const size_t end = line.find('"', directive.size());
        const std::string target =
            line.substr(directive.size(), end - directive.size());
        if (end != std::string::npos && has_suffix(target, ".cpp")) {
            result.insert(file_name(target));
        }
    }
    return result;
}

int main(int argc, char* argv[]) {
    if (argc < 5) {
        std::cerr << "Usage: " << argv[0]
                  << " --src_output=<src_dir> --hdr_output=<hdr_dir> --src="
                     "<file1> ... --hdr=<file2> ... [--classes=<classes.mk>]"
                  << std::endl;
        return 1;
    }

    std::string src_output = {};
    std::string hdr_output = {};
    std::vector<std::string> srcs = {};
    std::vector<std::string> hdrs = {};
    std::vector<std::string> classes_mks = {};

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        size_t pos = arg.find('=');
        if (pos != std::string::npos) {
            std::string key = arg.substr(0, pos);
            std::string value = arg.substr(pos + 1);
            if (key == "--src_output") {
                src_output = value;
            } else if (key == "--hdr_output") {
                hdr_output = value;
            } else if (key == "--src") {
                srcs.push_back(value);
            } else if (key == "--hdr") {
                hdrs.push_back(value);
            } else if (key == "--classes") {
                classes_mks.push_back(value);
            } else {
                std::cerr << "Unexpected argument: " << arg << std::endl;
                return 1;
            }
        } else {
            std::cerr << "Unexpected argument: " << arg << std::endl;
            return 1;
        }
    }

    if (src_output.empty() || hdr_output.empty()) {
        std::cerr << "Both --src_output and --hdr_output must be specified."
                  << std::endl;
        return 1;
    }

    create_directory(src_output);
    create_directory(hdr_output);

    if (classes_mks.size() > 1) {
        std::cerr << "Expected at most one --classes, got "
                  << classes_mks.size() << std::endl;
        return 1;
    }

    // Without a classes.mk (e.g. `--make json`), every source is compiled.
    // With one, a listed source is compiled unless it goes into __ALL.cpp; an
    // unlisted one (e.g. `--lib-create`'s) unless a listed source includes it.
    std::set<std::string> listed = {};
    std::set<std::string> included = {};
    bool unity = false;
    ClassesMk plan = {};
    if (!classes_mks.empty()) {
        plan = parse_classes_mk(classes_mks[0]);
        unity = !plan.parallel_builds;
        std::map<std::string, std::string> path_of = {};
        for (const std::string& file : srcs) {
            path_of[file_name(file)] = file;
        }
        for (const std::string& c : plan.classes) {
            const auto it = path_of.find(c + ".cpp");
            if (it == path_of.end()) {
                std::cerr << classes_mks[0] << " lists " << c
                          << " but there is no " << c << ".cpp" << std::endl;
                return 1;
            }
            listed.insert(it->first);
            const std::set<std::string> inc = included_cpps(it->second);
            included.insert(inc.begin(), inc.end());
        }
    }

    for (const std::string& file : srcs) {
        const std::string name = file_name(file);
        bool to_src = true;
        if (!classes_mks.empty() && has_suffix(name, ".cpp")) {
            to_src =
                listed.count(name) != 0 ? !unity : included.count(name) == 0;
        }
        copy_file(file, (to_src ? src_output : hdr_output) + "/" + name);
    }

    for (const std::string& file : hdrs) {
        copy_file(file, hdr_output + "/" + file_name(file));
    }

    if (unity) {
        const std::string mk = file_name(classes_mks[0]);
        const std::string prefix =
            mk.substr(0, mk.size() - std::strlen("_classes.mk"));
        const std::string all = src_output + "/" + prefix + "__ALL.cpp";
        std::ofstream out(all, std::ios::binary);
        // Byte-identical to `make <prefix>__ALL.cpp` (`verilator_includer`).
        out << "// DESCRIPTION: Generated by verilator_includer via makefile\n"
            << "#define VL_INCLUDE_OPT include\n";
        for (const std::string& c : plan.classes) {
            out << "#include \"" << c << ".cpp\"\n";
        }
        if (!out) {
            std::cerr << "Error writing " << all << std::endl;
            return 1;
        }
    }

    return 0;
}
