// ============================================================================
// tb_apb_bridge.sv - test my full two-tier bus, end to end
//
// The whole chain, for the first time:
//   AHB master (ibex_to_ahb) -> ahb_interconnect -> ahb_to_apb bridge
//                            -> APB bus -> apb_gpio -> pins
//
// GPIO now lives on APB behind the bridge. The bridge is AHB slave 1.
// I check:
//   1. A write to the GPIO region drives the pins (through 2 buses + a bridge).
//   2. A read from the GPIO region returns the input pins.
//   3. HREADY actually DROPS while the bridge runs the APB transfer (the stall
//      is real here - APB genuinely takes extra cycles, unlike the memory case).
// ============================================================================

`timescale 1ns/1ps

module tb_apb_bridge;

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

    // bridge (AHB slave 1) responses
    logic [31:0] s1_HRDATA;
    logic        s1_HREADY, s1_HRESP;

    // APB bus between bridge and apb_gpio
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
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .HSEL(HSEL),
        .slv_HADDR(slv_HADDR), .slv_HTRANS(slv_HTRANS),
        .slv_HWRITE(slv_HWRITE), .slv_HWDATA(slv_HWDATA),
        .s0_HRDATA(32'hDEAD_0000), .s0_HREADY(1'b1), .s0_HRESP(1'b0),  // mem stub
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP), // bridge
        .s2_HRDATA(32'hDEAD_0002), .s2_HREADY(1'b1), .s2_HRESP(1'b0),  // stub
        .s3_HRDATA(32'hDEAD_0003), .s3_HREADY(1'b1), .s3_HRESP(1'b0)   // stub
    );

    // the bridge: AHB slave 1, APB master
    ahb_to_apb u_bridge (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[1]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY)
    );

    // GPIO on APB
    apb_gpio #(.NUM_IO(NUM_IO)) u_gpio (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_apb_bridge.vcd");
        $dumpvars(0, tb_apb_bridge);
    end

    integer errors;
    logic [31:0] r_expected;
    logic        r_pending;
    logic        saw_hready_low;   // did I ever see the bridge stall AHB?

    // watch for HREADY dropping (proves the bridge's wait-state fires)
    always @(posedge clk) begin
        #1;
        if (rst_n && HTRANS[1] && HREADY === 1'b0) saw_hready_low = 1;
    end

    // read-data monitor
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

    // write through the whole chain. Because the bridge stalls (HREADY low),
    // I hold req until gnt (the adapter grants only when HREADY is high).
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

    task bus_read(input [31:0] a, input [31:0] exp);
        begin
            @(negedge clk);
            r_expected = exp; r_pending = 1;
            req = 1; we = 0; be = 0; addr = a;
            @(posedge clk);
            while (gnt !== 1'b1) @(posedge clk);
            @(negedge clk);
            req = 0;
            wait (r_pending == 0);
        end
    endtask

    initial begin
        req = 0; we = 0; be = 0; addr = 0; wdata = 0; gpio_in = 0;
        errors = 0; r_pending = 0; r_expected = 0; saw_hready_low = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        $display("TEST 1: write GPIO region through AHB->bridge->APB->GPIO");
        bus_write(32'h0001_0000, 32'h0000_00A5);
        repeat (3) @(posedge clk); #1;
        if (gpio_out !== 8'hA5) begin
            errors = errors + 1;
            $display("  FAIL: gpio_out expected 0xA5, got 0x%02h", gpio_out);
        end

        $display("TEST 2: read GPIO region back through the whole chain");
        gpio_in = 8'h5A;
        repeat (3) @(posedge clk);
        bus_read(32'h0001_0000, 32'h0000_005A);

        $display("TEST 3: confirm the bridge actually stalled AHB (HREADY went low)");
        if (!saw_hready_low) begin
            errors = errors + 1;
            $display("  FAIL: HREADY never dropped - bridge wait-state never fired");
        end else begin
            $display("  OK: saw HREADY drop - the bridge stall is real");
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
