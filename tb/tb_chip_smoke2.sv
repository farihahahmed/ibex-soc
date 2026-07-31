// ============================================================================
// tb_chip_smoke2.sv - smoke test + memory readback + macro read-port probe.
// Confirms (a) the force actually populated the array, and (b) what the macro
// sees on its address/output pins during a fetch.
// ============================================================================
`timescale 1ns/1ps
module tb_chip_smoke2;
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
    wire        fetch_req  = dut.instr_req;
    wire        fetch_gnt  = dut.instr_gnt;
    wire        fetch_rvalid = dut.instr_rvalid;
    wire [31:0] fetch_rdata  = dut.instr_rdata;

    integer cycle;
    logic [7:0] rb0, rb1, rb2, rb3;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        for (i=0;i<4;i=i+1) load_word(BASE_WORD+i, prog_mem[i]);

        // READ BACK the array to confirm the force populated it.
        rb0 = dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[BASE_WORD];
        rb1 = dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[BASE_WORD];
        rb2 = dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[BASE_WORD];
        rb3 = dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[BASE_WORD];
        $display("READBACK word[%0d]: lane3=%02h lane2=%02h lane1=%02h lane0=%02h (expect 00 50 00 93 -> wait, 0x00500093 => b3=00 b2=50 b1=00 b0=93)",
                 BASE_WORD, rb3, rb2, rb1, rb0);
        $display("  reconstructed = 0x%02h%02h%02h%02h (expect 0x00500093)", rb3, rb2, rb1, rb0);

        @(negedge clk); rst_n = 1;
        $display("---- watching fetch handshake + rdata ----");
        for (cycle=0; cycle<20; cycle=cycle+1) begin
            @(posedge clk); #1;
            $display("cyc %0d: req=%b gnt=%b rvalid=%b addr=0x%08h rdata=0x%08h",
                     cycle, fetch_req, fetch_gnt, fetch_rvalid, fetch_addr, fetch_rdata);
        end
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
