// clk_gen.sv - synthesizable clock generator (divider) + external-clock fallback.
// clk_int selects source: 1 = internal divided clock, 0 = external clk_ext.
// Internal clock = ref_clk divided by 2*(div+1).
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

    // Glitch-free 2:1 clock mux. A bare combinational select can emit a runt
    // pulse; instead each branch has a 2-flop synchronizer on the NEGATIVE edge
    // of its own clock (so its enable changes only while that clock is low), and
    // each is blocked while the other is still enabled. At most one gated clock
    // is ever active, so the OR is safe. Both clocks must run for a switch.
    logic int_en_q1, int_en_q2, ext_en_q1, ext_en_q2;

    always_ff @(negedge div_clk or negedge rst_n) begin
        if (!rst_n) begin int_en_q1 <= 1'b0; int_en_q2 <= 1'b0; end
        else begin
            int_en_q1 <= clk_int & ~ext_en_q2;
            int_en_q2 <= int_en_q1;
        end
    end

    always_ff @(negedge clk_ext or negedge rst_n) begin
        if (!rst_n) begin ext_en_q1 <= 1'b0; ext_en_q2 <= 1'b0; end
        else begin
            ext_en_q1 <= ~clk_int & ~int_en_q2;
            ext_en_q2 <= ext_en_q1;
        end
    end

    assign clk_out = (div_clk & int_en_q2) | (clk_ext & ext_en_q2);
endmodule
