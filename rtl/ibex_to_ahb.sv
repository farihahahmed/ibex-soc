// ============================================================================
// ibex_to_ahb.sv - Ibex -> AHB-Lite master. Write-data alignment fixed.
//
// THE FIX: I used to register the write data (wdata_q <= wdata on gnt&we), which
// delayed HWDATA by a cycle. But the APB bridge captures HWDATA in its SETUP
// cycle, which lined up with the OLD registered value - so a write following
// another write sent stale data (e.g. the UART got the previous GPIO byte).
//
// Ibex holds wdata stable while its request is outstanding, so I can just drive
// HWDATA = wdata directly (combinational). That way the write data is valid in
// the data phase exactly when any slave (including the bridge) captures it.
//
// Reads still tracked via read_inflight; rvalid registered to align with the
// interconnect's registered response.
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

    // Write data: drive it directly. Ibex holds wdata stable during the request,
    // so it's valid when a slave captures it in the data phase. No extra register
    // (that register is what caused stale write data on back-to-back writes).
    assign HWDATA = wdata;

    // Read tracking, aligned with the interconnect's registered response.
    logic read_inflight;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)              read_inflight <= 1'b0;
        else if (gnt & ~we)      read_inflight <= 1'b1;
        else if (HREADY)         read_inflight <= 1'b0;
    end

    logic data_phase_done;
    assign data_phase_done = read_inflight & HREADY;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rvalid <= 1'b0;
        else        rvalid <= data_phase_done;
    end

    assign rdata = HRDATA;

endmodule
