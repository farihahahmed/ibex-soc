// ============================================================================
// tb_ahb_bus.sv - STRESS test for my AHB-Lite bus
//
// The weak version only ever hit GPIO, so it never proved the bus ROUTES to the
// right slave. This version proves discrimination:
//   - Each stub slave returns a DISTINCT signature (0xDEAD_000N). If the mux
//     misroutes, I read the wrong signature and fail.
//   - I read every region and confirm I get THAT region's signature.
//   - I write GPIO, read another region, then re-read GPIO -> writes don't leak.
//   - I continuously check HSEL is one-hot (never 2 slaves selected at once).
// ============================================================================

`timescale 1ns/1ps

module tb_ahb_bus;

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
        // stub slaves with DISTINCT signatures so misrouting is caught:
        .s0_HRDATA(32'hDEAD_0000), .s0_HREADY(1'b1), .s0_HRESP(1'b0),  // mem region
        .s1_HRDATA(s1_HRDATA),     .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP), // GPIO (real)
        .s2_HRDATA(32'hDEAD_0002), .s2_HREADY(1'b1), .s2_HRESP(1'b0),  // UART region
        .s3_HRDATA(32'hDEAD_0003), .s3_HREADY(1'b1), .s3_HRESP(1'b0)   // SPI region
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

    initial begin
        $dumpfile("tb_ahb_bus.vcd");
        $dumpvars(0, tb_ahb_bus);
    end

    integer errors;
    logic [31:0] r_expected;
    logic        r_pending;

    // ---- continuous one-hot check on HSEL ----
    // during any real transfer, exactly one slave must be selected. If two bits
    // are ever set, that's a decode bug. ($countones counts the set bits.)
    always @(posedge clk) begin
        #1;
        if (HTRANS[1] && rst_n) begin
            if ($countones(HSEL) > 1) begin
                errors = errors + 1;
                $display("  FAIL: HSEL not one-hot (0x%0h) - multiple slaves selected", HSEL);
            end
        end
    end

    // ---- read-data monitor ----
    always @(posedge clk) begin
        #1;
        if (rvalid && r_pending) begin
            if (rdata !== r_expected) begin
                errors = errors + 1;
                $display("  MISMATCH: got 0x%08h, expected 0x%08h", rdata, r_expected);
            end
            r_pending = 0;
        end
    end

    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 1; be = 4'hF; addr = a; wdata = d;
            @(negedge clk);
            req = 0; we = 0; be = 0;
        end
    endtask

    task bus_read(input [31:0] a, input [31:0] exp);
        begin
            @(negedge clk);
            r_expected = exp; r_pending = 1;
            req = 1; we = 0; be = 0; addr = a;
            @(negedge clk);
            req = 0;
            wait (r_pending == 0);
        end
    endtask

    initial begin
        req = 0; we = 0; be = 0; addr = 0; wdata = 0; gpio_in = 0;
        errors = 0; r_pending = 0; r_expected = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        // ---- TEST 1: routing - each region returns ITS OWN signature ----
        $display("TEST 1: each address region routes to the correct slave");
        bus_read(32'h0000_0000, 32'hDEAD_0000);   // mem region  -> slave 0
        bus_read(32'h0002_0000, 32'hDEAD_0002);   // UART region -> slave 2
        bus_read(32'h0003_0000, 32'hDEAD_0003);   // SPI region  -> slave 3

        // ---- TEST 2: GPIO write reaches the pins ----
        $display("TEST 2: write GPIO region drives the pins");
        bus_write(32'h0001_0000, 32'h0000_00A5);
        repeat (2) @(posedge clk); #1;
        if (gpio_out !== 8'hA5) begin
            errors = errors + 1;
            $display("  FAIL: gpio_out expected 0xA5, got 0x%02h", gpio_out);
        end

        // ---- TEST 3: GPIO read returns inputs ----
        $display("TEST 3: read GPIO region returns input pins");
        gpio_in = 8'h5A;
        repeat (3) @(posedge clk);
        bus_read(32'h0001_0000, 32'h0000_005A);

        // ---- TEST 4: cross-region independence ----
        // read GPIO, then a different region, then GPIO again -> no leakage,
        // and the mux switches correctly between slaves back to back.
        $display("TEST 4: interleave regions - no cross-talk");
        bus_read(32'h0000_0000, 32'hDEAD_0000);   // mem
        bus_read(32'h0001_0000, 32'h0000_005A);   // GPIO still 0x5A
        bus_read(32'h0003_0000, 32'hDEAD_0003);   // SPI
        bus_read(32'h0001_0000, 32'h0000_005A);   // GPIO again, unchanged

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
