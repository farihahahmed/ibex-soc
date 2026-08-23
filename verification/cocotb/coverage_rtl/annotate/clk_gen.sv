//      // verilator_coverage annotation
        // clk_gen.sv - synthesizable clock generator (divider) + external-clock fallback.
        // clk_int selects source: 1 = internal divided clock, 0 = external clk_ext.
        // Internal clock = ref_clk divided by 2*(div+1).
        module clk_gen (
 117488     input  logic        ref_clk,
 117488     input  logic        clk_ext,
 000039     input  logic        rst_n,
%000000     input  logic        clk_int,
 000038     input  logic        cfg_load,
 001019     input  logic [7:0]  cfg_div_in,
 117488     output logic        clk_out
        );
%000000     logic [7:0] div;
%000000     logic [7:0] cnt;
 058493     logic       div_clk;
        
 117526     always_ff @(posedge ref_clk or negedge rst_n) begin
 117018         if (!rst_n) begin
 000508             div     <= 8'd0;
 000508             cnt     <= 8'd0;
 000508             div_clk <= 1'b0;
 000038         end else if (cfg_load) begin
 000038             div <= cfg_div_in;
 000038             cnt <= 8'd0;
~116980         end else if (cnt == div) begin
 116980             cnt     <= 8'd0;
 116980             div_clk <= ~div_clk;
%000000         end else begin
%000000             cnt <= cnt + 8'd1;
                end
            end
        
~352503     assign clk_out = clk_int ? div_clk : clk_ext;
        endmodule
        
