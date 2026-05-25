#include <verilated.h>

#include <memory>

#include "Vhier_top.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS.
double sc_time_stamp() { return 0; }

namespace {

TEST(HierarchicalCompileTest, EvaluatesAcrossBlocks) {
  std::unique_ptr<Vhier_top> dut = std::make_unique<Vhier_top>();

  dut->x = 3;
  dut->eval();
  EXPECT_EQ(dut->passthrough, 4);
  EXPECT_EQ(dut->sum, 4 + (3 ^ 0xf));

  dut->x = 10;
  dut->eval();
  EXPECT_EQ(dut->passthrough, 11);
  EXPECT_EQ(dut->sum, 11 + (10 ^ 0xf));
}

}  // namespace
