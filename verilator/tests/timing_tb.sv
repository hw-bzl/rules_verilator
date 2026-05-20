module timing_tb;
  logic clk;

  initial begin
    clk = 0;
  end

  always #5 clk = ~clk;

  initial begin
    #20 $finish;
  end
endmodule
