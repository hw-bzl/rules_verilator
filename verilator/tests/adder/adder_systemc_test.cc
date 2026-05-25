#include <systemc.h>
#include <verilated.h>
#include <verilated_vcd_sc.h>

#include <memory>

#include "Vadder.h"
#include "gtest/gtest.h"

namespace {

class AdderSystemCTest : public testing::Test {
 protected:
  void SetUp() override {
    sc_set_time_resolution(1, SC_NS);
  }
};

TEST_F(AdderSystemCTest, one_plus_two) {
  std::unique_ptr<Vadder> v_adder = std::make_unique<Vadder>("adder");

  // Set inputs
  v_adder->x = 1;
  v_adder->y = 2;

  // Evaluate
  v_adder->eval();

  // Check output
  EXPECT_EQ(v_adder->sum, 3);
}

TEST_F(AdderSystemCTest, five_plus_seven) {
  std::unique_ptr<Vadder> v_adder = std::make_unique<Vadder>("adder");

  v_adder->x = 5;
  v_adder->y = 7;
  v_adder->eval();

  EXPECT_EQ(v_adder->sum, 12);
}

}  // namespace
