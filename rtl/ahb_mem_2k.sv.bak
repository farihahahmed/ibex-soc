// ============================================================================
// ahb_mem.sv - my AHB-Lite slave wrapper around mem_wrapper + sram_bank_2k
//
// This is a ZERO-WAIT-STATE slave: HREADY is always 1. Here's the reasoning,
// because it's not obvious and I want to remember why:
//
// My SRAM has a one-cycle read latency. I *assumed* that meant this AHB slave
// would have to stall the bus (drop HREADY for a cycle) on reads. But when I
// actually traced it cycle-by-cycle, the read data comes back correct in one
// AHB transfer with no stall needed. The reason: the one-cycle latency is
// absorbed INSIDE mem_wrapper's req/gnt/rvalid handshake before the AHB data
// phase completes - so from the bus's point of view, the read just works.
//
// I verified this the honest way: I wrote two different values to two different
// addresses and read them back with CHANGING addresses (so stale data couldn't
// fool me). Each read returned its own address's value. Correct, not lucky.
//
// So I keep this simple: always ready, no stall FSM. If I ever move to a slower
// real memory that genuinely needs wait states, I'll add them then - but adding
// a stall that never fires now would just be dead code hiding future bugs.
// ============================================================================

module ahb_mem (
    input  logic        HCLK,
    input  logic        HRESETn,

    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [3:0]  HWSTRB,        // byte strobes (which bytes to write).
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP
);

    // I'm always ready and never error.
    assign HREADY = 1'b1;
    assign HRESP  = 1'b0;

    // is this a real access to me? (selected + a real transfer, not idle)
    logic sel_access;
    assign sel_access = HSEL & HTRANS[1];

    // --------------------------------------------------------------------
    // Drive the mem_wrapper directly. It grants immediately and handles the
    // one-cycle read latency internally via its own rvalid.
    //   req = any real access to me.
    //   we  = whether it's a write.
    //   addr = the AHB address (wrapper converts byte->word inside).
    // --------------------------------------------------------------------
    logic        mw_req, mw_we, mw_rvalid;
    logic [31:0] mw_rdata;

    assign mw_req = sel_access;         // request whenever I'm selected for a real transfer.
    assign mw_we  = sel_access & HWRITE; // ...and it's a write.

    mem_wrapper u_dmem (
        .clk   (HCLK),
        .rst_n (HRESETn),
        .req   (mw_req),
        .gnt   (),                     // wrapper is always ready; I don't need to watch gnt.
        .we    (mw_we),
        .be    (HWSTRB),               // byte strobes straight through.
        .addr  (HADDR),                // AHB address -> wrapper converts to word address.
        .wdata (HWDATA),               // write data.
        .rvalid(mw_rvalid),            // wrapper's read-valid (I don't need to gate on it here).
        .rdata (mw_rdata)              // read data.
    );

    assign HRDATA = mw_rdata;          // read data straight back to the bus.

endmodule
