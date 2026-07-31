`timescale 1ns/1ps
module tb_chip_smoke3;
    logic clk, rst_n;
    chip_top dut (.clk(clk), .rst_n(rst_n));
    initial clk = 0; always #5 clk = ~clk;

    localparam int BASE_WORD = 32;
    logic [31:0] prog_mem [0:3];
    initial begin
        prog_mem[0]=32'h00500093; prog_mem[1]=32'h00A00113;
        prog_mem[2]=32'h00308193; prog_mem[3]=32'h0000006F;
    end
    integer i;
    task load_word(input integer w, input [31:0] data);
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[w] = data[7:0];
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[w] = data[15:8];
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[w] = data[23:16];
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[w] = data[31:24];
        end
    endtask

    wire [31:0] fetch_addr = dut.instr_addr;
    wire        fetch_rvalid = dut.instr_rvalid;
    wire [31:0] fetch_rdata  = dut.instr_rdata;

    // macro lane0 pins
    wire        m_cen = dut.u_mem.u_imem.u_bank.lane[0].u_macro.CEN;
    wire [8:0]  m_a   = dut.u_mem.u_imem.u_bank.lane[0].u_macro.A;
    wire [7:0]  m_q   = dut.u_mem.u_imem.u_bank.lane[0].u_macro.Q;
    // bank-level signals feeding the macro
    wire        b_cs  = dut.u_mem.u_imem.u_bank.cs;
    wire [8:0]  b_addr= dut.u_mem.u_imem.u_bank.addr;

    integer cycle;
    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        for (i=0;i<4;i=i+1) load_word(BASE_WORD+i, prog_mem[i]);
        @(negedge clk); rst_n = 1;
        $display("---- macro pin probe ----");
        for (cycle=0; cycle<14; cycle=cycle+1) begin
            @(posedge clk); #1;
            $display("cyc %0d: fetchaddr=0x%08h | bank cs=%b addr=%0d | macro CEN=%b A=%0d Q=0x%02h | rvalid=%b rdata=0x%08h",
                     cycle, fetch_addr, b_cs, b_addr, m_cen, m_a, m_q, fetch_rvalid, fetch_rdata);
        end
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
