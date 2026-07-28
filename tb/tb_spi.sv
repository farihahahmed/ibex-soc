// ============================================================================
// tb_spi.sv - testbench for my SPI master, with MOSI looped back to MISO.
//
// Since MISO = MOSI (loopback), whatever byte I shift out should come right back
// in. So after a transfer, the received byte should equal what I sent. This tests
// the shift-out AND shift-in paths at once.
//
// I also watch: CS drops low during the transfer, SCLK pulses, and busy clears
// when done.
// ============================================================================

`timescale 1ns/1ps

module tb_spi;

    localparam int CLK_DIV = 4;

    logic        clk, rst_n;
    logic        sel, we;
    logic [31:0] wdata, rdata;
    logic        sclk, mosi, miso, cs_n;

    // loopback: whatever I send on MOSI comes back on MISO.
    assign miso = mosi;

    spi #(.CLK_DIV(CLK_DIV)) dut (
        .clk(clk), .rst_n(rst_n),
        .sel(sel), .we(we), .wdata(wdata), .rdata(rdata),
        .sclk(sclk), .mosi(mosi), .miso(miso), .cs_n(cs_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_spi.vcd");
        $dumpvars(0, tb_spi);
    end

    integer errors;
    logic saw_cs_low;
    logic [7:0] sent;

    // watch that CS actually goes low during a transfer
    always @(posedge clk) begin
        #1;
        if (cs_n === 1'b0) saw_cs_low = 1;
    end

    // start a transfer and wait for busy to clear
    task spi_xfer(input [7:0] b);
        integer guard;
        begin
            sent = b;
            @(negedge clk);
            sel = 1; we = 1; wdata = {24'b0, b};
            @(negedge clk);
            sel = 0; we = 0;
            // wait until busy (bit 0 of rdata) clears
            guard = 0;
            while (rdata[0] === 1'b1 && guard < 2000) begin
                @(posedge clk); guard = guard + 1;
            end
            // a couple cycles for rx_data to settle
            repeat (2) @(posedge clk);
        end
    endtask

    initial begin
        sel = 0; we = 0; wdata = 0;
        errors = 0; saw_cs_low = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        // CS should idle high before any transfer
        #1;
        if (cs_n !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: cs_n not idle-high before transfer");
        end

        // ---- transfer a byte ----
        $display("TEST 1: send 0xA5, loopback should return it");
        spi_xfer(8'hA5);
        if (rdata[15:8] !== 8'hA5) begin
            errors = errors + 1;
            $display("  FAIL: received 0x%02h, expected 0xA5", rdata[15:8]);
        end else $display("  OK: received 0xA5");

        if (!saw_cs_low) begin
            errors = errors + 1;
            $display("  FAIL: CS never went low during transfer");
        end else $display("  OK: CS asserted during transfer");

        // ---- a second byte to be sure ----
        $display("TEST 2: send 0x3C");
        spi_xfer(8'h3C);
        if (rdata[15:8] !== 8'h3C) begin
            errors = errors + 1;
            $display("  FAIL: received 0x%02h, expected 0x3C", rdata[15:8]);
        end else $display("  OK: received 0x3C");

        // CS should be back high after transfers
        #1;
        if (cs_n !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: cs_n not high after transfer");
        end else $display("  OK: CS released high after transfer");

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
