// ============================================================================
// gather_formal.sv - interface protocol properties for fetch_gather.
//
// Stated at the port boundary rather than on internal state, so the proof is
// about the contract the rest of the design relies on, not about one encoding.
//
// The property that matters most is G5, bounded liveness: once a fetch is
// granted, data MUST come back. A gather unit that silently stops responding
// wedges the CPU forever, and that is precisely the failure a directed test is
// least likely to produce.
// ============================================================================
module gather_formal (
    input logic        clk, rst_n,
    input logic        c_req,
    input logic [31:0] c_addr,
    input logic        m_gnt, m_rvalid,
    input logic [7:0]  m_rdata
);
    logic        c_gnt, c_rvalid, m_req, m_sel;
    logic [31:0] c_rdata, m_addr;
    fetch_gather dut (.*);

    initial assume (!rst_n);
    always @* assume (rst_n);            // no mid-trace reset
    always @* assume (m_gnt);            // imem_narrow ties m_gnt high

    logic past_valid;
    always @(posedge clk) past_valid <= 1'b1;

    // G1: grant and data never arrive together. A new fetch must not start in
    // the same cycle the previous one completes.
    always @* if (rst_n) assert (!(c_gnt && c_rvalid));

    // G2: a memory request always implies memory is selected. Requesting
    // without selecting would read a disabled SRAM and return garbage.
    always @* if (rst_n && m_req) assert (m_sel);

    // G3: a grant is only ever given when the CPU asked for one.
    always @* if (rst_n && c_gnt) assert (c_req);

    // ---- G4/G5: bounded liveness ------------------------------------------
    // Count cycles since a grant. The unit assembles a word from four byte
    // reads, so data must return well inside 12 cycles.
    logic [4:0] since_gnt;
    logic       waiting;
    always @(posedge clk) begin
        if (!rst_n) begin
            waiting <= 1'b0; since_gnt <= 5'd0;
        end else if (c_gnt) begin
            waiting <= 1'b1; since_gnt <= 5'd0;
        end else if (c_rvalid) begin
            waiting <= 1'b0; since_gnt <= 5'd0;
        end else if (waiting) begin
            since_gnt <= since_gnt + 5'd1;
        end
    end

    // G4: the unit never stalls indefinitely after accepting a fetch.
    always @* if (rst_n && waiting) assert (since_gnt < 5'd12);

    // G5: data is never returned unless a fetch was actually granted.
    // A spurious rvalid would make the CPU latch an instruction it never
    // requested.
    always @(posedge clk)
        if (past_valid && rst_n && c_rvalid) assert (waiting);
endmodule
