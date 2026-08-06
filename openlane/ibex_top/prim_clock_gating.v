module prim_clock_gating #(
  parameter bit NoFpgaGate = 1'b0,
  parameter bit FpgaBufGlobal = 1'b1
) (
  input  clk_i,
  input  en_i,
  input  test_en_i,
  output clk_o
);
  // Bring-up model: core clock always enabled (no low-power gating).
  assign clk_o = clk_i;
endmodule
