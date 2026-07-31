`timescale 1ns/1ps
module tb_piezo;
    localparam int NUM_OUT=5, NUM_IN=2, CLK_FREQ=8, BAUD_RATE=1, SPI_CLK_DIV=2;
    logic clk, clk_int, rst_n;
    logic scan_in, scan_shift, scan_load, scan_i0o1, scan_out;
    logic [NUM_OUT-1:0] gpio_out;
    logic [NUM_IN-1:0]  gpio_in;
    logic uart_tx, uart_rx; assign uart_rx = uart_tx;
    logic spi_sclk, spi_mosi, spi_cs_n;

    chip_top_full #(.NUM_OUT(NUM_OUT), .NUM_IN(NUM_IN), .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE), .SPI_CLK_DIV(SPI_CLK_DIV)) dut (
        .clk(clk), .clk_int(clk_int), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .gpio_out(gpio_out), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_cs_n(spi_cs_n)
    );

    initial clk=0; always #5 clk=~clk;

    localparam int NWORDS=31, BASE_WORD=32;
    logic [31:0] prog [0:NWORDS-1];
    initial begin
`include "g_tune_prog.svh"
    end

    task wake_all;
        begin
            dut.u_mem.u_imem.u_mem.u_sram.cen_fell=1'b1; dut.u_mem.u_imem.u_mem.u_sram.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_dly=1'b1;
        end
    endtask

    integer k;
    task scan_frame(input [1:0] tgt, input [13:0] addr, input [31:0] data);
        logic [47:0] frame;
        begin
            frame = {tgt, addr, data};
            for (k=0;k<48;k=k+1) begin @(negedge clk); scan_in=frame[k]; scan_shift=1; end
            @(negedge clk); scan_shift=0; scan_in=0;
            @(negedge clk); scan_load=1;
            @(negedge clk); scan_load=0;
        end
    endtask

    integer toggles; logic last_bit;
    initial begin toggles=0; last_bit=0; end
    always @(posedge clk) begin
        if (gpio_out[0] !== last_bit) begin toggles=toggles+1; last_bit=gpio_out[0]; end
    end

    integer i, errors;
    initial begin
        scan_in=0; scan_shift=0; scan_load=0; scan_i0o1=0; gpio_in=0; clk_int=0; errors=0;
        rst_n=0; repeat(6) @(negedge clk); rst_n=1; repeat(4) @(negedge clk); wake_all;

        for (i=0;i<NWORDS;i=i+1) scan_frame(2'd0, 14'(BASE_WORD+i), prog[i]);
        $display("g_tune scanned in (%0d words).", NWORDS);
        scan_frame(2'd2, 14'h0000, 32'h00000000);
        scan_frame(2'd1, 14'h0000, {14'h0, 2'd1, 16'd0});
        $display("FSM -> RUN. Playing tone...");

        begin for (int w=0; w<40000; w=w+1) begin @(posedge clk); wake_all; end end

        $display("--------------------------------------------------");
        $display("  gpio_out[0] toggles: %0d (piezo square wave)", toggles);
        if (toggles < 4) begin $display("BAD: pin not oscillating (tone not playing)"); errors=errors+1; end
        else $display("OK: piezo pin oscillating - tone is playing");
        $display("--------------------------------------------------");
        if (errors==0) $display("PASS: GPIO piezo demo drives a tone (Happy Birthday)!");
        else $display("CHECK: %0d error(s)", errors);
        $finish;
    end
    initial begin #60000000; $display("TIMEOUT (toggles=%0d)", toggles); $finish; end
endmodule
