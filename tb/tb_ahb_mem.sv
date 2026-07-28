// ============================================================================
// tb_ahb_mem.sv - test my AHB bus with REAL memory on slave 0
//
// Now slave 0 is a real ahb_mem (with SRAM read latency + HREADY stall), and
// GPIO is real on slave 1. Slaves 2/3 are distinct-signature stubs.
//
// The hard part I'm testing: memory STALLS the bus (HREADY low for a cycle on
// reads), GPIO does NOT. Interleaving a stalling slave with a zero-wait one is
// exactly where AHB timing bugs hide. I check:
//   1. Write memory through the bus, read it back (proves the stall works).
//   2. Multiple memory addresses (proves addressing through the bus).
//   3. Interleave memory <-> GPIO <-> stub (proves the bus handles mixed timing).
// ============================================================================

`timescale 1ns/1ps

module tb_ahb_mem;

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
        .s0_HRDATA(s0_HRDATA), .s0_HREADY(s0_HREADY), .s0_HRESP(s0_HRESP),  // real memory
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP),  // real GPIO
        .s2_HRDATA(32'hDEAD_0002), .s2_HREADY(1'b1), .s2_HRESP(1'b0),       // stub
        .s3_HRDATA(32'hDEAD_0003), .s3_HREADY(1'b1), .s3_HRESP(1'b0)        // stub
    );

    // real memory on slave 0
    ahb_mem u_mem (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[0]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWSTRB(4'hF),                 // full-word writes in this test.
        .HWDATA(slv_HWDATA),
        .HRDATA(s0_HRDATA), .HREADY(s0_HREADY), .HRESP(s0_HRESP)
    );

    // real GPIO on slave 1
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
        $dumpfile("tb_ahb_mem.vcd");
        $dumpvars(0, tb_ahb_mem);
    end

    integer errors;
    logic [31:0] r_expected;
    logic        r_pending;

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

    // NOTE: because memory can stall (HREADY low), a write's address phase must
    // be held until HREADY is high. I keep req asserted and only advance when
    // the bus is ready. gnt from the adapter already means "accepted + ready".
    task bus_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk);
            req = 1; we = 1; be = 4'hF; addr = a; wdata = d;
            // wait until the access is granted (adapter asserts gnt when HREADY)
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
        errors = 0; r_pending = 0; r_expected = 0;
        rst_n = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n = 1;
        repeat (2) @(posedge clk);

        // ---- TEST 1: write + read memory through the bus ----
        $display("TEST 1: write and read data memory through the bus");
        bus_write(32'h0000_0000, 32'h1111_1111);   // mem word 0
        bus_write(32'h0000_0004, 32'h2222_2222);   // mem word 1
        bus_write(32'h0000_0010, 32'h3333_3333);   // mem word 4
        bus_read (32'h0000_0000, 32'h1111_1111);
        bus_read (32'h0000_0004, 32'h2222_2222);
        bus_read (32'h0000_0010, 32'h3333_3333);

        // ---- TEST 2: GPIO still works ----
        $display("TEST 2: GPIO write/read still works");
        bus_write(32'h0001_0000, 32'h0000_00A5);
        repeat (2) @(posedge clk); #1;
        if (gpio_out !== 8'hA5) begin
            errors = errors + 1;
            $display("  FAIL: gpio_out expected 0xA5, got 0x%02h", gpio_out);
        end

        // ---- TEST 3: interleave stalling memory with zero-wait slaves ----
        $display("TEST 3: interleave memory <-> GPIO <-> stub");
        gpio_in = 8'h5A;
        repeat (3) @(posedge clk);
        bus_read (32'h0000_0000, 32'h1111_1111);    // memory (stalls)
        bus_read (32'h0001_0000, 32'h0000_005A);    // GPIO (no stall)
        bus_read (32'h0003_0000, 32'hDEAD_0003);    // stub (no stall)
        bus_read (32'h0000_0004, 32'h2222_2222);    // memory again (stalls)

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
