#include <verilated.h>

#include <memory>

#include "Vnested_module_1.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS.
double sc_time_stamp() { return 0; }

namespace {

class Module1Test : public testing::Test {
 protected:
  void Clock(Vnested_module_1* dut) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
};

TEST_F(Module1Test, TwoStagePipeline) {
  auto dut = std::make_unique<Vnested_module_1>();

  // 2-stage pipeline: module_1 XORs with 2 (registered),
  // then module_0 XORs with 1 (registered). Total: input ^ 3 after 2 cycles.
  for (int i = 0; i < 10; i++) {
    dut->input_val = i % 8;
    Clock(dut.get());
    if (i > 0) {
      EXPECT_EQ(dut->output_val, ((i - 1) % 8) ^ 3);
    }
  }
}

}  // namespace
