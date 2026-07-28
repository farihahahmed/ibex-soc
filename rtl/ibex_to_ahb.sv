// ============================================================================
// ibex_to_ahb.sv - my bridge from Ibex's protocol to AHB-Lite
//
// Ibex talks req/gnt/rvalid, with address AND data together at request time.
// AHB-Lite talks in two phases: address this cycle, data next cycle.
// This adapter stretches Ibex's one-shot request across AHB's two phases, and
// converts AHB's completion (HREADY) back into gnt/rvalid for Ibex.
//
// The tricky bits:
//   - HWDATA (write data) must appear in the DATA phase, one cycle after the
//     address. So I register Ibex's wdata by one cycle.
//   - rvalid comes back one cycle after the address phase (when the data phase
//     completes), which matches how Ibex expects reads to work.
// ============================================================================

module ibex_to_ahb (
    input  logic        clk,
    input  logic        rst_n,

    // ---- Ibex side (its data port connects here) ----
    input  logic        req,           // Ibex wants an access.
    output logic        gnt,           // I accept it.
    input  logic        we,            // 1 = write, 0 = read.
    input  logic [3:0]  be,            // byte enables (I pass these to HSIZE-ish / slaves).
    input  logic [31:0] addr,          // byte address from Ibex.
    input  logic [31:0] wdata,         // write data from Ibex.
    output logic        rvalid,        // read data valid back to Ibex.
    output logic [31:0] rdata,         // read data back to Ibex.

    // ---- AHB-Lite master side (drives the interconnect) ----
    output logic [31:0] HADDR,         // address phase: the address.
    output logic [1:0]  HTRANS,        // address phase: transfer type.
    output logic        HWRITE,        // address phase: write flag.
    output logic [3:0]  HWSTRB,        // byte-strobes (which bytes to write).
    output logic [31:0] HWDATA,        // data phase: the write data (one cycle later).
    input  logic [31:0] HRDATA,        // data phase: read data from the bus.
    input  logic        HREADY,        // 1 = the bus/slave finished the transfer.
    input  logic        HRESP          // 0 = OKAY, 1 = ERROR (I ignore errors for now).
);

    // AHB HTRANS encodings I use:
    localparam logic [1:0] TRANS_IDLE   = 2'b00;   // nothing happening.
    localparam logic [1:0] TRANS_NONSEQ = 2'b10;   // a single real transfer.

    // --------------------------------------------------------------------
    // 1) ADDRESS PHASE. When Ibex requests, I put its address and control on the
    //    AHB bus this cycle. When it's not requesting, I drive IDLE.
    // --------------------------------------------------------------------
    assign HADDR  = addr;                          // the address Ibex gave me.
    assign HTRANS = req ? TRANS_NONSEQ : TRANS_IDLE; // real transfer only when requesting.
    assign HWRITE = we;                            // write vs read.
    assign HWSTRB = be;                            // which bytes (for writes).

    // GRANT: I accept Ibex's request when the bus is ready (HREADY high means it's
    // not stalled and can take my address phase this cycle).
    assign gnt = req & HREADY;

    // --------------------------------------------------------------------
    // 2) DATA PHASE for writes. The write data must appear ONE CYCLE after the
    //    address. So I register wdata (and a "was that a write?" flag) by a cycle.
    // --------------------------------------------------------------------
    logic [31:0] wdata_q;              // Ibex's wdata, delayed one cycle.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wdata_q <= 32'h0;
        else if (req & HREADY & we) wdata_q <= wdata;  // capture on an accepted write.
    end
    assign HWDATA = wdata_q;           // present it in the data phase.

    // --------------------------------------------------------------------
    // 3) READ RESPONSE back to Ibex. A read accepted this cycle has its data one
    //    cycle later, when the data phase completes. I track "a read is in flight"
    //    and raise rvalid when that data phase lands.
    // --------------------------------------------------------------------
    logic read_pending;                // did I accept a read last cycle?
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) read_pending <= 1'b0;
        else        read_pending <= req & HREADY & ~we;  // accepted read this cycle -> valid next.
    end

    assign rvalid = read_pending & HREADY;  // read data is valid when the data phase completes.
    assign rdata  = HRDATA;                 // pass the bus read data straight to Ibex.

endmodule
