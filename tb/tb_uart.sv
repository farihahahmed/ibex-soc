// ============================================================================
// tb_uart.sv - testbench for my UART transmitter
//
// I write a known byte, then watch the tx line and decode the frame myself:
//   - line should idle high
//   - drop low for the start bit
//   - then 8 data bits, LSB first, matching my byte
//   - then back high for the stop bit
//
// I use a TINY baud divider (via parameters) so each bit is only a few clocks
// and the sim runs fast. I sample each bit in the MIDDLE of its bit-time.
// ============================================================================

`timescale 1ns/1ps

module tb_uart;

    // tiny, sim-friendly baud: 1 bit-time = 8 clock cycles.
    localparam int CLK_FREQ  = 8;
    localparam int BAUD_RATE = 1;          // BAUD_DIV = 8/1 = 8 clocks per bit.
    localparam int BIT_CLKS  = CLK_FREQ / BAUD_RATE;   // = 8.

    logic        clk, rst_n;
    logic        sel, we;
    logic [31:0] wdata, rdata;
    logic        tx;

    uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst_n(rst_n),
        .sel(sel), .we(we), .wdata(wdata), .rdata(rdata),
        .tx(tx)
    );

    initial clk = 0;
    always #5 clk = ~clk;                  // 10ns period.

    initial begin
        $dumpfile("tb_uart.vcd");
        $dumpvars(0, tb_uart);
    end

    integer errors;
    logic [7:0] test_byte;
    logic [7:0] received;
    integer i;

    initial begin
        sel = 0; we = 0; wdata = 0;
        errors = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        // line should idle high
        #1;
        if (tx !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: tx not idle-high before sending");
        end

        // ---- write a byte to send: 0x41 = 'A' = 0100_0001 ----
        test_byte = 8'h41;
        $display("TEST: send byte 0x%02h", test_byte);
        @(negedge clk);
        sel = 1; we = 1; wdata = {24'b0, test_byte};
        @(negedge clk);
        sel = 0; we = 0;

        // ---- now decode the frame off the tx line ----
        // wait for the start bit (tx goes low)
        wait (tx == 1'b0);
        // we're at the start of the start bit. Move to its middle.
        repeat (BIT_CLKS/2) @(posedge clk);
        #1;
        if (tx !== 1'b0) begin
            errors = errors + 1;
            $display("  FAIL: start bit not low");
        end

        // sample 8 data bits, LSB first. Advance one full bit-time each.
        received = 8'h0;
        for (i = 0; i < 8; i = i + 1) begin
            repeat (BIT_CLKS) @(posedge clk);   // move to middle of next bit.
            #1;
            received[i] = tx;                   // LSB first, so bit i.
        end

        // sample the stop bit (should be high)
        repeat (BIT_CLKS) @(posedge clk);
        #1;
        if (tx !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: stop bit not high");
        end

        // ---- check the received byte matches ----
        if (received !== test_byte) begin
            errors = errors + 1;
            $display("  FAIL: received 0x%02h, expected 0x%02h", received, test_byte);
        end else begin
            $display("  OK: received 0x%02h correctly", received);
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
