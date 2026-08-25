// ============================================================================
// ahb_to_apb.sv - AHB-to-APB bridge (read-data timing fixed)
//
// AHB slave on one side, APB master on the other. IDLE -> SETUP -> ACCESS.
//
// FIXES so far:
//   - Capture HWDATA in the SETUP cycle (the AHB data phase), not too early.
//   - Read data: drive HRDATA COMBINATIONALLY from PRDATA in the ACCESS-complete
//     cycle, so it's present the SAME cycle HREADY goes high. My earlier version
//     registered the read data, which delayed it one cycle past HREADY/rvalid and
//     made the read look invalid. Now HRDATA and HREADY line up.
// ============================================================================

module ahb_to_apb (
    input  logic        HCLK,
    input  logic        HRESETn,

    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP,

    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [31:0] PADDR,
    output logic [31:0] PWDATA,
    input  logic [31:0] PRDATA,
    input  logic        PREADY
);

    assign HRESP = 1'b0;

    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
    state_t state, next_state;

    logic ahb_access;
    assign ahb_access = HSEL & HTRANS[1];

    // capture address + control in the address phase.
    logic [31:0] addr_q;
    logic        write_q;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            addr_q <= 32'h0; write_q <= 1'b0;
        end else if (ahb_access && state == IDLE) begin
            addr_q  <= HADDR;
            write_q <= HWRITE;
        end
    end

    // Capture write data in the SETUP cycle. Note this is NOT the AHB data
    // phase in the strict sense - HREADY stays low in IDLE while ahb_access is
    // high, so the address phase is extended. The capture is still correct
    // because ibex_to_ahb drives HWDATA combinationally from the master, and
    // PicoRV32 holds mem_wdata stable for the whole transaction. A master that
    // pipelined HWDATA would break this.
    logic [31:0] wdata_q;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) wdata_q <= 32'h0;
        else if (state == SETUP) wdata_q <= HWDATA;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:   if (ahb_access) next_state = SETUP;
            SETUP:  next_state = ACCESS;
            ACCESS: if (PREADY) next_state = IDLE;
        endcase
    end

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) state <= IDLE;
        else          state <= next_state;
    end

    always_comb begin
        PSEL    = (state == SETUP) || (state == ACCESS);
        PENABLE = (state == ACCESS);
    end
    assign PWRITE = write_q;
    assign PADDR  = addr_q;
    assign PWDATA = wdata_q;

    // READ DATA: drive HRDATA straight from PRDATA (combinational). During the
    // ACCESS phase PRDATA is valid, and that's the same cycle HREADY completes
    // the transfer - so HRDATA and HREADY line up, and rvalid sees correct data.
    assign HRDATA = PRDATA;

    always_comb begin
        if (state == IDLE && !ahb_access)
            HREADY = 1'b1;
        else if (state == ACCESS && PREADY)
            HREADY = 1'b1;
        else
            HREADY = 1'b0;
    end

endmodule
