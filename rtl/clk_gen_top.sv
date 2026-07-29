// ============================================================================
// clk_gen_top.sv - v0.7: demonstrate the on-chip clock generator driving logic.
//
// clk_gen (my behavioral ring-oscillator model) produces a clock. Here I use that
// generated clock to drive a small counter - a stand-in for "downstream logic."
// If the counter advances, the generated clock is really clocking real flops.
//
// This is the honest, verifiable claim for a BEHAVIORAL clock source: it works as
// a clock. (The real ring oscillator's *frequency* is a SPICE/physical result; on
// silicon this generated clock would feed the whole SoC's clock tree.)
//
// clk_en gates the oscillator (start/stop the chip clock).
// ============================================================================

module clk_gen_top (
    input  logic       clk_en,        // enable the on-chip clock generator.
    input  logic       rst_n,         // reset for the downstream logic.
    output logic       gen_clk,       // the generated clock (exposed for observation).
    output logic [7:0] counter        // downstream logic clocked by gen_clk.
);

    // on-chip clock source (behavioral model).
    clk_gen #(.HALF_PERIOD(5.0)) u_clkgen (
        .enable  (clk_en),
        .clk_out (gen_clk)
    );

    // downstream logic: a counter clocked by the GENERATED clock.
    always_ff @(posedge gen_clk or negedge rst_n) begin
        if (!rst_n) counter <= 8'h00;
        else        counter <= counter + 8'h1;
    end

endmodule
