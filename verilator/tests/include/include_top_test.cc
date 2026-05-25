#include <verilated.h>

#include <memory>

#include "Vinclude_top.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS
double sc_time_stamp() { return 0; }

namespace {

TEST(IncludeTopTest, include_from_dep_library_is_visible) {
  std::unique_ptr<Vinclude_top> dut = std::make_unique<Vinclude_top>();
  dut->in_val = 7;
  dut->eval();
  EXPECT_EQ(dut->out_val, 12);
}

}  // namespace
