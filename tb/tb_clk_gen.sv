`timescale 1ns/1ps
module tb_clk_gen;
    logic enable;
    logic clk_out;

    clk_gen #(.HALF_PERIOD(5.0)) dut (.enable(enable), .clk_out(clk_out));

    integer edges;
    // count rising edges to confirm it's oscillating
    always @(posedge clk_out) edges = edges + 1;

    integer errors;
    initial begin
        errors = 0; edges = 0; enable = 0;
        // disabled: should NOT oscillate
        #100;
        if (edges != 0) begin errors=errors+1; $display("FAIL: oscillated while disabled (%0d edges)", edges); end
        else $display("OK: no clock while disabled");

        // enable: should oscillate
        enable = 1;
        #200;   // ~20 periods of 10ns
        if (edges < 5) begin errors=errors+1; $display("FAIL: not oscillating when enabled (%0d edges)", edges); end
        else $display("OK: oscillating when enabled (%0d rising edges)", edges);

        // disable again: edge count should stop climbing
        enable = 0;
        edges = 0;
        #100;
        if (edges != 0) begin errors=errors+1; $display("FAIL: still oscillating after disable (%0d edges)", edges); end
        else $display("OK: clock stopped when disabled");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED  (0 errors)");
        else           $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #10000; $display("TIMEOUT"); $finish; end
endmodule
