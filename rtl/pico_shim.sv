// ============================================================================
// pico_shim.sv - PicoRV32 unified memory port -> two existing CPU-side buses.
// Demuxes Pico's single mem port by mem_instr:
//   fetch  -> mem_subsystem (imem)   |   data -> ibex_to_ahb -> AHB bus
// ============================================================================
module pico_shim (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        mem_valid,
    input  logic        mem_instr,
    output logic        mem_ready,
    input  logic [31:0] mem_addr,
    input  logic [31:0] mem_wdata,
    input  logic [3:0]  mem_wstrb,
    output logic [31:0] mem_rdata,

    output logic        instr_req,
    input  logic        instr_gnt,
    output logic [31:0] instr_addr,
    input  logic        instr_rvalid,
    input  logic [31:0] instr_rdata,

    output logic        data_req,
    input  logic        data_gnt,
    output logic        data_we,
    output logic [3:0]  data_be,
    output logic [31:0] data_addr,
    output logic [31:0] data_wdata,
    input  logic        data_rvalid,
    input  logic [31:0] data_rdata
);
    logic inflight, sel_instr;
    logic launch;
    assign launch = mem_valid & ~inflight & ~mem_ready;

    logic want_instr;
    assign want_instr = mem_instr;

    assign instr_req  = (launch & want_instr) | (inflight & sel_instr);
    assign instr_addr = mem_addr;

    assign data_req   = (launch & ~want_instr) | (inflight & ~sel_instr);
    assign data_we    = |mem_wstrb;
    assign data_be    = mem_wstrb;
    assign data_addr  = mem_addr;
    assign data_wdata = mem_wdata;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            inflight  <= 1'b0;
            sel_instr <= 1'b0;
        end else if (launch) begin
            inflight  <= 1'b1;
            sel_instr <= want_instr;
        end else if (mem_ready) begin
            inflight  <= 1'b0;
        end
    end

    logic done;
    assign done = inflight & (sel_instr ? instr_rvalid : data_rvalid);
    assign mem_ready = done;
    assign mem_rdata = sel_instr ? instr_rdata : data_rdata;
endmodule
