// ============================================================================
// mem_wrapper.sv
// This is my translator. Ibex talks in a request/grant/valid handshake, but my
// sram_bank_2k just wants simple cs/we/addr signals. This file sits in between
// and converts one language into the other.
//
// Ibex's side (the "handshake" language it speaks to me):
//   req    - Ibex saying "I want to access memory this cycle"
//   gnt    - me saying "ok, request accepted". My bank is always ready, so gnt = req.
//   we     - Ibex: 1 = write, 0 = read
//   be     - Ibex: byte-enables (which bytes it wants to write)
//   addr   - Ibex: a BYTE address. I convert this to a word address for my bank.
//   wdata  - Ibex: the data it wants to write
//   rvalid - me saying "your read data is valid THIS cycle". It's req delayed by 1.
//   rdata  - me handing back the read data (straight from my bank)
//
// My bank's side (the simple "SRAM" language): cs / we / be / addr / wdata / rdata,
// where rdata shows up one cycle after I present the address.
//
// This wrapper is tiny on purpose: mostly it just passes signals through and
// converts the address. The one clever bit is generating rvalid with a single
// flip-flop that delays req by exactly one cycle - which lines up perfectly
// with my bank's one-cycle read latency.
// ============================================================================

module mem_wrapper (
    input  logic        clk,          // clock in.
    input  logic        rst_n,        // reset, active-low. 0 = I'm being reset, 1 = normal running.

    // ---- the Ibex handshake side ----
    input  logic        req,          // Ibex is asking for a memory access this cycle.
    output logic        gnt,          // I grant the access (tell Ibex "accepted").
    input  logic        we,           // 1 = Ibex wants to write, 0 = read.
    input  logic [3:0]  be,           // byte enables from Ibex.
    input  logic [31:0] addr,         // BYTE address from Ibex. Note it's the full 32 bits.
    input  logic [31:0] wdata,        // data Ibex wants to write.
    output logic        rvalid,       // I raise this when read data is ready (one cycle after the request).
    output logic [31:0] rdata         // the read data I hand back to Ibex.
);

    // ------------------------------------------------------------------
    // 1) GRANT: my bank is always ready, so I just accept every request instantly.
    //    "assign" makes gnt a live wire that always equals req, same cycle.
    // ------------------------------------------------------------------
    assign gnt = req;                 // accepted the moment Ibex asks. No stalling needed.

    // ------------------------------------------------------------------
    // 2) ADDRESS CONVERSION: Ibex counts memory in BYTES, my bank counts in WORDS.
    //    A word is 4 bytes, so to go from byte address to word address I divide by 4.
    //    Dividing by 4 in binary = dropping the bottom 2 bits. Those 2 bits just pick
    //    which byte inside the word, and my byte-enables already handle that.
    //    So addr[10:2] gives me the 9-bit word index I need (512 words = addresses 0..511).
    // ------------------------------------------------------------------
    logic [8:0] word_addr;            // the 9-bit word address I'll actually feed my bank.
    assign word_addr = addr[10:2];    // take bits 10 down to 2 = byte address / 4 = word index.

    // ------------------------------------------------------------------
    // 3) SELECT: I tell my bank to do something whenever Ibex is requesting.
    //    My bank's cs is active-high, and the bank flips it to the macro's active-low
    //    CEN internally, so I don't have to worry about polarity here.
    // ------------------------------------------------------------------
    logic cs;                         // the chip-select I'll hand my bank.
    assign cs = req;                  // select the bank on any request from Ibex.

    // ------------------------------------------------------------------
    // 4) Drop in my memory bank and wire it up.
    //    The read data comes straight back out to Ibex, unchanged.
    // ------------------------------------------------------------------
    sram_bank_2k u_bank (
        .clk  (clk),                  // my clock straight through.
        .cs   (cs),                   // select the bank when there's a request.
        .we   (we),                   // pass Ibex's write-enable straight through.
        .be   (be),                   // pass the byte-enables straight through.
        .addr (word_addr),            // give it the converted word address (not the raw byte address).
        .wdata(wdata),                // pass the write data straight through.
        .rdata(rdata)                 // the bank's read data goes straight back to Ibex.
    );

    // ------------------------------------------------------------------
    // 5) RVALID: this is the whole point of the wrapper, the tricky timing bit.
    //    My bank returns data ONE cycle after I present the address. So if Ibex makes
    //    a read request this cycle, the data is valid NEXT cycle. I make rvalid mean
    //    "there was a read request on the previous cycle" by pushing req through one flip-flop.
    //
    //    Reminder to self on the syntax:
    //    "always_ff @(posedge clk ...)" = a flip-flop. On each rising clock edge it grabs
    //    the right-hand value and stores it into the left-hand signal.
    //    "<=" is the flip-flop (non-blocking) assignment - I always use <= inside always_ff,
    //    never plain "=".
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid <= 1'b0;           // during reset there's no valid data, so force rvalid to 0.
        end else begin
            rvalid <= req & ~we;      // next cycle, rvalid is 1 if THIS cycle was a read request,
                                      // i.e. req=1 AND we=0. The "& ~we" excludes writes, because
                                      // a write doesn't produce any read data to hand back.
        end
    end

    // Note to self for later: some Ibex configs expect an rvalid pulse for WRITES too,
    // not just reads. Right now I only pulse rvalid for reads (the "& ~we"). If Ibex ever
    // stalls waiting for a write response during integration, I just change the line above
    // to "rvalid <= req;" so I respond to every access. I'll confirm which one my Ibex wants
    // when I actually hook it up.

endmodule
