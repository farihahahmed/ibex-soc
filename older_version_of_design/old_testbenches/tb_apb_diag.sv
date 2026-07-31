// ============================================================================
// tb_apb_diag.sv - DIAGNOSTIC for the two-tier bus. Prints every signal each
// cycle across the WHOLE chain so I can see where a write/read gets stuck.
// One write to GPIO region, then stop (no read, so it can't hang).
// ============================================================================

`timescale 1ns/1ps

module tb_apb_diag;

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
    logic [31:0] s1_HRDATA;
    logic        s1_HREADY, s1_HRESP;
    logic        PSEL, PENABLE, PWRITE, PREADY;
    logic [31:0] PADDR, PWDATA, PRDATA;
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
        .s0_HRDATA(32'h0), .s0_HREADY(1'b1), .s0_HRESP(1'b0),
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP),
        .s2_HRDATA(32'h0), .s2_HREADY(1'b1), .s2_HRESP(1'b0),
        .s3_HRDATA(32'h0), .s3_HREADY(1'b1), .s3_HRESP(1'b0)
    );
    ahb_to_apb u_bridge (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[1]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY)
    );
    apb_gpio #(.NUM_IO(NUM_IO)) u_gpio (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        $display("t=%0t req=%b gnt=%b HREADY=%b | HSEL=%b slv_HTRANS=%b slv_HWRITE=%b | PSEL=%b PEN=%b PWRITE=%b PADDR=0x%05h PWDATA=0x%08h | gpio_out=0x%02h",
                 $time, req, gnt, HREADY, HSEL, slv_HTRANS, slv_HWRITE,
                 PSEL, PENABLE, PWRITE, PADDR[19:0], PWDATA, gpio_out);
    end

    initial begin
        req=0; we=0; be=0; addr=0; wdata=0; gpio_in=0;
        rst_n=0;
        repeat(3) @(posedge clk);
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk);

        $display("---- WRITE 0xA5 to GPIO region 0x00010000 ----");
        @(negedge clk);
        req=1; we=1; be=4'hF; addr=32'h0001_0000; wdata=32'h0000_00A5;
        // hold req until granted, but cap it so we can't hang forever
        repeat(10) begin
            @(posedge clk);
            if (gnt === 1'b1) begin @(negedge clk); req=0; we=0; end
        end
        req=0; we=0;

        repeat(6) @(negedge clk);
        $display("final gpio_out = 0x%02h", gpio_out);
        $finish;
    end
endmodule
