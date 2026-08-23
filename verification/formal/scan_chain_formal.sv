// Formal: scan_chain load strobes are gated by scan_load and mutually exclusive
module scan_chain_formal (
    input logic        clk,
    input logic        rst_n,
    input logic        scan_in,
    input logic        scan_shift,
    input logic        scan_load,
    input logic        scan_i0o1
);
    logic        scan_out;
    logic        mem_we;
    logic [15:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        fsm_cfg_load;
    logic [1:0]  fsm_mode;
    logic [15:0] fsm_count;
    logic        clk_cfg_load;
    logic        clk_int;
    logic [7:0]  clk_div;

    assign mem_rdata = 32'h0;

    scan_chain dut (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata),
        .fsm_cfg_load(fsm_cfg_load), .fsm_mode(fsm_mode), .fsm_count(fsm_count),
        .clk_cfg_load(clk_cfg_load), .clk_int(clk_int), .clk_div(clk_div)
    );

    // Loads only when scan_load is high
    always @* assert (!mem_we || scan_load);
    always @* assert (!fsm_cfg_load || scan_load);
    always @* assert (!clk_cfg_load || scan_load);
    // At most one load active (tgt is one-hot among 0/1/2; tgt=3 → none)
    always @* assert ($onehot0({mem_we, fsm_cfg_load, clk_cfg_load}));
endmodule
