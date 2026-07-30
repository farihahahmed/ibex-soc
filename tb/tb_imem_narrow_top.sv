`timescale 1ns/1ps
module tb_imem_narrow_top;
    logic clk, rst_n;
    logic        req, gnt, rvalid;
    logic [31:0] addr, rdata;
    logic        ld_word_en, ld_busy;
    logic [15:0] ld_word_addr;
    logic [31:0] ld_word_data;

    imem_narrow_top dut (
        .clk(clk), .rst_n(rst_n),
        .req(req), .gnt(gnt), .addr(addr), .rvalid(rvalid), .rdata(rdata),
        .ld_word_en(ld_word_en), .ld_word_addr(ld_word_addr),
        .ld_word_data(ld_word_data), .ld_busy(ld_busy)
    );

    initial clk=0; always #5 clk=~clk;
    integer errors;

    task load_w(input [15:0] waddr, input [31:0] wdata);
        begin
            @(negedge clk); ld_word_en=1; ld_word_addr=waddr; ld_word_data=wdata;
            @(negedge clk); ld_word_en=0;
            wait(!ld_busy);           // wait for the 4 byte-writes to finish
            @(negedge clk);
        end
    endtask

    task fetch_chk(input [31:0] a, input [31:0] exp);
        begin
            @(negedge clk); addr=a; req=1;
            wait(gnt); @(negedge clk); req=0;
            wait(rvalid); #1;
            if (rdata===exp) $display("OK  fetch @0x%03h = 0x%08h", a, rdata);
            else begin $display("BAD fetch @0x%03h = 0x%08h (exp 0x%08h)", a, rdata, exp); errors=errors+1; end
            @(negedge clk);
        end
    endtask

    initial begin
        errors=0; req=0; addr=0; ld_word_en=0; ld_word_addr=0; ld_word_data=0;
        rst_n=0; repeat(4) @(posedge clk); rst_n=1; @(negedge clk);

        // scan-load a 4-word program (WORD addresses 0,1,2,3)
        load_w(16'd0, 32'h00500093);
        load_w(16'd1, 32'h00A00113);
        load_w(16'd2, 32'h002081B3);
        load_w(16'd3, 32'hFFDFF06F);

        // fetch by BYTE address (word*4)
        fetch_chk(32'h000, 32'h00500093);
        fetch_chk(32'h004, 32'h00A00113);
        fetch_chk(32'h008, 32'h002081B3);
        fetch_chk(32'h00C, 32'hFFDFF06F);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - narrow imem top (scan-load + fetch) works!");
        else           $display("FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #60000; $display("TIMEOUT"); $finish; end
endmodule
