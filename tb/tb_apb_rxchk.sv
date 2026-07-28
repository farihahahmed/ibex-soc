// ============================================================================
// tb_apb_rxchk.sv - after a UART write+loopback, do ONE clean read and watch
// both the bus rdata AND the uart's internal rx_valid/rx_data. This tells me if
// the read path returns the received byte correctly (separate from poll-loop mess).
// ============================================================================
`timescale 1ns/1ps
module tb_apb_rxchk;
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

    logic [31:0] read_val; logic r_pending;
    always @(posedge clk) begin
        #1; if (rvalid && r_pending) begin read_val=rdata; r_pending=0; end
    end

    task bus_write(input [31:0] a, input [31:0] d);
        begin @(negedge clk); req=1;we=1;be=4'hF;addr=a;wdata=d;
        @(posedge clk); while(gnt!==1'b1) @(posedge clk);
        @(negedge clk); req=0;we=0;be=0; repeat(3) @(negedge clk); end
    endtask
    task bus_read(input [32:0] a);
        begin @(negedge clk); r_pending=1; req=1;we=0;be=0;addr=a;
        @(posedge clk); while(gnt!==1'b1) @(posedge clk);
        @(negedge clk); req=0; wait(r_pending==0); repeat(3) @(negedge clk); end
    endtask

    initial begin
        req=0;we=0;be=0;addr=0;wdata=0;gpio_in=0; read_val=0; r_pending=0; rst_n=0;
        repeat(3) @(posedge clk); @(negedge clk); rst_n=1; repeat(2) @(posedge clk);

        $display("Write UART 0x41");
        bus_write(32'h0002_0000, 32'h0000_0041);

        // wait for TX to serialize + loopback to receive (10 bits * 8 clocks + margin)
        $display("Waiting for loopback receive...");
        repeat(120) @(negedge clk);

        // peek the uart's internal state directly
        $display("uart internal: rx_valid=%b rx_data=0x%02h", u_uart.u_uart.rx_valid, u_uart.u_uart.rx_data);

        // now read UART through the bus
        $display("Read UART status through bus:");
        bus_read(32'h0002_0000);
        $display("  bus read_val = 0x%08h  -> rx_valid(bit1)=%b rx_data(15:8)=0x%02h tx_busy(bit0)=%b",
                 read_val, read_val[1], read_val[15:8], read_val[0]);

        if (read_val[15:8] === 8'h41)
            $display("  OK: read 0x41 through the bus");
        else
            $display("  MISMATCH: got 0x%02h", read_val[15:8]);

        repeat(4) @(negedge clk); $finish;
    end
endmodule
