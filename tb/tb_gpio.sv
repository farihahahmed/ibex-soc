// ============================================================================
// tb_gpio.sv - my testbench for the GPIO peripheral
//
// What I'm checking:
//   1. Write -> output pins follow what I wrote.
//   2. Reset -> output pins go low.
//   3. Drive the input pins -> after the 2-flop synchronizer delay, the CPU
//      reads them back correctly.
//   4. A write only happens when I'm selected AND writing (sel && we).
// ============================================================================

`timescale 1ns/1ps

module tb_gpio;

    localparam int NUM_IO = 8;

    logic              clk, rst_n;
    logic              sel, we;
    logic [31:0]       wdata, rdata;
    logic [NUM_IO-1:0] gpio_out, gpio_in;

    gpio #(.NUM_IO(NUM_IO)) dut (
        .clk(clk), .rst_n(rst_n),
        .sel(sel), .we(we), .wdata(wdata), .rdata(rdata),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_gpio.vcd");
        $dumpvars(0, tb_gpio);
    end

    integer errors;

    // write to the GPIO output register
    task gpio_write(input [31:0] val);
        begin
            @(negedge clk);
            sel = 1; we = 1; wdata = val;
            @(posedge clk);       // write lands here
            @(negedge clk);
            sel = 0; we = 0;
        end
    endtask

    initial begin
        sel = 0; we = 0; wdata = 0; gpio_in = 0;
        errors = 0;
        rst_n = 0;
        repeat (2) @(posedge clk);
        @(negedge clk); rst_n = 1;
        @(posedge clk);

        // ---- TEST 1: reset cleared the outputs ----
        $display("TEST 1: outputs low after reset");
        #1;
        if (gpio_out !== 8'h00) begin
            errors = errors + 1;
            $display("  FAIL: outputs not zero after reset (got 0x%02h)", gpio_out);
        end

        // ---- TEST 2: write drives the output pins ----
        $display("TEST 2: write sets output pins");
        gpio_write(32'h0000_00A5);   // 0xA5 = 10100101
        #1;
        if (gpio_out !== 8'hA5) begin
            errors = errors + 1;
            $display("  FAIL: gpio_out expected 0xA5, got 0x%02h", gpio_out);
        end

        gpio_write(32'h0000_00FF);   // all pins high
        #1;
        if (gpio_out !== 8'hFF) begin
            errors = errors + 1;
            $display("  FAIL: gpio_out expected 0xFF, got 0x%02h", gpio_out);
        end

        // ---- TEST 3: input pins read back through the synchronizer ----
        $display("TEST 3: drive inputs, read them back (after 2-flop delay)");
        @(negedge clk);
        gpio_in = 8'h3C;             // drive some input pins: 00111100
        // wait for the 2-flop synchronizer to pass the value through
        repeat (3) @(posedge clk);
        // now read: sel=1, we=0
        @(negedge clk);
        sel = 1; we = 0;
        @(posedge clk); #1;
        if (rdata[7:0] !== 8'h3C) begin
            errors = errors + 1;
            $display("  FAIL: read inputs expected 0x3C, got 0x%02h", rdata[7:0]);
        end
        @(negedge clk); sel = 0;

        // ---- TEST 4: no write when not selected ----
        $display("TEST 4: no write when sel=0");
        // outputs currently 0xFF from test 2. Try to write with sel=0 -> should NOT change.
        @(negedge clk);
        sel = 0; we = 1; wdata = 32'h0000_0000;
        @(posedge clk);
        @(negedge clk); we = 0;
        #1;
        if (gpio_out !== 8'hFF) begin
            errors = errors + 1;
            $display("  FAIL: output changed while not selected (got 0x%02h)", gpio_out);
        end

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED  (0 errors)");
        else
            $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
