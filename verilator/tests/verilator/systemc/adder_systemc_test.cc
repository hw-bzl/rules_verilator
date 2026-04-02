#include <systemc.h>
#include <verilated.h>
#include <verilated_vcd_sc.h>

#include "Vadder.h"
#include "gtest/gtest.h"

double sc_time_stamp() { return sc_core::sc_time_stamp().to_double(); }

namespace {

TEST(AdderSystemCTest, addition) {
  Vadder v_adder{"adder"};

  sc_signal<uint32_t> sig_x, sig_y, sig_sum;
  sc_signal<bool> sig_carry_in, sig_carry_output_bit;
  v_adder.x(sig_x);
  v_adder.y(sig_y);
  v_adder.carry_in(sig_carry_in);
  v_adder.carry_output_bit(sig_carry_output_bit);
  v_adder.sum(sig_sum);

  sig_x.write(1);
  sig_y.write(2);
  sig_carry_in.write(false);
  sc_start(1, SC_NS);
  EXPECT_EQ(sig_sum.read(), 3u);

  sig_x.write(5);
  sig_y.write(7);
  sc_start(1, SC_NS);
  EXPECT_EQ(sig_sum.read(), 12u);
}

}  // namespace

int sc_main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
