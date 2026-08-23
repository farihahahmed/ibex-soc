// Formal: combo invariants of test_fsm
module test_fsm_formal (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cfg_load,
    input  logic [1:0]  cfg_mode_in,
    input  logic [15:0] cfg_count_in
);
    logic cpu_clk, scan_owns_mem;
    logic [1:0] mode_o;

    test_fsm dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_load(cfg_load),
        .cfg_mode_in(cfg_mode_in),
        .cfg_count_in(cfg_count_in),
        .cpu_clk(cpu_clk),
        .scan_owns_mem(scan_owns_mem),
        .mode_o(mode_o)
    );

    // Invariant: scan_owns_mem iff IDLE (always true from assign)
    always @* assert (scan_owns_mem == (mode_o == 2'd0));
endmodule
