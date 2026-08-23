// ============================================================================
// tb_chip_smoke.sv - "is the CPU alive?" smoke test for chip_top v0.1.
//
// FIX from first run: Ibex fetches its first instruction at boot_addr_i + 0x80.
// With boot_addr_i = 0, that's byte 0x80 = word index 32. So I load the program
// THERE (not at 0), and the jal loops back to 0x8C.
//
// Also: I let the memory wake up after reset before judging fetches (the SRAM
// macros print "operational" once CEN toggles post-reset).
//
// Program (loaded at byte 0x80):
//   0x80: addi x1,x0,5     -> x1 = 5
//   0x84: addi x2,x0,10    -> x2 = 10
//   0x88: addi x3,x1,3     -> x3 = 8
//   0x8C: jal  x0,0        -> infinite loop (jump to self)
//
// Success = PC/fetch settles looping at 0x8C, no "illegal instruction".
// ============================================================================

`timescale 1ns/1ps

module tb_chip_smoke;

    logic clk, rst_n;

    chip_top dut (.clk(clk), .rst_n(rst_n));

    initial clk = 0;
    always #5 clk = ~clk;

    // program words and the word index where they load (byte 0x80 => word 32)
    localparam int BASE_WORD = 32;   // 0x80 / 4
    logic [31:0] prog_mem [0:3];
    initial begin
        prog_mem[0] = 32'h00500093;  // addi x1,x0,5
        prog_mem[1] = 32'h00A00113;  // addi x2,x0,10
        prog_mem[2] = 32'h00308193;  // addi x3,x1,3
        prog_mem[3] = 32'h0000006F;  // jal x0,0
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

    wire [31:0] pc         = dut.u_ibex.u_ibex_core.if_stage_i.pc_id_o;
    wire [31:0] fetch_addr = dut.instr_addr;
    wire        fetch_req  = dut.instr_req;

    integer cycle;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);

        // load the program at word index 32 (byte 0x80), where Ibex boots.
        for (i = 0; i < 4; i = i + 1) begin
            load_word(BASE_WORD + i, prog_mem[i]);
            $display("loaded imem[0x%03h] = 0x%08h", (BASE_WORD+i)*4, prog_mem[i]);
        end

        @(negedge clk);
        rst_n = 1;
        $display("---- reset released, watching CPU fetch (expect it to reach 0x8C loop) ----");

        for (cycle = 0; cycle < 40; cycle = cycle + 1) begin
            @(posedge clk); #1;
            $display("cyc %0d: instr_req=%b fetch_addr=0x%08h  PC=0x%08h",
                     cycle, fetch_req, fetch_addr, pc);
        end

        $display("--------------------------------------------------");
        $display("ALIVE if fetch settled at 0x8C (the jal loop) with no illegal-instruction.");
        $display("--------------------------------------------------");
        $finish;
    end

    initial begin
        #100000;
        $display("TIMEOUT");
        $finish;
    end

endmodule
