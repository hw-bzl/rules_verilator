#include <systemc.h>
#include <verilated.h>
#include <verilated_vcd_sc.h>

#include "Vnested_module_2.h"
#include "gtest/gtest.h"

double sc_time_stamp() { return sc_core::sc_time_stamp().to_double(); }

namespace {

TEST(NestedModuleSystemCTest, pipeline_computes_bitwise_not) {
  Vnested_module_2 dut{"nested_module_2"};

  sc_signal<bool> sig_clk;
  sc_signal<uint32_t> sig_input_val, sig_output_val;
  dut.clk(sig_clk);
  dut.input_val(sig_input_val);
  dut.output_val(sig_output_val);

  for (int i = 0; i < 11; i++) {
    sig_input_val.write(i % 8);
    sig_clk.write(false);
    sc_start(1, SC_NS);
    sig_clk.write(true);
    sc_start(1, SC_NS);
    if (i > 2) {
      EXPECT_EQ(sig_output_val.read(), static_cast<uint32_t>((~(i - 2)) & 0x7));
    }
  }
}

}  // namespace

int sc_main(int argc, char* argv[]) {
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
