// ============================================================================
// fabric_formal.sv - AHB decode and response multiplexing.
//
// The interconnect must select exactly one slave and return that slave's
// response. Selecting two would let both drive the bus; muxing the wrong one
// returns another peripheral's data to the CPU with no error indication.
// ============================================================================
module fabric_formal (
    input logic        HCLK, HRESETn,
    input logic [31:0] HADDR, HWDATA,
    input logic [1:0]  HTRANS,
    input logic        HWRITE,
    input logic [31:0] s0_HRDATA, s1_HRDATA, s2_HRDATA, s3_HRDATA,
    input logic        s0_HREADY, s1_HREADY, s2_HREADY, s3_HREADY,
    input logic        s0_HRESP,  s1_HRESP,  s2_HRESP,  s3_HRESP
);
    logic [31:0] HRDATA, slv_HADDR, slv_HWDATA;
    logic        HREADY, HRESP, slv_HWRITE;
    logic [1:0]  slv_HTRANS;
    logic [3:0]  HSEL;
    ahb_interconnect dut (.*);

    initial assume (!HRESETn);
    always @* assume (HRESETn);

    // F1: at most one slave is ever selected. Two would contend on the bus.
    always @* if (HRESETn) assert ($onehot0(HSEL));

    // F2: no slave is selected unless the transfer is real. HTRANS[1] low
    // means IDLE or BUSY, which must not reach a peripheral.
    always @* if (HRESETn && !HTRANS[1]) assert (HSEL == 4'b0);

    // F3: a real transfer always selects exactly one slave. The decode is two
    // bits wide, so every address maps somewhere - there is no unmapped hole.
    always @* if (HRESETn && HTRANS[1]) assert ($onehot(HSEL));

    // F4: address and control reach the slaves unmodified.
    always @* assert (slv_HADDR  == HADDR);
    always @* assert (slv_HWDATA == HWDATA);
    always @* assert (slv_HWRITE == HWRITE);
    always @* assert (slv_HTRANS == HTRANS);

    // F5: the response mux follows the REGISTERED selection, because AHB is
    // pipelined - the data returning now belongs to last cycle's address.
    always @* if (HRESETn && dut.region_q == 2'd0) assert (HRDATA == s0_HRDATA);
    always @* if (HRESETn && dut.region_q == 2'd1) assert (HRDATA == s1_HRDATA);
    always @* if (HRESETn && dut.region_q == 2'd2) assert (HRDATA == s2_HRDATA);
    always @* if (HRESETn && dut.region_q == 2'd3) assert (HRDATA == s3_HRDATA);
endmodule
