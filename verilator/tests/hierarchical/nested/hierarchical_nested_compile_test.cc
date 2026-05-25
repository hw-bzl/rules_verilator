#include <verilated.h>

#include <memory>

#include "Vhier_nested_top.h"
#include "gtest/gtest.h"

double sc_time_stamp() { return 0; }

namespace {

TEST(HierarchicalNestedCompileTest, EvaluatesAcrossNestedBlocks) {
  std::unique_ptr<Vhier_nested_top> dut = std::make_unique<Vhier_nested_top>();

  dut->x = 4;
  dut->eval();
  EXPECT_EQ(dut->y, (4 + 2) + (4 ^ 0x3));

  dut->x = 9;
  dut->eval();
  EXPECT_EQ(dut->y, (9 + 2) + (9 ^ 0x3));
}

}  // namespace
