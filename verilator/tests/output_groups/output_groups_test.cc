#include <verilated.h>

#include <cstdint>
#include <memory>

#include "Voutput_groups.h"
#include "gtest/gtest.h"

// A class file is on the include path only if a group file includes it, or
// if the model is not split and __ALL.cpp includes every file, including
// support files, which are never grouped.
#if !__has_include("Voutput_groups___024root__0.cpp")
#error "Verilator did not group the fast class files"
#endif
#if !__has_include("Voutput_groups___024root__0__Slow.cpp")
#error "Verilator did not group the slow class files"
#endif
#if __has_include("Voutput_groups__Syms__Slow.cpp")
#error "model is no longer split"
#endif

// Required by Verilator on macOS
double sc_time_stamp() { return 0; }

namespace {

constexpr int kStages = 64;

uint32_t Stage(int k, uint32_t a) {
  return (a * static_cast<uint32_t>(k + 3)) ^
         ((a >> (k % 7)) + static_cast<uint32_t>(k));
}

TEST(OutputGroupsTest, MatchesReferencePipeline) {
  std::unique_ptr<Voutput_groups> dut = std::make_unique<Voutput_groups>();
  uint32_t regs[kStages] = {};
  for (uint32_t i = 0; i < 3 * kStages; ++i) {
    dut->a = i * 2654435761u;
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
    for (int k = kStages - 1; k >= 0; --k) {
      regs[k] = Stage(k, k == 0 ? i * 2654435761u : regs[k - 1]);
    }
    EXPECT_EQ(dut->y, regs[kStages - 1]) << "cycle " << i;
  }
}

}  // namespace
