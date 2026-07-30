`timescale 1ns/1ps
module tb_dmem_narrow;
    logic clk, rst_n;
    logic        req, gnt, we, rvalid;
    logic [3:0]  be;
    logic [31:0] addr, wdata, rdata;
    logic        ld_word_en, ld_busy;
    logic [15:0] ld_word_addr;
    logic [31:0] ld_word_data;

    dmem_narrow_top dut (
        .clk(clk), .rst_n(rst_n),
        .req(req), .gnt(gnt), .we(we), .be(be),
        .addr(addr), .wdata(wdata), .rvalid(rvalid), .rdata(rdata),
        .ld_word_en(ld_word_en), .ld_word_addr(ld_word_addr),
        .ld_word_data(ld_word_data), .ld_busy(ld_busy)
    );

    initial clk=0; always #5 clk=~clk;
    integer errors;

    // full 32-bit write (all bytes)
    task wr(input [31:0] a, input [31:0] d, input [3:0] byteen);
        begin
            @(negedge clk); addr=a; wdata=d; be=byteen; we=1; req=1;
            wait(gnt); @(negedge clk); req=0; we=0;
            wait(rvalid); @(negedge clk);
        end
    endtask

    task rd_chk(input [31:0] a, input [31:0] exp);
        begin
            @(negedge clk); addr=a; we=0; be=4'hF; req=1;
            wait(gnt); @(negedge clk); req=0;
            wait(rvalid); #1;
            if (rdata===exp) $display("OK  read @0x%02h = 0x%08h", a, rdata);
            else begin $display("BAD read @0x%02h = 0x%08h (exp 0x%08h)", a, rdata, exp); errors=errors+1; end
            @(negedge clk);
        end
    endtask

    initial begin
        errors=0; req=0; we=0; be=0; addr=0; wdata=0;
        ld_word_en=0; ld_word_addr=0; ld_word_data=0;
        rst_n=0; repeat(6) @(posedge clk); rst_n=1; repeat(6) @(negedge clk);

        // 1) full-word write then read back
        wr(32'h00, 32'hDEADBEEF, 4'b1111);
        wr(32'h04, 32'h12345678, 4'b1111);
        rd_chk(32'h00, 32'hDEADBEEF);
        rd_chk(32'h04, 32'h12345678);

        // 2) partial byte-write: overwrite ONLY byte 1 of addr 0 (be=0010)
        //    0xDEADBEEF -> write 0x??33?? into byte1 -> expect 0xDEAD33EF
        wr(32'h00, 32'h0000_3300, 4'b0010);
        rd_chk(32'h00, 32'hDEAD33EF);

        // 3) partial byte-write: overwrite byte 3 only (be=1000)
        //    0xDEAD33EF -> byte3=0x99 -> expect 0x99AD33EF
        wr(32'h00, 32'h9900_0000, 4'b1000);
        rd_chk(32'h00, 32'h99AD33EF);

        // 4) another address untouched by the above
        rd_chk(32'h04, 32'h12345678);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - narrow dmem read/write/byte-enable works!");
        else           $display("FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
