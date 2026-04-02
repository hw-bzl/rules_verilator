#include <verilated.h>

#include <memory>

#include "Vnested_module_0.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS.
double sc_time_stamp() { return 0; }

namespace {

class Module0Test : public testing::Test {
 protected:
  void Clock(Vnested_module_0* dut) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
};

TEST_F(Module0Test, XorWithOne) {
  auto dut = std::make_unique<Vnested_module_0>();

  for (int i = 0; i < 8; i++) {
    dut->input_val = i;
    Clock(dut.get());
    EXPECT_EQ(dut->output_val, i ^ 1);
  }
}

}  // namespace
