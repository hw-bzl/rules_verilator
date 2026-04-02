#include <verilated.h>
#include <verilated_vcd_c.h>

#include <memory>

#include "Vnested_module_2.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS
double sc_time_stamp() { return 0; }

namespace {

class NestedModuleTraceTest : public testing::Test {
 protected:
  void SetUp() override { Verilated::traceEverOn(true); }

  void Clock(Vnested_module_2* dut) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
};

TEST_F(NestedModuleTraceTest, trace_nested_pipeline) {
  auto dut = std::make_unique<Vnested_module_2>();

  auto trace = std::make_unique<VerilatedVcdC>();
  dut->trace(trace.get(), 99);
  trace->open("nested_module_trace.vcd");

  vluint64_t time_counter = 0;

  for (int i = 0; i < 11; i++) {
    dut->input_val = i % 8;
    dut->clk = 0;
    dut->eval();
    trace->dump(time_counter++);
    dut->clk = 1;
    dut->eval();
    trace->dump(time_counter++);
    if (i > 2) {
      EXPECT_EQ(dut->output_val, (~(i - 2)) & 0x7);
    }
  }

  trace->close();
  dut->final();
}

}  // namespace
