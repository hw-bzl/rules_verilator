/**
 * @file verilator_copy_file.cc
 * @brief A tool for copying a single file out of a generated tree artifact.
 */

#include <fstream>
#include <iostream>
#include <string>

int main(int argc, char* argv[]) {
    if (argc < 3) {
        std::cerr << "Usage: " << argv[0] << " <src> [<fallback_src> ...] <dst>" << std::endl;
        return 1;
    }

    const std::string dst = argv[argc - 1];

    std::ifstream src_stream;
    std::string chosen_src;
    for (int i = 1; i < argc - 1; ++i) {
        src_stream = std::ifstream(argv[i], std::ios::binary);
        if (src_stream) {
            chosen_src = argv[i];
            break;
        }
    }

    if (!src_stream) {
        std::cerr << "Error opening source file candidates:";
        for (int i = 1; i < argc - 1; ++i) {
            std::cerr << ' ' << argv[i];
        }
        std::cerr << std::endl;
        return 1;
    }

    std::ofstream dst_stream(dst, std::ios::binary);
    if (!dst_stream) {
        std::cerr << "Error opening destination file: " << dst << std::endl;
        return 1;
    }

    dst_stream << src_stream.rdbuf();
    if (!dst_stream.good()) {
        std::cerr << "Error writing destination file: " << dst << std::endl;
        return 1;
    }

    return 0;
}
