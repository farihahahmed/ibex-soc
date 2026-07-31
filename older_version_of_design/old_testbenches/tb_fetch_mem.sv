`timescale 1ns/1ps
module tb_fetch_mem;
    logic clk, rst_n;
    logic        c_req, c_gnt, c_rvalid;
    logic [31:0] c_addr, c_rdata;
    logic        m_req, m_sel, m_gnt, m_rvalid;
    logic [31:0] m_addr;
    logic [7:0]  m_rdata;
    logic        ld_en;
    logic [8:0]  ld_addr;
    logic [7:0]  ld_data;

    fetch_gather u_gather (
        .clk(clk), .rst_n(rst_n),
        .c_req(c_req), .c_gnt(c_gnt), .c_addr(c_addr),
        .c_rvalid(c_rvalid), .c_rdata(c_rdata),
        .m_req(m_req), .m_sel(m_sel), .m_gnt(m_gnt), .m_addr(m_addr),
        .m_rvalid(m_rvalid), .m_rdata(m_rdata)
    );
    imem_narrow u_mem (
        .clk(clk), .rst_n(rst_n),
        .m_req(m_req), .m_sel(m_sel), .m_gnt(m_gnt), .m_addr(m_addr),
        .m_rvalid(m_rvalid), .m_rdata(m_rdata),
        .ld_en(ld_en), .ld_addr(ld_addr), .ld_data(ld_data)
    );

    initial clk = 0; always #5 clk = ~clk;
    integer errors;

    task load_word(input [8:0] base, input [31:0] word);
        begin
            @(negedge clk); ld_en=1; ld_addr=base+0; ld_data=word[7:0];
            @(negedge clk);        ld_addr=base+1; ld_data=word[15:8];
            @(negedge clk);        ld_addr=base+2; ld_data=word[23:16];
            @(negedge clk);        ld_addr=base+3; ld_data=word[31:24];
            @(negedge clk); ld_en=0;
        end
    endtask

    task fetch_check(input [31:0] addr, input [31:0] exp_word);
        begin
            @(negedge clk);
            c_addr=addr; c_req=1;
            wait (c_gnt); @(negedge clk); c_req=0;
            wait (c_rvalid); #1;
            if (c_rdata === exp_word)
                $display("OK  fetch @0x%03h = 0x%08h", addr, c_rdata);
            else begin
                $display("BAD fetch @0x%03h = 0x%08h (expected 0x%08h)", addr, c_rdata, exp_word);
                errors=errors+1;
            end
            @(negedge clk);
        end
    endtask

    initial begin
        errors=0; c_req=0; c_addr=0; ld_en=0; ld_addr=0; ld_data=0;
        rst_n=0; repeat(4) @(posedge clk); rst_n=1; @(negedge clk);

        load_word(9'h000, 32'h00500093);
        load_word(9'h004, 32'h00A00113);
        load_word(9'h008, 32'h002081B3);
        load_word(9'h00C, 32'hFFDFF06F);

        fetch_check(32'h000, 32'h00500093);
        fetch_check(32'h004, 32'h00A00113);
        fetch_check(32'h008, 32'h002081B3);
        fetch_check(32'h00C, 32'hFFDFF06F);
        fetch_check(32'h000, 32'h00500093);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED - gather+narrow-memory fetch path works!");
        else           $display("TESTS FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #40000; $display("TIMEOUT - fetch path hung"); $finish; end
endmodule
