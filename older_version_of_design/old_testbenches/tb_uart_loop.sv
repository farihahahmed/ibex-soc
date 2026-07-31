// ============================================================================
// tb_uart_loop.sv - loopback test for my complete UART (TX + RX)
//
// I wire tx straight into rx, send a byte, and check RX reassembles the same
// byte. This tests BOTH halves at once - the classic UART self-test:
//   TX serializes the byte out -> that wire feeds RX -> RX samples it back in.
//
// Tiny baud (8 clocks/bit) so it runs fast.
// ============================================================================

`timescale 1ns/1ps

module tb_uart_loop;

    localparam int CLK_FREQ  = 8;
    localparam int BAUD_RATE = 1;      // BAUD_DIV = 8 clocks per bit.

    logic        clk, rst_n;
    logic        sel, we;
    logic [31:0] wdata, rdata;
    logic        tx, rx;

    // loopback: tx feeds rx directly.
    assign rx = tx;

    uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst_n(rst_n),
        .sel(sel), .we(we), .wdata(wdata), .rdata(rdata),
        .tx(tx), .rx(rx)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_uart_loop.vcd");
        $dumpvars(0, tb_uart_loop);
    end

    integer errors;
    logic [7:0] test_byte;
    logic [7:0] got;

    // send a byte via the register interface
    task send_byte(input [7:0] b);
        begin
            @(negedge clk);
            sel = 1; we = 1; wdata = {24'b0, b};
            @(negedge clk);
            sel = 0; we = 0; wdata = 0;
        end
    endtask

    // wait until rx_valid (bit 1 of rdata) is set, then read the byte
    task wait_and_read(output [7:0] b);
        integer guard;
        begin
            guard = 0;
            // poll rx_valid by reading status (sel=1, we=0). But reading clears
            // rx_valid, so I peek at the dut's rx_valid via the read value on a
            // NON-clearing cycle: here I just watch rdata bit 1 combinationally.
            while (rdata[1] !== 1'b1 && guard < 2000) begin
                @(posedge clk);
                guard = guard + 1;
            end
            b = rdata[15:8];       // grab the received byte.
            // now do an actual read to clear rx_valid.
            @(negedge clk);
            sel = 1; we = 0;
            @(negedge clk);
            sel = 0;
        end
    endtask

    initial begin
        sel = 0; we = 0; wdata = 0;
        errors = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        test_byte = 8'h41;         // 'A'
        $display("LOOPBACK: send 0x%02h, expect to receive it back", test_byte);
        send_byte(test_byte);

        wait_and_read(got);

        if (got !== test_byte) begin
            errors = errors + 1;
            $display("  FAIL: received 0x%02h, expected 0x%02h", got, test_byte);
        end else begin
            $display("  OK: looped back 0x%02h correctly", got);
        end

        // second byte to be sure it works repeatedly
        test_byte = 8'h5A;         // 'Z'
        $display("LOOPBACK: send 0x%02h", test_byte);
        send_byte(test_byte);
        wait_and_read(got);
        if (got !== test_byte) begin
            errors = errors + 1;
            $display("  FAIL: received 0x%02h, expected 0x%02h", got, test_byte);
        end else begin
            $display("  OK: looped back 0x%02h correctly", got);
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
