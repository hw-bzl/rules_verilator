#include <verilated.h>

#include "Vtiming_tb.h"
#include "gtest/gtest.h"

TEST(TimingTbTest, compiles_and_runs_timing_model) {
  VerilatedContext context;
  Vtiming_tb dut{&context};

  while (!context.gotFinish()) {
    dut.eval();
    context.timeInc(1);
  }

  EXPECT_GE(context.time(), 20);
}
