module mem_subsystem (
    input  logic        clk,
    input  logic        rst_n_in,
    input  logic        instr_req_i,
    output logic        instr_gnt_o,
    input  logic [31:0] instr_addr_i,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o,
    input  logic        scan_owns_mem,
    input  logic        scan_we,
    input  logic [15:0] scan_addr,
    input  logic [31:0] scan_wdata,
    input  logic        scan_re,
    output logic [31:0] scan_rdata
);
    logic rst_n;
    rst_sync u_rst_sync (
        .clk(clk), .rst_n_in(rst_n_in), .rst_n_out(rst_n)
    );

    // ---- INSTRUCTION memory: narrow 8-bit path ----
    // (Data memory lives in ahb_mem on the AHB bus; the old mem_subsystem dmem
    //  was never used by the CPU, so it has been removed.)
    // Scan writes reach the instruction memory only. Data memory lives in
    // ahb_mem on the AHB bus and is initialised by the CPU at runtime, so there
    // is no scan path to it (an earlier scan_sel_dmem port was inert and has
    // been removed).
    logic imem_ld_en;
    assign imem_ld_en = scan_owns_mem & scan_we;

    imem_narrow_top u_imem (
        .clk(clk), .rst_n(rst_n),
        .req(instr_req_i), .gnt(instr_gnt_o), .addr(instr_addr_i),
        .rvalid(instr_rvalid_o), .rdata(instr_rdata_o),
        .ld_word_en(imem_ld_en), .ld_word_addr(scan_addr),
        .ld_word_data(scan_wdata), .ld_busy(),
        .scan_owns(scan_owns_mem),
        .rd_word_en(scan_re), .rd_word_addr(scan_addr),
        .rd_word_data(scan_rdata), .rd_busy()
    );
endmodule
