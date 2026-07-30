module mem_subsystem (
    input  logic        clk,
    input  logic        rst_n_in,
    input  logic        instr_req_i,
    output logic        instr_gnt_o,
    input  logic [31:0] instr_addr_i,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o,
    input  logic        data_req_i,
    output logic        data_gnt_o,
    input  logic        data_we_i,
    input  logic [3:0]  data_be_i,
    input  logic [31:0] data_addr_i,
    input  logic [31:0] data_wdata_i,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o,
    input  logic        scan_owns_mem,
    input  logic        scan_we,
    input  logic [15:0] scan_addr,
    input  logic [31:0] scan_wdata,
    input  logic        scan_sel_dmem
);
    logic rst_n;
    rst_sync u_rst_sync (
        .clk(clk), .rst_n_in(rst_n_in), .rst_n_out(rst_n)
    );

    // ---- INSTRUCTION memory: narrow 8-bit path ----
    logic imem_ld_en;
    assign imem_ld_en = scan_owns_mem & ~scan_sel_dmem & scan_we;

    imem_narrow_top u_imem (
        .clk(clk), .rst_n(rst_n),
        .req(instr_req_i), .gnt(instr_gnt_o), .addr(instr_addr_i),
        .rvalid(instr_rvalid_o), .rdata(instr_rdata_o),
        .ld_word_en(imem_ld_en), .ld_word_addr(scan_addr),
        .ld_word_data(scan_wdata), .ld_busy()
    );

    // ---- DATA memory: narrow 8-bit path (reads, byte-enable writes) ----
    logic dmem_ld_en;
    assign dmem_ld_en = scan_owns_mem & scan_sel_dmem & scan_we;

    dmem_narrow_top u_dmem (
        .clk(clk), .rst_n(rst_n),
        .req(data_req_i), .gnt(data_gnt_o), .we(data_we_i), .be(data_be_i),
        .addr(data_addr_i), .wdata(data_wdata_i),
        .rvalid(data_rvalid_o), .rdata(data_rdata_o),
        .ld_word_en(dmem_ld_en), .ld_word_addr(scan_addr),
        .ld_word_data(scan_wdata), .ld_busy()
    );
endmodule
