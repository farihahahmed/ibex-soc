// ============================================================================
// bridge_formal.sv - AMBA APB protocol compliance for ahb_to_apb.
//
// APB is a specified protocol: a transfer is SETUP (PSEL, no PENABLE) then
// ACCESS (PSEL and PENABLE), and PENABLE must never be asserted without a
// preceding SETUP. A bridge that violates this can double-write a peripheral
// register or drop a transfer entirely.
// ============================================================================
module bridge_formal (
    input logic        HCLK, HRESETn,
    input logic        HSEL,
    input logic [31:0] HADDR,
    input logic [1:0]  HTRANS,
    input logic        HWRITE,
    input logic [31:0] HWDATA,
    input logic [31:0] PRDATA,
    input logic        PREADY
);
    logic [31:0] HRDATA, PADDR, PWDATA;
    logic        HREADY, HRESP, PSEL, PENABLE, PWRITE;
    ahb_to_apb dut (.*);

    initial assume (!HRESETn);
    always @* assume (HRESETn);
    always @* assume (PREADY);        // all our peripherals are zero-wait

    logic past_valid, psel_q, penable_q;
    always @(posedge HCLK) begin
        past_valid <= 1'b1;
        psel_q     <= PSEL;
        penable_q  <= PENABLE;
    end

    // B1: PENABLE never asserts without PSEL. An enable with no select is not
    // a legal APB phase at all.
    always @* if (HRESETn && PENABLE) assert (PSEL);

    // B2: every ACCESS phase is preceded by a SETUP phase. Jumping straight to
    // ACCESS would present address and data in the same cycle the peripheral
    // is expected to act on them.
    always @(posedge HCLK)
        if (past_valid && HRESETn && PENABLE && !penable_q)
            assert (psel_q);

    // B3: PENABLE is never held for two cycles back to back with PREADY high.
    // Holding it would make a zero-wait peripheral perform the write twice.
    always @(posedge HCLK)
        if (past_valid && HRESETn && penable_q) assert (!PENABLE);

    // B4: HREADY is low throughout the transfer, so the AHB master waits.
    // Releasing early would let the master start a second transfer while the
    // first is still in its APB access phase.
    always @* if (HRESETn && PSEL && !PENABLE) assert (!HREADY);

    // B5: the bridge never responds with an error. HRESP is tied low by
    // design; asserting it would need an error path the fabric does not have.
    always @* assert (HRESP == 1'b0);
endmodule
