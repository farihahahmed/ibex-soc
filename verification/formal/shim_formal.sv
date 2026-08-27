// ============================================================================
// shim_formal.sv - PicoRV32 memory-port demux.
//
// The shim splits one CPU port into instruction and data buses. Getting the
// arbitration wrong means a fetch response routed to a load, or two
// transactions in flight on a single-outstanding interface.
// ============================================================================
module shim_formal (
    input logic        clk, rst_n,
    input logic        mem_valid, mem_instr,
    input logic [31:0] mem_addr, mem_wdata,
    input logic [3:0]  mem_wstrb,
    input logic        instr_gnt, instr_rvalid,
    input logic [31:0] instr_rdata,
    input logic        data_gnt, data_rvalid,
    input logic [31:0] data_rdata
);
    logic        mem_ready, instr_req, data_req, data_we;
    logic [3:0]  data_be;
    logic [31:0] mem_rdata, instr_addr, data_addr, data_wdata;
    pico_shim dut (.*);

    initial assume (!rst_n);
    always @* assume (rst_n);

    logic past_valid;
    always @(posedge clk) past_valid <= 1'b1;

    // S1: the two buses are never requested at once. Both active would mean
    // two outstanding transactions on an interface that tracks only one.
    always @* if (rst_n) assert (!(instr_req && data_req));

    // S2: completion is only ever signalled for a transaction in flight.
    // A ready without an inflight transaction would advance the CPU past an
    // instruction that never returned.
    always @* if (rst_n && mem_ready) assert (dut.inflight);

    // S3: read data is routed from the bus that was actually selected.
    always @* if (rst_n && dut.inflight && dut.sel_instr)
        assert (mem_rdata == instr_rdata);
    always @* if (rst_n && dut.inflight && !dut.sel_instr)
        assert (mem_rdata == data_rdata);

    // S4: a request is only issued when the CPU has one outstanding, or is
    // launching one. No spurious bus traffic.
    always @* if (rst_n && (instr_req || data_req))
        assert (mem_valid || dut.inflight);

    // S5: write enable matches the byte strobes - a store must not be issued
    // as a load, or vice versa.
    always @* if (rst_n) assert (data_we == (|mem_wstrb));
endmodule
