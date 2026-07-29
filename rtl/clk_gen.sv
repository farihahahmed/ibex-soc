// ============================================================================
// clk_gen.sv - on-chip clock generator (ring oscillator).
//
// *** IMPORTANT: this file is a BEHAVIORAL SIMULATION MODEL, not the real
//     synthesizable circuit. ***
//
// A real ring oscillator is an ANALOG structure: an odd number of inverter cells
// wired in a loop. Because an odd number of inversions can never settle, the
// signal oscillates on its own, and the frequency is set by the gate propagation
// delays (period ~= 2 x total inverter delay). That behavior:
//   - is NOT expressible in normal zero-delay RTL (a bare inverter loop is an
//     illegal combinational loop),
//   - depends on #delays that synthesis IGNORES (so it won't synthesize into a
//     real oscillator),
//   - is characterized with SPICE at the transistor level, not functional sim.
//
// So for RTL simulation I use this behavioral model: a clock that simply toggles
// with a #delay, giving my testbenches an on-chip clock source. It is a STAND-IN.
//
// The REAL structural version (to build during physical design) looks like:
//     wire n0, n1, n2;
//     gf180mcu_fd_sc_mcu7t5v0__inv_1 u0 (.ZN(n0), .I(clk_int & enable));
//     gf180mcu_fd_sc_mcu7t5v0__inv_1 u1 (.ZN(n1), .I(n0));
//     gf180mcu_fd_sc_mcu7t5v0__inv_1 u2 (.ZN(n2), .I(n1));
//     ... (odd count) ... last stage feeds back to the first, tap clk from a node.
//   with an enable/NAND gate in the loop to start/stop it, and the frequency
//   tuned by the number of stages. That version is verified by SPICE, then
//   dropped in as a hard block.
//
// Parameters:
//   HALF_PERIOD : sim half-period in time units (period = 2 x HALF_PERIOD).
// ============================================================================

module clk_gen #(
    parameter realtime HALF_PERIOD = 5.0    // 5 time units high, 5 low -> period 10.
)(
    input  logic enable,     // 1 = oscillate, 0 = hold clock low (gate it off).
    output logic clk_out     // the generated clock.
);

    // ---- BEHAVIORAL sim model: toggle with a delay while enabled ----
    // (synthesis will not turn this into a real oscillator - see header.)
    logic clk_reg;
    initial clk_reg = 1'b0;

    always begin
        if (enable) begin
            #(HALF_PERIOD) clk_reg = ~clk_reg;
        end else begin
            // when disabled, park low and wait a bit before re-checking.
            clk_reg = 1'b0;
            #(HALF_PERIOD);
        end
    end

    assign clk_out = clk_reg & enable;

endmodule
