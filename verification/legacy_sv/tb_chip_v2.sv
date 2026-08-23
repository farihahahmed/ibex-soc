`timescale 1ns/1ps
module tb_chip_v2;
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
    localparam int BIT_CYCLES = CLK_FREQ/BAUD_RATE;

    localparam int NWORDS=16, BASE_WORD=0;
    logic [31:0] prog [0:NWORDS-1];
    initial begin
        prog[0]=32'h00010537; prog[1]=32'h000205B7; prog[2]=32'h00030637;
        prog[3]=32'h0A500293; prog[4]=32'h04100313; prog[5]=32'h0B700393;
        prog[6]=32'h00552023; prog[7]=32'h0065A023; prog[8]=32'h00762023;
        prog[9]=32'h00000013; prog[10]=32'hFFDFF06F; prog[11]=32'h00000013;
        prog[12]=32'h00000013; prog[13]=32'h00000013; prog[14]=32'h00000013;
        prog[15]=32'h00000013;
    end

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

    logic [7:0] spi_byte; integer spi_bits;
    initial begin
        spi_byte=8'h0; spi_bits=0;
        forever begin @(posedge spi_sclk); #1;
            if (spi_bits<8) begin spi_byte={spi_byte[6:0],spi_mosi}; spi_bits=spi_bits+1; end
        end
    end

    logic [7:0] uart_byte; integer bb;
    task decode_uart;
        begin
            @(negedge uart_tx);
            repeat (BIT_CYCLES/2) @(posedge clk);
            for (bb=0;bb<8;bb=bb+1) begin repeat (BIT_CYCLES) @(posedge clk); #1; uart_byte[bb]=uart_tx; end
        end
    endtask

    task wake_all;
        begin
            dut.u_mem.u_imem.u_mem.u_sram.cen_fell=1'b1; dut.u_mem.u_imem.u_mem.u_sram.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_dly=1'b1;
        end
    endtask

    integer i, errors;
    initial begin
        scan_in=0; scan_shift=0; scan_load=0; scan_i0o1=0; gpio_in=0;
        clk_int=0;
        uart_byte=8'h0; errors=0;

        rst_n=0; repeat(6) @(negedge clk); rst_n=1; repeat(4) @(negedge clk); wake_all;
        for (i=0;i<NWORDS;i=i+1) scan_frame(2'd0, 14'(BASE_WORD+i), prog[i]);
        $display("program scanned in.");

        scan_frame(2'd2, 14'h0000, 32'h00000000);
        scan_frame(2'd1, 14'h0000, {14'h0, 2'd1, 16'd0});
        $display("FSM set to RUN. CPU running...");

        fork
            decode_uart;
            begin for (int w=0;w<800;w=w+1) begin @(posedge clk); wake_all; end end
        join

        $display("--------------------------------------------------");
        $display("  GPIO out : 0x%02h (expect 0x05)", gpio_out);
        $display("  UART sent: 0x%02h (expect 0x41)", uart_byte);
        $display("  SPI MOSI : 0x%02h (expect 0xB7), bits=%0d", spi_byte, spi_bits);
        if (gpio_out!==5'h05) errors=errors+1;
        if (uart_byte!==8'h41) errors=errors+1;
        if (spi_byte!==8'hB7) errors=errors+1;
        $display("--------------------------------------------------");
        if (errors==0) $display("PASS: SoC boots via scan-configured FSM!");
        else $display("CHECK: %0d mismatch(es)", errors);
        $finish;
    end
    initial begin #20000000; $display("TIMEOUT"); $finish; end
endmodule
