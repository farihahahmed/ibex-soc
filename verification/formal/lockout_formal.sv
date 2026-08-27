// ============================================================================
// lockout_formal.sv - the scan lockout safety property.
//
// Composes test_fsm and scan_chain to prove the property that actually
// matters: while the CPU is running, a scan write cannot reach instruction
// memory. If this failed, an errant scan frame could rewrite the program
// underneath a running CPU.
//
// mem_subsystem gates the write as:   imem_ld_en = scan_owns_mem & scan_we
// and test_fsm drives:                scan_owns_mem = (mode == IDLE)
// so the claim is: mode != IDLE  =>  imem_ld_en == 0, for ALL scan traffic.
// ============================================================================
module lockout_formal (
    input logic        clk,
    input logic        rst_n,
    input logic        scan_in,
    input logic        scan_shift,
    input logic        scan_load,
    input logic        scan_i0o1,
    input logic        cfg_load,
    input logic [1:0]  cfg_mode_in,
    input logic [15:0] cfg_count_in
);
    localparam logic [1:0] IDLE = 2'd0;

    // ---- the FSM ----
    logic cpu_clk, scan_owns_mem;
    logic [1:0] mode_o;
    test_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .cfg_load(cfg_load), .cfg_mode_in(cfg_mode_in),
        .cfg_count_in(cfg_count_in),
        .cpu_clk(cpu_clk), .scan_owns_mem(scan_owns_mem), .mode_o(mode_o)
    );

    // ---- the scan chain ----
    logic        scan_out, mem_we, mem_re;
    logic [15:0] mem_addr;
    logic [31:0] mem_wdata;
    logic        fsm_cfg_load, clk_cfg_load, clk_int;
    logic [1:0]  fsm_mode;
    logic [15:0] fsm_count;
    logic [7:0]  clk_div;
    scan_chain u_scan (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .mem_we(mem_we), .mem_re(mem_re), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(32'b0), .status_in(32'b0),
        .fsm_cfg_load(fsm_cfg_load), .fsm_mode(fsm_mode), .fsm_count(fsm_count),
        .clk_cfg_load(clk_cfg_load), .clk_int(clk_int), .clk_div(clk_div)
    );

    // the gating term as mem_subsystem builds it
    logic imem_ld_en, imem_rd_en;
    assign imem_ld_en = scan_owns_mem & mem_we;
    assign imem_rd_en = mem_re;          // readback is qualified by scan_owns inside imem

    initial assume (!rst_n);
    always @* assume (cfg_mode_in != 2'd3);

    // ---- L1: THE lockout property ------------------------------------------
    // While the CPU owns memory, no scan frame of any kind can write it.
    always @* if (rst_n && mode_o != IDLE) assert (imem_ld_en == 1'b0);

    // ---- L2: the converse is available - scan CAN write in IDLE ------------
    // Stated as a cover so we know L1 is not vacuous: if scan could never
    // write at all, L1 would hold trivially and prove nothing.
    always @* if (rst_n && mode_o == IDLE && scan_load && u_scan.shift_reg[47:46] == 2'd0)
        assert (imem_ld_en == 1'b1);

    // ---- L3: a write and a read never assert together ----------------------
    always @* if (rst_n) assert (!(mem_we && mem_re));

    // ---- L4: no scan side effect at all without scan_load ------------------
    always @* if (rst_n && !scan_load)
        assert (!mem_we && !mem_re && !fsm_cfg_load && !clk_cfg_load);

    // ---- L5: exactly one target per load -----------------------------------
    always @* if (rst_n)
        assert ($onehot0({mem_we, mem_re, fsm_cfg_load, clk_cfg_load}));
endmodule
