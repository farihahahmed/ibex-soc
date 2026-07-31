`timescale 1ns/1ps
module tb_clk_gen;
    logic ref_clk, clk_ext, rst_n, clk_int, cfg_load;
    logic [7:0] cfg_div_in;
    logic clk_out;

    clk_gen dut(.ref_clk(ref_clk), .clk_ext(clk_ext), .rst_n(rst_n),
        .clk_int(clk_int), .cfg_load(cfg_load), .cfg_div_in(cfg_div_in),
        .clk_out(clk_out));

    initial ref_clk=0; always #5 ref_clk=~ref_clk;
    initial clk_ext=0; always #35 clk_ext=~clk_ext;

    integer out_edges, errors;
    always @(posedge clk_out) out_edges = out_edges + 1;

    task set_div(input [7:0] d);
        begin @(negedge ref_clk); cfg_div_in=d; cfg_load=1; @(negedge ref_clk); cfg_load=0; end
    endtask

    initial begin
        errors=0; out_edges=0; clk_int=1; cfg_load=0; cfg_div_in=0;
        rst_n=0; repeat(4) @(negedge ref_clk); rst_n=1; @(negedge ref_clk);

        set_div(8'd0);
        out_edges=0; repeat(40) @(negedge ref_clk);
        $display("div=0: %0d out rising edges over 40 ref cycles", out_edges);
        if (out_edges<18 || out_edges>22) begin $display("BAD div0"); errors=errors+1; end
        else $display("OK div=0 (fast divide)");

        set_div(8'd3);
        out_edges=0; repeat(40) @(negedge ref_clk);
        $display("div=3: %0d out rising edges over 40 ref cycles", out_edges);
        if (out_edges<4 || out_edges>6) begin $display("BAD div3"); errors=errors+1; end
        else $display("OK div=3 (slower divide)");

        clk_int=0; @(negedge ref_clk);
        out_edges=0; repeat(40) @(negedge ref_clk);
        $display("ext: %0d out rising edges (ext clock)", out_edges);
        if (out_edges<4 || out_edges>7) begin $display("BAD ext"); errors=errors+1; end
        else $display("OK external clock passthrough");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - clock generator works!");
        else           $display("FAILED (%0d errors)", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
