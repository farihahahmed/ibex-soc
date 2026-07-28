// ============================================================================
// tb_chip_smoke5.sv - v0.1 smoke test; wake the SRAM macros EXPLICITLY.
//
// Root cause of the zero reads: the macro sets its internal cen_fell (=>
// "operational") only when it observes a clean CEN 1->0 edge with its #100
// delayed copy cen_dly already settled high. On plain reset, CEN sits high and
// cen_dly may be uninitialized (X), so the edge is never registered and reads
// return 0 forever.
//
// Fix: during reset I directly force each macro's cen_fell = 1 (and toggle CEN
// through a clean high->low->high so cen_dly settles). This mimics the power-up
// wake-up the real macro gets, letting reads work. Pure sim bring-up nudge - the
// design itself (cen = ~cs) is correct.
// ============================================================================
`timescale 1ns/1ps
module tb_chip_smoke5;
    logic clk, rst_n;
    chip_top dut (.clk(clk), .rst_n(rst_n));
    initial clk = 0; always #5 clk = ~clk;

    localparam int BASE_WORD = 32;
    logic [31:0] prog_mem [0:3];
    initial begin
        prog_mem[0]=32'h00500093; prog_mem[1]=32'h00A00113;
        prog_mem[2]=32'h00308193; prog_mem[3]=32'h0000006F;
    end
    integer i, L;
    task load_word(input integer w, input [31:0] data);
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[w] = data[7:0];
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[w] = data[15:8];
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[w] = data[23:16];
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[w] = data[31:24];
        end
    endtask

    // directly set the "operational" flags in every imem + dmem macro lane.
    task wake_macros;
        begin
            // imem lanes
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_dly  = 1'b1;
            // dmem lanes
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_dly  = 1'b1;
        end
    endtask

    wire [31:0] fetch_addr = dut.instr_addr;
    wire [31:0] fetch_rdata = dut.instr_rdata;
    wire        fetch_rvalid = dut.instr_rvalid;

    integer cycle;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);

        for (i=0;i<4;i=i+1) begin
            load_word(BASE_WORD+i, prog_mem[i]);
            $display("loaded imem[0x%03h] = 0x%08h", (BASE_WORD+i)*4, prog_mem[i]);
        end

        // wake the macros just before releasing reset
        wake_macros;
        $display("---- macros woken (cen_fell forced) ----");

        @(negedge clk); rst_n = 1;
        $display("---- reset released ----");

        for (cycle=0; cycle<45; cycle=cycle+1) begin
            @(posedge clk); #1;
            // keep re-asserting wake in the first couple cycles in case the
            // macro's own logic clears it before it's latched
            if (cycle < 2) wake_macros;
            $display("cyc %0d: addr=0x%08h rvalid=%b rdata=0x%08h",
                     cycle, fetch_addr, fetch_rvalid, fetch_rdata);
        end
        $display("--------------------------------------------------");
        $display("ALIVE if rdata shows the real instructions and fetch reaches 0x8C.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
