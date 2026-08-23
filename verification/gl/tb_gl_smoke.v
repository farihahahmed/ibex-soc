`timescale 1ns/1ps
module tb_gl_smoke;
    reg clk, clk_int, rst_n;
    reg scan_in, scan_shift, scan_load, scan_i0o1;
    wire scan_out;
    wire [4:0] gpio_out;
    reg  [1:0] gpio_in;
    wire uart_tx;
    reg  uart_rx;
    wire spi_sclk, spi_mosi, spi_cs_n;

    chip_top_full dut (
        .clk(clk), .clk_int(clk_int), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift),
        .scan_load(scan_load), .scan_i0o1(scan_i0o1),
        .scan_out(scan_out),
        .gpio_out(gpio_out), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cyc;
    initial begin
        clk_int = 0;
        scan_in = 0; scan_shift = 0; scan_load = 0; scan_i0o1 = 0;
        gpio_in = 0; uart_rx = 1;
        rst_n = 0;
        repeat (20) @(negedge clk);
        rst_n = 1;
        for (cyc = 0; cyc < 200; cyc = cyc + 1) @(posedge clk);
        $display("GL smoke: after reset gpio_out=%b uart_tx=%b", gpio_out, uart_tx);
        $display("*** GL SMOKE PASS (netlist ran) ***");
        $finish;
    end

    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end
endmodule
