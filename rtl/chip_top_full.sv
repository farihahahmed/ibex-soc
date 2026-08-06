// ============================================================================
// chip_top_full.sv - Columbia-style: scan-configured clock-gating FSM +
// on-chip clock generator. 22-pin target (20 signal + 2 power).
// ============================================================================
module chip_top_full import ibex_pkg::*; #(
    parameter int NUM_OUT     = 5,
    parameter int NUM_IN      = 2,
    parameter int CLK_FREQ    = 8,
    parameter int BAUD_RATE   = 1,
    parameter int SPI_CLK_DIV = 2
)(
    input  logic clk,
    input  logic clk_int,
    input  logic rst_n,
    input  logic scan_in,
    input  logic scan_shift,
    input  logic scan_load,
    input  logic scan_i0o1,
    output logic scan_out,
    output logic [NUM_OUT-1:0] gpio_out,
    input  logic [NUM_IN-1:0]  gpio_in,
    output logic uart_tx,
    input  logic uart_rx,
    output logic spi_sclk,
    output logic spi_mosi,
    output logic spi_cs_n
);
    logic        clkgen_cfg_load, clkgen_int;
    logic [7:0]  clkgen_div;
    logic        sys_clk;
    logic        use_internal;
    assign use_internal = clkgen_int & clk_int;
    clk_gen u_clkgen (
        .ref_clk(clk), .clk_ext(clk), .rst_n(rst_n),
        .clk_int(use_internal), .cfg_load(clkgen_cfg_load),
        .cfg_div_in(clkgen_div), .clk_out(sys_clk)
    );

    logic        scan_mem_we;
    logic [15:0] scan_mem_addr;
    logic [31:0] scan_mem_wdata, scan_mem_rdata;
    logic        fsm_cfg_load; logic [1:0] fsm_mode; logic [15:0] fsm_count;
    scan_chain u_scan (
        .clk(sys_clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .mem_we(scan_mem_we), .mem_addr(scan_mem_addr),
        .mem_wdata(scan_mem_wdata), .mem_rdata(scan_mem_rdata),
        .fsm_cfg_load(fsm_cfg_load), .fsm_mode(fsm_mode), .fsm_count(fsm_count),
        .clk_cfg_load(clkgen_cfg_load), .clk_int(clkgen_int), .clk_div(clkgen_div)
    );

    logic cpu_clk, scan_owns_mem;
    logic [1:0] fsm_mode_o;
    test_fsm u_fsm (
        .clk(sys_clk), .rst_n(rst_n),
        .cfg_load(fsm_cfg_load), .cfg_mode_in(fsm_mode), .cfg_count_in(fsm_count),
        .cpu_clk(cpu_clk), .scan_owns_mem(scan_owns_mem), .mode_o(fsm_mode_o)
    );

    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;
    logic        data_req, data_gnt, data_rvalid, data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;
    logic [6:0]  instr_rdata_intg, data_rdata_intg;
    assign instr_rdata_intg = 7'b0;
    assign data_rdata_intg  = 7'b0;

    ibex_top #(
        .PMPEnable(1'b0), .MHPMCounterNum(0), .RV32E(1'b0),
        .RV32M(ibex_pkg::RV32MFast), .RV32B(ibex_pkg::RV32BNone),
        .ICache(1'b0), .DbgTriggerEn(1'b0), .SecureIbex(1'b0)
    ) u_ibex (
        .clk_i(cpu_clk), .rst_ni(rst_n),
        .test_en_i(1'b0), .scan_rst_ni(1'b1),
        .ram_cfg_icache_tag_i ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
        .ram_cfg_icache_tag_o (),
        .ram_cfg_icache_data_i('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
        .ram_cfg_icache_data_o(),
        .hart_id_i(32'b0), .boot_addr_i(32'h0000_0000),
        .instr_req_o(instr_req), .instr_gnt_i(instr_gnt), .instr_rvalid_i(instr_rvalid),
        .instr_addr_o(instr_addr), .instr_rdata_i(instr_rdata),
        .instr_rdata_intg_i(instr_rdata_intg), .instr_err_i(1'b0),
        .data_req_o(data_req), .data_gnt_i(data_gnt), .data_rvalid_i(data_rvalid),
        .data_we_o(data_we), .data_be_o(data_be), .data_addr_o(data_addr),
        .data_wdata_o(data_wdata), .data_wdata_intg_o(),
        .data_rdata_i(data_rdata), .data_rdata_intg_i(data_rdata_intg), .data_err_i(1'b0),
        .irq_software_i(1'b0), .irq_timer_i(1'b0), .irq_external_i(1'b0),
        .irq_fast_i(15'b0), .irq_nm_i(1'b0),
        .scramble_key_valid_i(1'b0), .scramble_key_i('0), .scramble_nonce_i('0), .scramble_req_o(),
        .debug_req_i(1'b0), .crash_dump_o(), .double_fault_seen_o(),
        .fetch_enable_i(ibex_pkg::IbexMuBiOn), .mcounteren_writable_i(ibex_pkg::IbexMuBiOn),
        .alert_minor_o(), .alert_major_internal_o(), .alert_major_bus_o(), .core_sleep_o(),
        .lockstep_cmp_en_o(),
        .data_req_shadow_o(), .data_we_shadow_o(), .data_be_shadow_o(), .data_addr_shadow_o(),
        .data_wdata_shadow_o(), .data_wdata_intg_shadow_o(),
        .instr_req_shadow_o(), .instr_addr_shadow_o()
    );

    mem_subsystem u_mem (
        .clk(sys_clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .scan_owns_mem(scan_owns_mem),
        .scan_we(scan_mem_we), .scan_addr(scan_mem_addr), .scan_wdata(scan_mem_wdata),
        .scan_sel_dmem(1'b0)
    );

    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS;
    logic        HWRITE, HREADY, HRESP;
    logic [3:0]  HWSTRB;
    logic [3:0]  HSEL;
    logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0]  slv_HTRANS;
    logic        slv_HWRITE;
    logic [31:0] s0_HRDATA, s1_HRDATA;
    logic        s0_HREADY, s0_HRESP, s1_HREADY, s1_HRESP;

    ibex_to_ahb u_adapter (
        .clk(cpu_clk), .rst_n(rst_n),
        .req(data_req), .gnt(data_gnt), .we(data_we), .be(data_be),
        .addr(data_addr), .wdata(data_wdata), .rvalid(data_rvalid), .rdata(data_rdata),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWSTRB(HWSTRB),
        .HWDATA(HWDATA), .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP)
    );

    ahb_interconnect u_ic (
        .HCLK(cpu_clk), .HRESETn(rst_n),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .HSEL(HSEL), .slv_HADDR(slv_HADDR), .slv_HTRANS(slv_HTRANS),
        .slv_HWRITE(slv_HWRITE), .slv_HWDATA(slv_HWDATA),
        .s0_HRDATA(s0_HRDATA), .s0_HREADY(s0_HREADY), .s0_HRESP(s0_HRESP),
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(s1_HREADY), .s1_HRESP(s1_HRESP),
        .s2_HRDATA(s1_HRDATA), .s2_HREADY(s1_HREADY), .s2_HRESP(s1_HRESP),
        .s3_HRDATA(s1_HRDATA), .s3_HREADY(s1_HREADY), .s3_HRESP(s1_HRESP)
    );

    ahb_mem u_dmem_slave (
        .HCLK(cpu_clk), .HRESETn(rst_n),
        .HSEL(HSEL[0]), .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWSTRB(HWSTRB), .HWDATA(slv_HWDATA),
        .HRDATA(s0_HRDATA), .HREADY(s0_HREADY), .HRESP(s0_HRESP)
    );

    logic        PSEL, PENABLE, PWRITE, PREADY;
    logic [31:0] PADDR, PWDATA, PRDATA;

    ahb_to_apb u_bridge (
        .HCLK(cpu_clk), .HRESETn(rst_n),
        .HSEL(HSEL[1] | HSEL[2] | HSEL[3]),
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE), .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY)
    );

    logic        gpio_PSEL, uart_PSEL, spi_PSEL;
    logic [31:0] gpio_PRDATA, uart_PRDATA, spi_PRDATA;
    logic        gpio_PREADY, uart_PREADY, spi_PREADY;
    logic        p_PENABLE, p_PWRITE;
    logic [31:0] p_PADDR, p_PWDATA;

    apb_decoder u_apbdec (
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .gpio_PSEL(gpio_PSEL), .gpio_PRDATA(gpio_PRDATA), .gpio_PREADY(gpio_PREADY),
        .uart_PSEL(uart_PSEL), .uart_PRDATA(uart_PRDATA), .uart_PREADY(uart_PREADY),
        .spi_PSEL(spi_PSEL),  .spi_PRDATA(spi_PRDATA),  .spi_PREADY(spi_PREADY),
        .p_PENABLE(p_PENABLE), .p_PWRITE(p_PWRITE), .p_PADDR(p_PADDR), .p_PWDATA(p_PWDATA)
    );

    apb_gpio #(.NUM_OUT(NUM_OUT), .NUM_IN(NUM_IN)) u_gpio (
        .PCLK(cpu_clk), .PRESETn(rst_n),
        .PSEL(gpio_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(gpio_PRDATA), .PREADY(gpio_PREADY),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    apb_uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .PCLK(cpu_clk), .PRESETn(rst_n),
        .PSEL(uart_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(uart_PRDATA), .PREADY(uart_PREADY),
        .tx(uart_tx), .rx(uart_rx)
    );

    apb_spi #(.CLK_DIV(SPI_CLK_DIV)) u_spi (
        .PCLK(cpu_clk), .PRESETn(rst_n),
        .PSEL(spi_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(spi_PRDATA), .PREADY(spi_PREADY),
        .sclk(spi_sclk), .mosi(spi_mosi), .miso(1'b0), .cs_n(spi_cs_n)
    );

endmodule
