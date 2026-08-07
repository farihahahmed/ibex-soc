// ============================================================================
// tb_apb_spi.sv - SPI on the full two-tier bus, alongside GPIO and UART.
// All three peripherals on APB now: GPIO @0x0001, UART @0x0002, SPI @0x0003.
// MOSI looped to MISO, so a byte sent through the bus to SPI comes back and I
// read it via the bus. Proves the decoder routes to slave 3 and SPI works end-to-end.
// ============================================================================
`timescale 1ns/1ps
module tb_apb_spi;
    localparam int NUM_IO=8, CLK_FREQ=8, BAUD_RATE=1, CLK_DIV=2;
    logic clk, rst_n;
    logic        req, gnt, we, rvalid;
    logic [3:0]  be; logic [31:0] addr, wdata, rdata;
    logic [31:0] HADDR, HWDATA, HRDATA; logic [1:0] HTRANS;
    logic HWRITE, HREADY, HRESP; logic [3:0] HWSTRB;
    logic [3:0] HSEL; logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0] slv_HTRANS; logic slv_HWRITE;
    logic [31:0] br_HRDATA; logic br_HREADY, br_HRESP;
    logic PSEL, PENABLE, PWRITE, PREADY; logic [31:0] PADDR, PWDATA, PRDATA;
    logic gpio_PSEL, uart_PSEL, spi_PSEL;
    logic [31:0] gpio_PRDATA, uart_PRDATA, spi_PRDATA;
    logic gpio_PREADY, uart_PREADY, spi_PREADY;
    logic p_PENABLE, p_PWRITE; logic [31:0] p_PADDR, p_PWDATA;
    logic [NUM_IO-1:0] gpio_out, gpio_in;
    logic tx, rx; assign rx=tx;
    logic sclk, mosi, miso, cs_n; assign miso = mosi;   // SPI loopback

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
        .s3_HRDATA(br_HRDATA),.s3_HREADY(br_HREADY),.s3_HRESP(br_HRESP));
    // bridge selected for ANY peripheral region (slave 1, 2, or 3)
    ahb_to_apb u_bridge (.HCLK(clk),.HRESETn(rst_n),.HSEL(HSEL[1]|HSEL[2]|HSEL[3]),
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
    apb_spi #(.CLK_DIV(CLK_DIV)) u_spi (.PCLK(clk),.PRESETn(rst_n),
        .PSEL(spi_PSEL),.PENABLE(p_PENABLE),.PWRITE(p_PWRITE),
        .PADDR(p_PADDR),.PWDATA(p_PWDATA),.PRDATA(spi_PRDATA),.PREADY(spi_PREADY),
        .sclk(sclk),.mosi(mosi),.miso(miso),.cs_n(cs_n));

    initial clk=0; always #5 clk=~clk;
    initial begin $dumpfile("tb_apb_spi.vcd"); $dumpvars(0, tb_apb_spi); end

    integer errors, guard;
    logic [31:0] read_val; logic r_pending;
    always @(posedge clk) begin
        #1; if (rvalid && r_pending) begin read_val=rdata; r_pending=0; end
    end
    task settle; repeat(4) @(negedge clk); endtask
    task bus_write(input [31:0] a, input [31:0] d);
        begin @(negedge clk); req=1;we=1;be=4'hF;addr=a;wdata=d;
        @(posedge clk); while(gnt!==1'b1) @(posedge clk);
        @(negedge clk); req=0;we=0;be=0; settle; end
    endtask
    task bus_read(input [31:0] a);
        begin @(negedge clk); r_pending=1; req=1;we=0;be=0;addr=a;
        @(posedge clk); while(gnt!==1'b1) @(posedge clk);
        @(negedge clk); req=0; wait(r_pending==0); settle; end
    endtask

    initial begin
        req=0;we=0;be=0;addr=0;wdata=0;gpio_in=0;
        errors=0; r_pending=0; read_val=0; rst_n=0;
        repeat(3) @(posedge clk); @(negedge clk); rst_n=1; repeat(2) @(posedge clk);

        $display("TEST: send 0xA5 to SPI (0x00030000) through the full bus");
        bus_write(32'h0003_0000, 32'h0000_00A5);

        // poll SPI status through the bus until busy (bit0) clears
        $display("  polling SPI until transfer done...");
        guard=0; read_val=32'h1;
        while (read_val[0] === 1'b1 && guard < 500) begin
            bus_read(32'h0003_0000);
            guard=guard+1;
        end
        // read once more to get the final rx byte
        bus_read(32'h0003_0000);
        if (read_val[15:8] !== 8'hA5) begin
            errors=errors+1; $display("  FAIL: SPI rx=0x%02h expected 0xA5 (loopback)", read_val[15:8]);
        end else $display("  OK: SPI looped back 0xA5 through the bus");

        // sanity: GPIO still reachable
        $display("TEST: GPIO still works");
        bus_write(32'h0001_0000, 32'h0000_003C);
        repeat(3) @(posedge clk); #1;
        if (gpio_out !== 8'h3C) begin errors=errors+1; $display("  FAIL: gpio_out=0x%02h", gpio_out); end
        else $display("  OK: GPIO = 0x3C");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED  (0 errors)");
        else           $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");
        repeat(4) @(posedge clk); $finish;
    end
endmodule
