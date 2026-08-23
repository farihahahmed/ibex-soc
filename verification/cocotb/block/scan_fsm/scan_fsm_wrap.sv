// Integration DUT: scan_chain drives test_fsm (chip-faithful wiring).
module scan_fsm_wrap (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       scan_in,
    input  logic       scan_shift,
    input  logic       scan_load,
    input  logic       scan_i0o1,
    output logic       scan_out,
    output logic       cpu_clk,
    output logic       scan_owns_mem,
    output logic [1:0] mode_o
);
    logic        mem_we;
    logic [15:0] mem_addr;
    logic [31:0] mem_wdata;
    logic        fsm_cfg_load;
    logic [1:0]  fsm_mode;
    logic [15:0] fsm_count;
    logic        clk_cfg_load;
    logic        clk_int;
    logic [7:0]  clk_div;

    scan_chain u_scan (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(32'b0),
        .fsm_cfg_load(fsm_cfg_load), .fsm_mode(fsm_mode), .fsm_count(fsm_count),
        .clk_cfg_load(clk_cfg_load), .clk_int(clk_int), .clk_div(clk_div)
    );

    test_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .cfg_load(fsm_cfg_load), .cfg_mode_in(fsm_mode), .cfg_count_in(fsm_count),
        .cpu_clk(cpu_clk), .scan_owns_mem(scan_owns_mem), .mode_o(mode_o)
    );
endmodule
