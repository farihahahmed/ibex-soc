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

    assign clk_out = clk_int ? div_clk : clk_ext;
endmodule
