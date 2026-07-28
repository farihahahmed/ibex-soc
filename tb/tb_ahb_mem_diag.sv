// ============================================================================
// tb_ahb_mem_diag.sv - DIAGNOSTIC: watch memory read timing cycle by cycle
//
// No pass/fail. I do ONE write then ONE read to memory through the bus, with
// idle cycles around them, and print every AHB signal each cycle. I want to see:
//   - when does HREADY drop (if ever)?
//   - when does the real read data appear on HRDATA vs HREADY/rvalid?
//   - is the read correct because of proper handshaking, or by luck (stale bus)?
// ============================================================================

`timescale 1ns/1ps

module tb_ahb_mem_diag;

    localparam int NUM_IO = 8;

    logic clk, rst_n;

    logic        req, gnt, we, rvalid;
    logic [3:0]  be;
    logic [31:0] addr, wdata, rdata;

    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS;
    logic        HWRITE, HREADY, HRESP;
    logic [3:0]  HWSTRB;

    logic [3:0]  HSEL;
    logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0]  slv_HTRANS;
    logic        slv_HWRITE;

    logic [31:0] s0_HRDATA, s1_HRDATA;
    logic        s0_HREADY, s0_HRESP, s1_HREADY, s1_HRESP;

    logic [NUM_IO-1:0] gpio_out, gpio_in;

    ibex_to_ahb u_adapter (
        .clk(clk), .rst_n(rst_n),
        .req(req), .gnt(gnt), .we(we), .be(be),
        .addr(addr), .wdata(wdata), .rvalid(rvalid), .rdata(rdata),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWSTRB(HWSTRB),
        .HWDATA(HWDATA), .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP)
    );

    ahb_interconnect u_ic (
        .HCLK(clk), .HRESETn(rst_n),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .HSEL(HSEL),
        .slv_HADDR(slv_HADDR), .slv_HTRANS(slv_HTRANS),
        .slv_HWRITE(slv_HWRITE), .slv_HWDATA(slv_HWDATA),
        .s0_HRDATA(s0_HRDATA), .s0_HREADY(s0_HREADY), .s0_HRESP(s0_HRESP),
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP),
        .s2_HRDATA(32'hDEAD_0002), .s2_HREADY(1'b1), .s2_HRESP(1'b0),
        .s3_HRDATA(32'hDEAD_0003), .s3_HREADY(1'b1), .s3_HRESP(1'b0)
    );

    ahb_mem u_mem (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[0]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWSTRB(4'hF), .HWDATA(slv_HWDATA),
        .HRDATA(s0_HRDATA), .HREADY(s0_HREADY), .HRESP(s0_HRESP)
    );

    ahb_gpio #(.NUM_IO(NUM_IO)) u_gpio (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[1]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // print every cycle
    always @(posedge clk) begin
        #1;
        $display("t=%0t req=%b gnt=%b | HTRANS=%b HADDR=0x%08h HWRITE=%b HSEL=%b | HREADY=%b HRDATA=0x%08h | rvalid=%b rdata=0x%08h",
                 $time, req, gnt, HTRANS, HADDR, HWRITE, HSEL, HREADY, HRDATA, rvalid, rdata);
    end

    initial begin
        req=0; we=0; be=0; addr=0; wdata=0; gpio_in=0;
        rst_n=0;
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk);

        // single WRITE to mem word 0
        $display("---- WRITE mem[0] = 0xCAFEBABE ----");
        @(negedge clk);
        req=1; we=1; be=4'hF; addr=32'h0000_0000; wdata=32'hCAFEBABE;
        @(negedge clk);
        req=0; we=0; be=0;

        // idle gap so the bus goes quiet
        repeat(3) @(negedge clk);

        // single READ of mem word 0
        $display("---- READ mem[0] (expect 0xCAFEBABE) ----");
        @(negedge clk);
        req=1; we=0; be=0; addr=32'h0000_0000;
        @(negedge clk);
        req=0;

        // watch several cycles for the data + HREADY behavior
        repeat(6) @(negedge clk);

        $finish;
    end

endmodule
