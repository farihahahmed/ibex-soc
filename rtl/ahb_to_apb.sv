// ============================================================================
// ahb_to_apb.sv - AHB-to-APB bridge (reworked for correct stalling handshake)
//
// AHB slave on one side, APB master on the other. Translates an AHB transfer
// into APB's SETUP/ACCESS phases, stalling AHB (HREADY low) while APB runs.
//
// KEY FIX vs my first attempt:
//   - AHB write data (HWDATA) is valid in the DATA phase, one cycle AFTER the
//     address phase. My first version grabbed it too early (in IDLE), so PWDATA
//     was always 0. Now I capture the address/control in the address phase, and
//     grab HWDATA on the FIRST bridge-busy cycle (when the data phase is valid).
//   - I hold HREADY low correctly through the whole APB transfer and only raise
//     it (completing the AHB transfer) when APB finishes.
//
// State machine: IDLE -> SETUP -> ACCESS -> IDLE.
//   IDLE   : ready. When AHB selects me, capture address/control, go SETUP.
//   SETUP  : APB setup phase (PSEL=1,PENABLE=0). Also the AHB data phase, so I
//            capture HWDATA here. Always 1 cycle.
//   ACCESS : APB access phase (PSEL=1,PENABLE=1). When PREADY, finish: raise
//            HREADY so the AHB side completes, and grab read data.
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

    // Capture address + control in the ADDRESS phase (when the AHB access arrives
    // while I'm IDLE). These are held stable across the whole APB transfer.
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

    // Capture write DATA in the SETUP cycle. That's one cycle after the address
    // phase = the AHB data phase = when HWDATA is actually valid. THIS is the fix.
    logic [31:0] wdata_q;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) wdata_q <= 32'h0;
        else if (state == SETUP) wdata_q <= HWDATA;   // grab HWDATA in the data phase.
    end

    // Next-state logic.
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

    // APB outputs.
    always_comb begin
        PSEL    = (state == SETUP) || (state == ACCESS);
        PENABLE = (state == ACCESS);
    end
    assign PWRITE = write_q;
    assign PADDR  = addr_q;
    assign PWDATA = wdata_q;

    // Capture read data at APB completion.
    logic [31:0] rdata_q;
    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) rdata_q <= 32'h0;
        else if (state == ACCESS && PREADY) rdata_q <= PRDATA;
    end
    assign HRDATA = rdata_q;

    // HREADY: ready when idle (and not just-selected), or the cycle APB completes.
    // Low while the transfer is in flight -> stalls AHB correctly.
    always_comb begin
        if (state == IDLE && !ahb_access)
            HREADY = 1'b1;
        else if (state == ACCESS && PREADY)
            HREADY = 1'b1;
        else
            HREADY = 1'b0;
    end

endmodule
