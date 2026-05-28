#include <verilated.h>
#include <verilated_fst_c.h>

#include <memory>

#include "Vadder.h"
#include "gtest/gtest.h"

double sc_time_stamp() { return 0; }

namespace {

TEST(AdderFstTest, trace_functionality) {
  Verilated::traceEverOn(true);

  std::unique_ptr<Vadder> v_adder = std::make_unique<Vadder>();
  auto trace = std::make_unique<VerilatedFstC>();
  v_adder->trace(trace.get(), 99);
  trace->open("adder_trace.fst");

  v_adder->x = 21;
  v_adder->y = 21;
  v_adder->carry_in = 0;
  v_adder->eval();
  trace->dump(0);

  EXPECT_EQ(v_adder->sum, 42);
  EXPECT_EQ(v_adder->carry_output_bit, 0);

  trace->close();
  v_adder->final();
}

}  // namespace
