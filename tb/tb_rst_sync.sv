// ============================================================================
// tb_rst_sync.sv - my testbench for the reset synchronizer
//
// I'm not checking data here, I'm checking TIMING behavior:
//   1. When I drop rst_n_in low, the output must go low right away (async assert).
//   2. When I release rst_n_in high, the output must come back high a couple
//      cycles later, cleanly lined up with the clock (sync de-assert).
// I print the signals every cycle so I can watch the two-flop delay happen.
// ============================================================================

`timescale 1ns/1ps

module tb_rst_sync;

    logic clk;
    logic rst_n_in;
    logic rst_n_out;

    // the thing I'm testing.
    rst_sync dut (
        .clk(clk),
        .rst_n_in(rst_n_in),
        .rst_n_out(rst_n_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;            // 10ns clock period.

    initial begin
        $dumpfile("tb_rst_sync.vcd");
        $dumpvars(0, tb_rst_sync);
    end

    integer errors;

    // print the signals just after each rising edge, so I can see the delay.
    always @(posedge clk) begin
        #1;
        $display("t=%0t  rst_n_in=%b  rst_n_out=%b", $time, rst_n_in, rst_n_out);
    end

    initial begin
        errors = 0;

        // ---- start asserted (in reset) ----
        rst_n_in = 0;                // hold reset low.
        repeat (3) @(posedge clk);
        #1;
        // check 1: while held in reset, output must be low.
        if (rst_n_out !== 1'b0) begin
            errors = errors + 1;
            $display("  FAIL: output not low while reset asserted");
        end

        // ---- release reset ----
        @(negedge clk);
        rst_n_in = 1;                // release reset (on the falling edge, a clean moment).
        $display("---- released rst_n_in high ----");

        // the output should NOT jump high instantly - it takes 2 flops = 2 cycles.
        @(posedge clk); #1;
        // after 1 cycle, flop1=1 but flop2 (the output) may still be 0. That's expected.

        @(posedge clk); #1;
        // after 2 cycles the output should be high (clean, synchronized release).
        if (rst_n_out !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: output did not release high after 2 cycles");
        end

        // ---- assert reset again mid-run: output must drop immediately ----
        repeat (2) @(posedge clk);
        @(negedge clk);
        rst_n_in = 0;                // slam reset low again.
        #1;                          // check almost immediately (async assert).
        $display("---- asserted rst_n_in low again ----");
        if (rst_n_out !== 1'b0) begin
            errors = errors + 1;
            $display("  FAIL: output did not assert low immediately");
        end

        repeat (3) @(posedge clk);

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED  (0 errors)");
        else
            $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");

        $finish;
    end

endmodule
