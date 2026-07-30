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

    logic [31:0] scan_byte_addr;
    assign scan_byte_addr = {14'b0, scan_addr, 2'b00};

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

    // ---- DATA memory: unchanged ----
    logic        dmem_we;
    logic [3:0]  dmem_be;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_req;

    always_comb begin
        if (scan_owns_mem && scan_sel_dmem) begin
            dmem_req=scan_we; dmem_we=scan_we; dmem_be=4'b1111;
            dmem_addr=scan_byte_addr; dmem_wdata=scan_wdata;
        end else begin
            dmem_req=data_req_i; dmem_we=data_we_i; dmem_be=data_be_i;
            dmem_addr=data_addr_i; dmem_wdata=data_wdata_i;
        end
    end

    mem_wrapper u_dmem (
        .clk(clk), .rst_n(rst_n),
        .req(dmem_req), .gnt(data_gnt_o), .we(dmem_we), .be(dmem_be),
        .addr(dmem_addr), .wdata(dmem_wdata),
        .rvalid(data_rvalid_o), .rdata(data_rdata_o)
    );
endmodule
