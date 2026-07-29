`timescale 1ns/1ps
module tb_clk_gen_top;
    logic clk_en, rst_n;
    logic gen_clk;
    logic [7:0] counter;

    clk_gen_top dut (.clk_en(clk_en), .rst_n(rst_n), .gen_clk(gen_clk), .counter(counter));

    integer errors;
    logic [7:0] snap;
    initial begin
        errors=0; clk_en=0; rst_n=0;
        #20 rst_n=1;
        #50; snap = counter;
        #50;
        if (counter !== snap) begin errors=errors+1; $display("FAIL: counter moved with clock disabled"); end
        else $display("OK: counter idle while clock disabled (=%0d)", counter);

        clk_en=1;
        #200;
        if (counter == snap) begin errors=errors+1; $display("FAIL: counter did not advance with generated clock"); end
        else $display("OK: generated clock is clocking logic (counter=%0d)", counter);

        snap = counter;
        clk_en=0;
        #100;
        if (counter !== snap) begin errors=errors+1; $display("FAIL: counter advanced after clock disabled"); end
        else $display("OK: counter stopped when clock disabled (=%0d)", counter);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED  (0 errors)");
        else           $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #5000; $display("TIMEOUT"); $finish; end
endmodule
