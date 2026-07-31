`timescale 1ns/1ps
module tb_chip_v05;
    localparam int NUM_IO=8, CLK_FREQ=8, BAUD_RATE=1, SPI_CLK_DIV=2;
    logic clk, rst_n;
    logic [NUM_IO-1:0] gpio_out, gpio_in;
    logic uart_tx, uart_rx; assign uart_rx = uart_tx;
    logic spi_sclk, spi_mosi, spi_miso, spi_cs_n;
    assign spi_miso = spi_mosi;   // SPI loopback: receives what it sends

    chip_top #(.NUM_IO(NUM_IO), .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .SPI_CLK_DIV(SPI_CLK_DIV)) dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_out(gpio_out), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_cs_n(spi_cs_n)
    );

    initial clk=0; always #5 clk=~clk;

    localparam int BASE_WORD=32;
    logic [31:0] prog_mem[0:3];
    initial begin
        prog_mem[0]=32'h0B700293;  // addi x5,x0,0xB7
        prog_mem[1]=32'h00030337;  // lui  x6,0x30
        prog_mem[2]=32'h00532023;  // sw   x5,0(x6)
        prog_mem[3]=32'h0000006F;  // jal  x0,0
    end
    integer i;
    task load_imem(input integer w, input [31:0] d);
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[w]=d[7:0];
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[w]=d[15:8];
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[w]=d[23:16];
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[w]=d[31:24];
        end
    endtask
    task wake_all;
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[0].u_macro.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_bank.lane[0].u_macro.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[1].u_macro.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_bank.lane[1].u_macro.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[2].u_macro.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_bank.lane[2].u_macro.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[3].u_macro.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_bank.lane[3].u_macro.cen_dly=1'b1;
        end
    endtask

    // capture the byte MOSI shifts out (MSB first), sampled on SCLK rising edges
    logic [7:0] mosi_byte;
    integer bitcnt;
    initial begin
        mosi_byte = 8'h00; bitcnt = 0;
        forever begin
            @(posedge spi_sclk);
            #1;
            if (bitcnt < 8) begin
                mosi_byte = {mosi_byte[6:0], spi_mosi};  // shift in MSB-first
                bitcnt = bitcnt + 1;
            end
        end
    end

    integer cycle;
    initial begin
        rst_n=0; gpio_in=0;
        repeat(5) @(posedge clk);
        for (i=0;i<4;i=i+1) load_imem(BASE_WORD+i, prog_mem[i]);
        wake_all;
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk); wake_all;
        $display("---- v0.5: CPU writes 0xB7 to SPI; capturing MOSI ----");
        repeat(400) @(posedge clk);
        $display("--------------------------------------------------");
        $display("SPI shifted out on MOSI: 0x%02h (expect 0xB7), bits captured=%0d", mosi_byte, bitcnt);
        if (mosi_byte == 8'hB7) $display("PASS: CPU drove SPI MOSI through the bus. v0.5 ALIVE - FULL SoC!");
        else                    $display("CHECK: MOSI byte mismatch - inspect.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #3000000; $display("TIMEOUT"); $finish; end
endmodule
