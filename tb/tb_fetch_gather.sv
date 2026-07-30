`timescale 1ns/1ps
module tb_fetch_gather;
    logic clk, rst_n;
    logic        c_req, c_gnt, c_rvalid;
    logic [31:0] c_addr, c_rdata;
    logic        m_req, m_gnt, m_rvalid;
    logic [31:0] m_addr;
    logic [7:0]  m_rdata;
    fetch_gather dut (
        .clk(clk), .rst_n(rst_n),
        .c_req(c_req), .c_gnt(c_gnt), .c_addr(c_addr),
        .c_rvalid(c_rvalid), .c_rdata(c_rdata),
        .m_req(m_req), .m_gnt(m_gnt), .m_addr(m_addr),
        .m_rvalid(m_rvalid), .m_rdata(m_rdata)
    );
    initial clk=0; always #5 clk=~clk;
    logic [7:0] mem [0:255];
    assign m_gnt = 1'b1;
    logic        m_req_d;
    logic [7:0]  m_rdata_r;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin m_req_d<=1'b0; m_rdata_r<=8'b0; end
        else begin
            m_req_d <= m_req;
            if (m_req) m_rdata_r <= mem[m_addr[7:0]];
        end
    end
    assign m_rvalid = m_req_d;
    assign m_rdata  = m_rdata_r;
    task preload(input [31:0] base, input [31:0] word);
        begin
            mem[base+0] = word[7:0];   mem[base+1] = word[15:8];
            mem[base+2] = word[23:16]; mem[base+3] = word[31:24];
        end
    endtask
    integer errors;
    task do_fetch(input [31:0] addr, input [31:0] expect_word);
        begin
            @(negedge clk); c_addr = addr; c_req = 1'b1;
            wait (c_gnt); @(negedge clk); c_req = 1'b0;
            wait (c_rvalid); #1;
            if (c_rdata === expect_word)
                $display("OK  fetch @0x%02h = 0x%08h", addr, c_rdata);
            else begin
                $display("BAD fetch @0x%02h = 0x%08h (expected 0x%08h)", addr, c_rdata, expect_word);
                errors = errors + 1;
            end
            @(negedge clk);
        end
    endtask
    initial begin
        errors = 0; c_req=0; c_addr=0;
        preload(0, 32'h11223344); preload(4, 32'hDEADBEEF);
        preload(8, 32'h00500093); preload(12,32'hFFDFF06F);
        rst_n=0; repeat(3) @(posedge clk); rst_n=1; @(negedge clk);
        do_fetch(0,  32'h11223344);
        do_fetch(4,  32'hDEADBEEF);
        do_fetch(8,  32'h00500093);
        do_fetch(12, 32'hFFDFF06F);
        do_fetch(0,  32'h11223344);
        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED (0 errors) - gather unit assembles words correctly");
        else           $display("TESTS FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #10000; $display("TIMEOUT - gather unit hung (handshake bug)"); $finish; end
endmodule
