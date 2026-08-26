// Behavioural model of gf180mcu_fd_sc_mcu7t5v0__icgtp_1.
// Integrated clock gate, clock_gating_integrated_cell:
//   "latch_posedge_precontrol", state_function : "(CLK&IQ2)"
//
// A low-phase-transparent latch captures E|TE while CLK is low and holds it
// through the high phase, so Q = CLK & latched_enable can never emit a partial
// pulse regardless of when E changes.
`timescale 1ns/1ps
module gf180mcu_fd_sc_mcu7t5v0__icgtp_1 (
    input  CLK,
    input  E,
    input  TE,
    output Q
);
    reg iq2;
    always @(*) if (!CLK) iq2 <= (E | TE);   // transparent while CLK low
    assign Q = CLK & iq2;
endmodule
