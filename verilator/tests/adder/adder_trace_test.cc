#include <verilated.h>
#include <verilated_vcd_c.h>

#include <memory>

#include "Vadder.h"
#include "gtest/gtest.h"

// Required by Verilator on macOS
double sc_time_stamp() { return 0; }

namespace {

class AdderTraceTest : public testing::Test {
 protected:
  void SetUp() override {
    Verilated::traceEverOn(true);
  }
};

TEST_F(AdderTraceTest, trace_functionality) {
  std::unique_ptr<Vadder> v_adder = std::make_unique<Vadder>();

  // Open trace file
  auto trace = std::make_unique<VerilatedVcdC>();
  v_adder->trace(trace.get(), 99);
  trace->open("adder_trace.vcd");

  vluint64_t time_counter = 0;

  // Test 1: Simple addition - 1 + 2 = 3
  v_adder->x = 1;
  v_adder->y = 2;
  v_adder->carry_in = 0;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 3);
  EXPECT_EQ(v_adder->carry_output_bit, 0);

  // Test 2: Overflow with carry - 255 + 1 = 256 (sum=0, carry=1)
  v_adder->x = 255;
  v_adder->y = 1;
  v_adder->carry_in = 0;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 0);
  EXPECT_EQ(v_adder->carry_output_bit, 1);

  // Test 3: Addition with carry_in - 100 + 100 + 1 = 201
  v_adder->x = 100;
  v_adder->y = 100;
  v_adder->carry_in = 1;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 201);
  EXPECT_EQ(v_adder->carry_output_bit, 0);

  // Test 4: Both operands max - 128 + 128 = 256 (sum=0, carry=1)
  v_adder->x = 128;
  v_adder->y = 128;
  v_adder->carry_in = 0;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 0);
  EXPECT_EQ(v_adder->carry_output_bit, 1);

  // Test 5: No carry - 0 + 0 + 0 = 0
  v_adder->x = 0;
  v_adder->y = 0;
  v_adder->carry_in = 0;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 0);
  EXPECT_EQ(v_adder->carry_output_bit, 0);

  // Test 6: Only carry_in - 0 + 0 + 1 = 1
  v_adder->x = 0;
  v_adder->y = 0;
  v_adder->carry_in = 1;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 1);
  EXPECT_EQ(v_adder->carry_output_bit, 0);

  // Test 7: Carry out from carry_in - 255 + 0 + 1 = 0 (carry=1)
  v_adder->x = 255;
  v_adder->y = 0;
  v_adder->carry_in = 1;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 0);
  EXPECT_EQ(v_adder->carry_output_bit, 1);

  // Test 8: Maximum values - 255 + 255 + 1 = 511 (sum=255, carry=1)
  v_adder->x = 255;
  v_adder->y = 255;
  v_adder->carry_in = 1;
  v_adder->eval();
  trace->dump(time_counter++);
  EXPECT_EQ(v_adder->sum, 255);
  EXPECT_EQ(v_adder->carry_output_bit, 1);

  // Properly cleanup
  trace->close();
  v_adder->final();
}

}  // namespace
