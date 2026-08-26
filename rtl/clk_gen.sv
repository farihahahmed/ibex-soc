// clk_gen.sv - clock generator (divider) + external-clock fallback.
// clk_int selects source: 1 = internal divided clock, 0 = external clk_ext.
// Internal clock = ref_clk divided by 2*(div+1).
//
// GLITCH-FREE SOURCE MUX (ICG-based)
// A bare combinational select can emit a runt pulse if clk_int changes while
// either clock is high. Instead each branch is gated by the PDK's integrated
// clock-gating cell icgtp_1 (clock_gating_integrated_cell:
// "latch_posedge_precontrol"): its internal latch is transparent while CLK is
// low and holds E steady through the high phase, so Q = CLK & E can never be a
// partial pulse. The two enables are cross-blocked, so at most one branch is
// active and the OR is safe; a switch stops the old clock before starting the
// new one.
//
// An earlier version used negedge flops clocked from div_clk. That is correct
// in RTL but makes a flop output a clock source, which crashes OpenROAD CTS.
// The ICG is a characterised clock gate the tools handle natively.
module clk_gen (
    input  logic        ref_clk,
    input  logic        clk_ext,
    input  logic        rst_n,
    input  logic        clk_int,
    input  logic        cfg_load,
    input  logic [7:0]  cfg_div_in,
    output logic        clk_out
);
    logic [7:0] div;
    logic [7:0] cnt;
    logic       div_clk;

    always_ff @(posedge ref_clk or negedge rst_n) begin
        if (!rst_n) begin
            div     <= 8'd0;
            cnt     <= 8'd0;
            div_clk <= 1'b0;
        end else if (cfg_load) begin
            div <= cfg_div_in;
            cnt <= 8'd0;
        end else if (cnt == div) begin
            cnt     <= 8'd0;
            div_clk <= ~div_clk;
        end else begin
            cnt <= cnt + 8'd1;
        end
    end

    // Enable requests, registered on ref_clk (a real input clock - nothing is
    // ever clocked from div_clk). Cross-blocked so both can never be high.
    logic int_req, ext_req;

    always_ff @(posedge ref_clk or negedge rst_n) begin
        if (!rst_n) begin
            int_req <= 1'b0;
            ext_req <= 1'b0;
        end else begin
            int_req <=  clk_int & ~ext_req;
            ext_req <= ~clk_int & ~int_req;
        end
    end

    logic int_gated, ext_gated;

    gf180mcu_fd_sc_mcu7t5v0__icgtp_1 u_icg_int (
        .CLK (div_clk), .E (int_req), .TE (1'b0), .Q (int_gated)
    );

    gf180mcu_fd_sc_mcu7t5v0__icgtp_1 u_icg_ext (
        .CLK (clk_ext), .E (ext_req), .TE (1'b0), .Q (ext_gated)
    );

    assign clk_out = int_gated | ext_gated;
endmodule
