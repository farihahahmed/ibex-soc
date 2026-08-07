// ============================================================================
// tb_apb_uart.sv - test UART through the FULL two-tier bus, with loopback.
//
// Path: AHB master -> ahb_interconnect -> ahb_to_apb bridge -> APB -> apb_uart.
// I loop the uart's tx back into its rx, so a byte the "CPU" writes through the
// bus gets serialized out, looped back, received, and I read it back through the
// bus. That exercises the whole chain end to end.
//
// UART sits in AHB slave-1 region here (0x0001_xxxx) so the bridge (wired to
// slave 1) forwards to it. Tiny baud (8 clocks/bit) for speed.
// ============================================================================

`timescale 1ns/1ps

module tb_apb_uart;

    localparam int CLK_FREQ  = 8;
    localparam int BAUD_RATE = 1;      // 8 clocks/bit.

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

    logic        tx, rx;
    assign rx = tx;                    // loopback.

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
    apb_uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .tx(tx), .rx(rx)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_apb_uart.vcd");
        $dumpvars(0, tb_apb_uart);
    end

    integer errors;
    logic [31:0] r_expected;
    logic        r_pending;
    logic [31:0] read_val;

    always @(posedge clk) begin
        #1;
        if (rvalid && r_pending) begin
            read_val  = rdata;
            r_pending = 0;
        end
    end

    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 1; be = 4'hF; addr = a; wdata = d;
            @(posedge clk);
            while (gnt !== 1'b1) @(posedge clk);
            @(negedge clk);
            req = 0; we = 0; be = 0;
        end
    endtask

    task bus_read(input [31:0] a);
        begin
            @(negedge clk);
            r_pending = 1;
            req = 1; we = 0; be = 0; addr = a;
            @(posedge clk);
            while (gnt !== 1'b1) @(posedge clk);
            @(negedge clk);
            req = 0;
            wait (r_pending == 0);
        end
    endtask

    integer guard;

    initial begin
        req = 0; we = 0; be = 0; addr = 0; wdata = 0;
        errors = 0; r_pending = 0; read_val = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        // ---- write a byte to the UART through the bus (starts TX) ----
        $display("Send 0x41 to UART through AHB->bridge->APB");
        bus_write(32'h0001_0000, 32'h0000_0041);   // 'A'

        // ---- poll the UART status through the bus until rx_valid (bit 1) ----
        $display("Poll for rx_valid through the bus...");
        guard = 0;
        read_val = 0;
        while (read_val[1] !== 1'b1 && guard < 500) begin
            bus_read(32'h0001_0000);
            guard = guard + 1;
        end

        if (read_val[1] !== 1'b1) begin
            errors = errors + 1;
            $display("  FAIL: rx_valid never set (guard=%0d)", guard);
        end else begin
            // bits[15:8] hold the received byte
            if (read_val[15:8] !== 8'h41) begin
                errors = errors + 1;
                $display("  FAIL: got 0x%02h, expected 0x41", read_val[15:8]);
            end else begin
                $display("  OK: byte 0x41 traveled CPU->bus->UART->loopback->UART->bus->CPU");
            end
        end

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED  (0 errors)");
        else
            $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
