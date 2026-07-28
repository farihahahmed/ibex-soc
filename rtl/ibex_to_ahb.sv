// ============================================================================
// ibex_to_ahb.sv - Ibex protocol -> AHB-Lite master (rvalid aligned to data)
//
// Handles stalling slaves. The subtlety fixed here: the interconnect registers
// its response selection by one cycle (correct AHB pipelining), so read data on
// HRDATA/rdata arrives ONE CYCLE after HREADY completes the transfer. So I must
// assert rvalid the cycle the data is actually present - which is one cycle after
// the address phase completes. I register a "data coming next cycle" flag and use
// it to time rvalid to the data.
// ============================================================================

module ibex_to_ahb (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        req,
    output logic        gnt,
    input  logic        we,
    input  logic [3:0]  be,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic        rvalid,
    output logic [31:0] rdata,

    output logic [31:0] HADDR,
    output logic [1:0]  HTRANS,
    output logic        HWRITE,
    output logic [3:0]  HWSTRB,
    output logic [31:0] HWDATA,
    input  logic [31:0] HRDATA,
    input  logic        HREADY,
    input  logic        HRESP
);

    localparam logic [1:0] TRANS_IDLE   = 2'b00;
    localparam logic [1:0] TRANS_NONSEQ = 2'b10;

    assign HADDR  = addr;
    assign HTRANS = req ? TRANS_NONSEQ : TRANS_IDLE;
    assign HWRITE = we;
    assign HWSTRB = be;

    assign gnt = req & HREADY;

    // write data one cycle after accepted address phase.
    logic [31:0] wdata_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) wdata_q <= 32'h0;
        else if (gnt & we) wdata_q <= wdata;
    end
    assign HWDATA = wdata_q;

    // Read completion tracking, timed to when the DATA is actually present.
    // When a read address phase is accepted (gnt & ~we), the transfer's data
    // phase completes when HREADY next goes high; the interconnect then presents
    // the data ONE more cycle later. So:
    //   read_accepted : the cycle the read address phase is granted.
    //   read_done     : the cycle HREADY completes the data phase (data valid
    //                   on HRDATA the NEXT cycle due to interconnect register).
    // I pulse rvalid the cycle the data is actually on rdata.
    logic read_inflight;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)              read_inflight <= 1'b0;
        else if (gnt & ~we)      read_inflight <= 1'b1;
        else if (HREADY)         read_inflight <= 1'b0;
    end

    // the data phase completes this cycle when a read is in flight and HREADY=1.
    logic data_phase_done;
    assign data_phase_done = read_inflight & HREADY;

    // the interconnect delivers the data one cycle after that, so register the
    // "valid" pulse by one cycle to line rvalid up with rdata.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rvalid <= 1'b0;
        else        rvalid <= data_phase_done;
    end

    assign rdata = HRDATA;

endmodule
