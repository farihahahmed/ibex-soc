// ============================================================================
// tb_apb_wdiag.sv - watch the UART WRITE's address capture through the bridge.
// Single write to UART only (no GPIO first), well-spaced, printing HADDR,
// the bridge address path, and PADDR. Bounded.
// ============================================================================
`timescale 1ns/1ps
module tb_apb_wdiag;
    localparam int NUM_IO=8, CLK_FREQ=8, BAUD_RATE=1;
    logic clk, rst_n;
    logic        req, gnt, we, rvalid;
    logic [3:0]  be;
    logic [31:0] addr, wdata, rdata;
    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS; logic HWRITE, HREADY, HRESP; logic [3:0] HWSTRB;
    logic [3:0]  HSEL;
    logic [31:0] slv_HADDR, slv_HWDATA; logic [1:0] slv_HTRANS; logic slv_HWRITE;
    logic [31:0] br_HRDATA; logic br_HREADY, br_HRESP;
    logic        PSEL, PENABLE, PWRITE, PREADY; logic [31:0] PADDR, PWDATA, PRDATA;
    logic        gpio_PSEL, uart_PSEL, spi_PSEL;
    logic [31:0] gpio_PRDATA, uart_PRDATA, spi_PRDATA;
    logic        gpio_PREADY, uart_PREADY, spi_PREADY;
    logic        p_PENABLE, p_PWRITE; logic [31:0] p_PADDR, p_PWDATA;
    logic [NUM_IO-1:0] gpio_out, gpio_in;
    logic tx, rx; assign rx = tx;
    assign spi_PRDATA=32'h0; assign spi_PREADY=1'b1;

    ibex_to_ahb u_adapter (.clk(clk),.rst_n(rst_n),.req(req),.gnt(gnt),.we(we),.be(be),
        .addr(addr),.wdata(wdata),.rvalid(rvalid),.rdata(rdata),
        .HADDR(HADDR),.HTRANS(HTRANS),.HWRITE(HWRITE),.HWSTRB(HWSTRB),
        .HWDATA(HWDATA),.HRDATA(HRDATA),.HREADY(HREADY),.HRESP(HRESP));
    ahb_interconnect u_ic (.HCLK(clk),.HRESETn(rst_n),
        .HADDR(HADDR),.HTRANS(HTRANS),.HWRITE(HWRITE),.HWDATA(HWDATA),
        .HRDATA(HRDATA),.HREADY(HREADY),.HRESP(HRESP),.HSEL(HSEL),
        .slv_HADDR(slv_HADDR),.slv_HTRANS(slv_HTRANS),.slv_HWRITE(slv_HWRITE),.slv_HWDATA(slv_HWDATA),
        .s0_HRDATA(32'h0),.s0_HREADY(1'b1),.s0_HRESP(1'b0),
        .s1_HRDATA(br_HRDATA),.s1_HREADY(br_HREADY),.s1_HRESP(br_HRESP),
        .s2_HRDATA(br_HRDATA),.s2_HREADY(br_HREADY),.s2_HRESP(br_HRESP),
        .s3_HRDATA(32'h0),.s3_HREADY(1'b1),.s3_HRESP(1'b0));
    ahb_to_apb u_bridge (.HCLK(clk),.HRESETn(rst_n),.HSEL(HSEL[1]|HSEL[2]),
        .HADDR(slv_HADDR),.HTRANS(slv_HTRANS),.HWRITE(slv_HWRITE),.HWDATA(slv_HWDATA),
        .HRDATA(br_HRDATA),.HREADY(br_HREADY),.HRESP(br_HRESP),
        .PSEL(PSEL),.PENABLE(PENABLE),.PWRITE(PWRITE),
        .PADDR(PADDR),.PWDATA(PWDATA),.PRDATA(PRDATA),.PREADY(PREADY));
    apb_decoder u_apbdec (.PSEL(PSEL),.PENABLE(PENABLE),.PWRITE(PWRITE),
        .PADDR(PADDR),.PWDATA(PWDATA),.PRDATA(PRDATA),.PREADY(PREADY),
        .gpio_PSEL(gpio_PSEL),.gpio_PRDATA(gpio_PRDATA),.gpio_PREADY(gpio_PREADY),
        .uart_PSEL(uart_PSEL),.uart_PRDATA(uart_PRDATA),.uart_PREADY(uart_PREADY),
        .spi_PSEL(spi_PSEL),.spi_PRDATA(spi_PRDATA),.spi_PREADY(spi_PREADY),
        .p_PENABLE(p_PENABLE),.p_PWRITE(p_PWRITE),.p_PADDR(p_PADDR),.p_PWDATA(p_PWDATA));
    apb_gpio #(.NUM_IO(NUM_IO)) u_gpio (.PCLK(clk),.PRESETn(rst_n),
        .PSEL(gpio_PSEL),.PENABLE(p_PENABLE),.PWRITE(p_PWRITE),
        .PADDR(p_PADDR),.PWDATA(p_PWDATA),.PRDATA(gpio_PRDATA),.PREADY(gpio_PREADY),
        .gpio_out(gpio_out),.gpio_in(gpio_in));
    apb_uart #(.CLK_FREQ(CLK_FREQ),.BAUD_RATE(BAUD_RATE)) u_uart (.PCLK(clk),.PRESETn(rst_n),
        .PSEL(uart_PSEL),.PENABLE(p_PENABLE),.PWRITE(p_PWRITE),
        .PADDR(p_PADDR),.PWDATA(p_PWDATA),.PRDATA(uart_PRDATA),.PREADY(uart_PREADY),
        .tx(tx),.rx(rx));

    initial clk=0; always #5 clk=~clk;

    always @(posedge clk) begin
        #1;
        $display("t=%0t req=%b gnt=%b | HSEL=%b slvHADDR=0x%05h slvHWRITE=%b | PSEL=%b PEN=%b PWRITE=%b PADDR=0x%05h PWDATA=0x%08h | u_PSEL=%b tx=%b",
            $time, req, gnt, HSEL, slv_HADDR[19:0], slv_HWRITE, PSEL, PENABLE, PWRITE, PADDR[19:0], PWDATA, uart_PSEL, tx);
    end

    initial begin
        req=0;we=0;be=0;addr=0;wdata=0;gpio_in=0; rst_n=0;
        repeat(3) @(posedge clk); @(negedge clk); rst_n=1; repeat(2) @(posedge clk);
        $display("---- WRITE UART 0x00020000 = 0x41 (only) ----");
        @(negedge clk);
        req=1; we=1; be=4'hF; addr=32'h0002_0000; wdata=32'h0000_0041;
        @(posedge clk); while(gnt!==1'b1) @(posedge clk);
        @(negedge clk); req=0; we=0;
        repeat(20) @(negedge clk);   // watch the APB transfer + start of TX
        $finish;
    end
endmodule
