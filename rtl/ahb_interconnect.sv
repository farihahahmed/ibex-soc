// ============================================================================
// ahb_interconnect.sv - my AHB-Lite decoder + response multiplexor
//
// This is the traffic controller. One master (Ibex, via the adapter) talks AHB
// to me, and I fan it out to N slaves (data mem, GPIO, UART, SPI). I do two jobs:
//   1. DECODE: look at HADDR in the address phase, assert HSEL for exactly one slave.
//   2. MUX: route the selected slave's HRDATA / HREADY / HRESP back to the master.
//
// THE KEY AHB TIMING FACT: AHB is pipelined. The address is on the bus ONE CYCLE
// before its data. So I decode HSEL from the address phase, but the read data
// (HRDATA) that comes back belongs to the address from the PREVIOUS cycle. That's
// why I register the selection ("sel_q") by one cycle before I use it to mux the
// response. Control is a cycle ahead of data - same idea as my rvalid flip-flop.
//
// I'm building this for 4 slaves. Slave index:
//   0 = data memory   1 = GPIO   2 = UART   3 = SPI
// The address regions come straight from my memory_map.md.
// ============================================================================

module ahb_interconnect (
    input  logic        HCLK,
    input  logic        HRESETn,

    // ---- from the master (Ibex adapter drives these) ----
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,

    // ---- back to the master ----
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP,

    // ---- to/from the 4 slaves ----
    output logic [3:0]  HSEL,
    output logic [31:0] slv_HADDR,
    output logic [1:0]  slv_HTRANS,
    output logic        slv_HWRITE,
    output logic [31:0] slv_HWDATA,

    input  logic [31:0] s0_HRDATA, input logic s0_HREADY, input logic s0_HRESP,
    input  logic [31:0] s1_HRDATA, input logic s1_HREADY, input logic s1_HRESP,
    input  logic [31:0] s2_HRDATA, input logic s2_HREADY, input logic s2_HRESP,
    input  logic [31:0] s3_HRDATA, input logic s3_HREADY, input logic s3_HRESP
);

    assign slv_HADDR  = HADDR;
    assign slv_HTRANS = HTRANS;
    assign slv_HWRITE = HWRITE;
    assign slv_HWDATA = HWDATA;

    logic        active;
    logic [1:0]  region;

    assign active = HTRANS[1];
    assign region = HADDR[17:16];

    always_comb begin
        HSEL = 4'b0000;
        if (active) begin
            HSEL[region] = 1'b1;
        end
    end

    logic [1:0] region_q;
    logic       active_q;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            region_q <= 2'b00;
            active_q <= 1'b0;
        end else begin
            region_q <= region;
            active_q <= active;
        end
    end

    always_comb begin
        if (!active_q) begin
            // no transfer in the prior address phase -> idle: always ready.
            HRDATA = 32'h0; HREADY = 1'b1; HRESP = 1'b0;
        end else
        case (region_q)
            2'b00: begin HRDATA = s0_HRDATA; HREADY = s0_HREADY; HRESP = s0_HRESP; end
            2'b01: begin HRDATA = s1_HRDATA; HREADY = s1_HREADY; HRESP = s1_HRESP; end
            2'b10: begin HRDATA = s2_HRDATA; HREADY = s2_HREADY; HRESP = s2_HRESP; end
            2'b11: begin HRDATA = s3_HRDATA; HREADY = s3_HREADY; HRESP = s3_HRESP; end
            default: begin HRDATA = 32'h0; HREADY = 1'b1; HRESP = 1'b0; end
        endcase
    end

endmodule
