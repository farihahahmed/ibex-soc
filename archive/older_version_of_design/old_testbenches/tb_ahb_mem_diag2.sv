// ============================================================================
// tb_ahb_mem_diag2.sv - DECISIVE diagnostic: change addresses so stale data can't hide bugs
//
// I write TWO different values to TWO different addresses, then read them back in
// an order that would expose stale-data reads. If the read path is correct, each
// read returns ITS OWN address's value. If it's returning stale/previous data,
// I'll see the wrong value and know the handshake is broken.
// ============================================================================

`timescale 1ns/1ps

module tb_ahb_mem_diag2;

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
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP), .HSEL(HSEL),
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
        .HCLK(clk), .HRESETn(rst_n), .HSEL(HSEL[1]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        $display("t=%0t req=%b gnt=%b | HTRANS=%b HADDR=0x%08h HWRITE=%b HSEL=%b | HREADY=%b HRDATA=0x%08h | rvalid=%b rdata=0x%08h",
                 $time, req, gnt, HTRANS, HADDR, HWRITE, HSEL, HREADY, HRDATA, rvalid, rdata);
    end

    task do_req(input wr, input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            req=1; we=wr; be=4'hF; addr=a; wdata=d;
            @(negedge clk);
            req=0; we=0; be=0;
        end
    endtask

    initial begin
        req=0; we=0; be=0; addr=0; wdata=0; gpio_in=0;
        rst_n=0;
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk);

        $display("---- WRITE mem[0]=0xAAAAAAAA, mem[4]=0xBBBBBBBB ----");
        do_req(1, 32'h0000_0000, 32'hAAAAAAAA);
        do_req(1, 32'h0000_0004, 32'hBBBBBBBB);

        repeat(2) @(negedge clk);

        // Read addr 4 FIRST (its data is NOT currently on the bus), then addr 0.
        // If reads return stale data, addr 4's read will be wrong.
        $display("---- READ mem[4] (expect 0xBBBBBBBB) ----");
        do_req(0, 32'h0000_0004, 32'h0);
        repeat(2) @(negedge clk);
        $display("---- READ mem[0] (expect 0xAAAAAAAA) ----");
        do_req(0, 32'h0000_0000, 32'h0);
        repeat(4) @(negedge clk);

        $finish;
    end
endmodule

