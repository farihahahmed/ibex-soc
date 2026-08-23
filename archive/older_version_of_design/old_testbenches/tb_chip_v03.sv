`timescale 1ns/1ps
module tb_chip_v03;
    localparam int NUM_IO = 8;
    logic clk, rst_n;
    logic [NUM_IO-1:0] gpio_out, gpio_in;

    chip_top #(.NUM_IO(NUM_IO)) dut (
        .clk(clk), .rst_n(rst_n),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0; always #5 clk = ~clk;

    localparam int BASE_WORD = 32;
    logic [31:0] prog_mem [0:3];
    initial begin
        prog_mem[0]=32'h0A500293;  // addi x5,x0,0xA5
        prog_mem[1]=32'h00010337;  // lui  x6,0x10
        prog_mem[2]=32'h00532023;  // sw   x5,0(x6)
        prog_mem[3]=32'h0000006F;  // jal  x0,0
    end
    integer i;
    task load_imem(input integer w, input [31:0] d);
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[w] = d[7:0];
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[w] = d[15:8];
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[w] = d[23:16];
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[w] = d[31:24];
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

    integer cycle;
    initial begin
        rst_n = 0; gpio_in = 8'h00;
        repeat (5) @(posedge clk);
        for (i=0;i<4;i=i+1) load_imem(BASE_WORD+i, prog_mem[i]);
        wake_all;
        @(negedge clk); rst_n = 1;
        $display("---- v0.3: CPU should write 0xA5 to GPIO ----");
        for (cycle=0; cycle<60; cycle=cycle+1) begin
            @(posedge clk); #1;
            if (cycle < 2) wake_all;
            if (gpio_out !== 8'h00)
                $display("cyc %0d: gpio_out = 0x%02h", cycle, gpio_out);
        end
        $display("--------------------------------------------------");
        $display("Final gpio_out = 0x%02h (expect 0xA5)", gpio_out);
        if (gpio_out == 8'hA5) $display("PASS: CPU drove GPIO pins through the bus. v0.3 ALIVE.");
        else                   $display("CHECK: gpio_out not 0xA5 - inspect.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
