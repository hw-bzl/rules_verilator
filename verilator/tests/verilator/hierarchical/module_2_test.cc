#include <verilated.h>

#include <memory>

#include "Vnested_module_2.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS.
double sc_time_stamp() { return 0; }

namespace {

class Module2Test : public testing::Test {
 protected:
  void Clock(Vnested_module_2* dut) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
};

TEST_F(Module2Test, ThreeStagePipeline) {
  auto dut = std::make_unique<Vnested_module_2>();

  // 3-stage pipeline: module_2 XORs with 4, module_1 XORs with 2,
  // module_0 XORs with 1. Total: input ^ 7 = ~input (3-bit) after 3 cycles.
  for (int i = 0; i < 11; i++) {
    dut->input_val = i % 8;
    Clock(dut.get());
    if (i > 2) {
      EXPECT_EQ(dut->output_val, (~(i - 2)) & 0x7);
    }
  }
}

}  // namespace
