// ============================================================================
// ibex_to_ahb.sv - simple CPU (Ibex/Pico) -> AHB-Lite master.
//
// Correct single-outstanding transfer with wait-state support.
//
// AHB is pipelined: the address phase of cycle N corresponds to the data phase
// of cycle N+1.  Once the address has been accepted (gnt), we MUST drive
// HTRANS = IDLE on every subsequent cycle until the data phase completes
// (HREADY high while inflight).  Leaving HTRANS = NONSEQ while waiting
// re-issues the identical transfer and produces the duplicate accesses that
// were breaking memory, GPIO, UART and SPI.
//
// rvalid is still registered one cycle after the data-phase HREADY so the
// pico_shim / CPU side sees exactly the same latency as before.
// ============================================================================

module ibex_to_ahb (
    input  logic        clk,
    input  logic        rst_n,

    // ---- CPU-side simple memory interface ----
    input  logic        req,
    output logic        gnt,
    input  logic        we,
    input  logic [3:0]  be,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic        rvalid,
    output logic [31:0] rdata,

    // ---- AHB-Lite master ----
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

    // Address/control are driven combinationally.  They are only observed by
    // slaves while HTRANS is NONSEQ; once we switch to IDLE the values are
    // ignored.
    assign HADDR  = addr;
    assign HWRITE = we;
    assign HWSTRB = be;
    assign HWDATA = wdata;          // upstream holds wdata stable until rvalid

    // Present a new address phase only when we are not already waiting for a
    // previous data phase to finish.
    logic inflight;
    assign gnt    = req & ~inflight & HREADY;
    assign HTRANS = (req & ~inflight) ? TRANS_NONSEQ : TRANS_IDLE;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            inflight <= 1'b0;
        else if (gnt)
            inflight <= 1'b1;               // address accepted this cycle
        else if (inflight && HREADY)
            inflight <= 1'b0;               // data phase completed this cycle
    end

    // rvalid pulses the cycle AFTER the data-phase HREADY (identical timing
    // to the previous version).  All of our slaves hold HRDATA stable after
    // completion, so the delayed sample is safe.
    logic data_phase_done;
    assign data_phase_done = inflight & HREADY;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rvalid <= 1'b0;
        else
            rvalid <= data_phase_done;
    end

    assign rdata = HRDATA;

endmodule
