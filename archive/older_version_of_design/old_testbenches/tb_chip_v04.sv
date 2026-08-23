`timescale 1ns/1ps
module tb_chip_v04;
    localparam int NUM_IO=8, CLK_FREQ=8, BAUD_RATE=1;
    logic clk, rst_n;
    logic [NUM_IO-1:0] gpio_out, gpio_in;
    logic uart_tx, uart_rx;
    assign uart_rx = uart_tx;   // loopback: UART also receives what it sends

    chip_top #(.NUM_IO(NUM_IO), .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_out(gpio_out), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .uart_rx(uart_rx)
    );

    initial clk=0; always #5 clk=~clk;

    // baud period in clock cycles = CLK_FREQ/BAUD_RATE = 8 cycles per bit
    localparam int BIT_CYCLES = CLK_FREQ/BAUD_RATE;

    localparam int BASE_WORD=32;
    logic [31:0] prog_mem[0:3];
    initial begin
        prog_mem[0]=32'h04100293;  // addi x5,x0,0x41
        prog_mem[1]=32'h00020337;  // lui  x6,0x20
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

    // decode the UART tx frame by sampling at bit centers
    logic [7:0] rx_byte;
    integer b;
    task decode_frame;
        begin
            // wait for start bit (tx goes low)
            @(negedge uart_tx);
            // move to center of start bit
            repeat (BIT_CYCLES/2) @(posedge clk);
            // step to center of each data bit and sample (LSB first)
            for (b=0; b<8; b=b+1) begin
                repeat (BIT_CYCLES) @(posedge clk);
                #1; rx_byte[b] = uart_tx;
            end
        end
    endtask

    integer cycle;
    logic started;
    initial begin
        rst_n=0; gpio_in=0; rx_byte=8'h00; started=0;
        repeat(5) @(posedge clk);
        for (i=0;i<4;i=i+1) load_imem(BASE_WORD+i, prog_mem[i]);
        wake_all;
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk); wake_all;
        $display("---- v0.4: CPU writes 0x41 to UART; decoding tx frame ----");
        decode_frame;
        $display("--------------------------------------------------");
        $display("UART tx sent byte: 0x%02h (expect 0x41)", rx_byte);
        if (rx_byte == 8'h41) $display("PASS: CPU sent a byte over UART through the bus. v0.4 ALIVE.");
        else                  $display("CHECK: byte mismatch - inspect.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #2000000; $display("TIMEOUT (no tx frame seen)"); $finish; end
endmodule
