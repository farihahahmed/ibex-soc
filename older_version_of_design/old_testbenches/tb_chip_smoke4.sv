// ============================================================================
// tb_chip_smoke4.sv - v0.1 smoke test with SRAM macro WAKE-UP handled.
//
// The GF180 macro model needs a clean CEN falling edge (with its internal #100
// delayed copy settling) before it will output read data. On plain reset-release
// the CPU asserts CEN too fast and the macro never registers "operational",
// outputting zeros.
//
// Fix: I give the memory a longer, quiet reset window so the macro's #100 CEN
// delay settles with CEN held high (deselected) - then when the CPU's first
// fetch pulls CEN low, it's a clean wake-up edge and the macro comes alive.
//
// Program at byte 0x80 (word 32), where Ibex boots. Success: fetch reaches 0x8C
// loop with the instructions actually read back (no illegal-instruction).
// ============================================================================
`timescale 1ns/1ps
module tb_chip_smoke4;
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
            // also load DMEM lanes harmlessly? no - imem only for fetch.
        end
    endtask

    wire [31:0] fetch_addr = dut.instr_addr;
    wire [31:0] fetch_rdata = dut.instr_rdata;
    wire        fetch_rvalid = dut.instr_rvalid;
    // macro operational flags (per lane) - I can watch them wake up
    wire imem_l0_fell = dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_fell;

    integer cycle;

    initial begin
        rst_n = 0;

        // ---- LONG quiet reset so the macro's #100 CEN delay settles ----
        // During reset the CPU isn't fetching, cs=0 -> CEN=1 (high, asleep).
        // Hold this well past 100 time units (>=20 cycles = 200ns) so cen_dly
        // catches up high before any access.
        repeat (30) @(posedge clk);

        // load program while still in reset
        for (i=0;i<4;i=i+1) begin
            load_word(BASE_WORD+i, prog_mem[i]);
            $display("loaded imem[0x%03h] = 0x%08h", (BASE_WORD+i)*4, prog_mem[i]);
        end

        repeat (5) @(posedge clk);   // a little more quiet time after load

        @(negedge clk); rst_n = 1;
        $display("---- reset released (macro should be operational) ----");

        for (cycle=0; cycle<45; cycle=cycle+1) begin
            @(posedge clk); #1;
            $display("cyc %0d: addr=0x%08h rvalid=%b rdata=0x%08h  (l0_fell=%b)",
                     cycle, fetch_addr, fetch_rvalid, fetch_rdata, imem_l0_fell);
        end
        $display("--------------------------------------------------");
        $display("ALIVE if rdata shows 0x00500093 etc and fetch reaches 0x8C loop.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
