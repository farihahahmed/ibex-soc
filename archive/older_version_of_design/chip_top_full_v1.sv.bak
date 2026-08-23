// ============================================================================
// chip_top_full.sv - v0.8: the COMPLETE SoC. Everything, unified.
//
// Merges the two earlier tops:
//   - chip_top v0.5: full peripheral set (GPIO+UART+SPI) on the two-tier bus.
//   - chip_top_load v0.6: scan chain + test FSM real load-then-run path.
//
// So this top can: scan-load a program into memory (FSM sequences it), release
// the CPU, and run a program that drives GPIO, UART, and SPI - all in one chip.
//
// Data-side topology (same as v0.5):
//   Ibex data -> ibex_to_ahb -> ahb_interconnect -+-> ahb_mem  (s0, @0x0000)
//                                                  +-> bridge -> apb_decoder -+-> gpio (@0x0001)
//                                                                             +-> uart (@0x0002)
//                                                                             +-> spi  (@0x0003)
// Instruction path: Ibex instr -> mem_subsystem imem, with the scan-load write
// path muxed in (from v0.6). Ibex reset gated by the FSM.
// ============================================================================

module chip_top_full import ibex_pkg::*; #(
    parameter int NUM_IO      = 8,
    parameter int CLK_FREQ    = 8,
    parameter int BAUD_RATE   = 1,
    parameter int SPI_CLK_DIV = 2
)(
    input  logic clk,
    input  logic rst_n,

    // scan / FSM control (chip pads)
    input  logic scan_in,
    input  logic scan_shift,
    input  logic scan_load,
    input  logic scan_capture,
    output logic scan_out,
    input  logic scan_sel_dmem,
    input  logic start,
    input  logic load_done,
    output logic [1:0] fsm_state,

    // peripheral pins
    output logic [NUM_IO-1:0] gpio_out,
    input  logic [NUM_IO-1:0] gpio_in,
    output logic uart_tx,
    input  logic uart_rx,
    output logic spi_sclk,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n
);

    // ---- test FSM: conductor ----
    logic cpu_rst_n_fsm, scan_owns_mem;
    test_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .start(start), .load_done(load_done),
        .cpu_rst_n(cpu_rst_n_fsm), .scan_owns_mem(scan_owns_mem), .state_o(fsm_state)
    );
    logic cpu_rst_n;
    assign cpu_rst_n = rst_n & cpu_rst_n_fsm;

    // ---- scan chain ----
    logic        scan_mem_we;
    logic [15:0] scan_mem_addr;
    logic [31:0] scan_mem_wdata, scan_mem_rdata;
    scan_chain u_scan (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_capture(scan_capture), .scan_out(scan_out),
        .mem_we(scan_mem_we), .mem_addr(scan_mem_addr),
        .mem_wdata(scan_mem_wdata), .mem_rdata(scan_mem_rdata)
    );

    // ---- Ibex ----
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
        .clk_i(clk), .rst_ni(cpu_rst_n),
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

    // ---- memory subsystem (imem for fetch + scan-load port; dmem for CPU data) ----
    mem_subsystem u_mem (
        .clk(clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .data_req_i(1'b0), .data_gnt_o(), .data_we_i(1'b0), .data_be_i(4'b0),
        .data_addr_i(32'b0), .data_wdata_i(32'b0), .data_rvalid_o(), .data_rdata_o(),
        .scan_owns_mem(scan_owns_mem),
        .scan_we(scan_mem_we), .scan_addr(scan_mem_addr), .scan_wdata(scan_mem_wdata),
        .scan_sel_dmem(scan_sel_dmem)
    );

    // ---- data-side AHB bus (same as v0.5) ----
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
        .clk(clk), .rst_n(rst_n),
        .req(data_req), .gnt(data_gnt), .we(data_we), .be(data_be),
        .addr(data_addr), .wdata(data_wdata), .rvalid(data_rvalid), .rdata(data_rdata),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWSTRB(HWSTRB),
        .HWDATA(HWDATA), .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP)
    );

    ahb_interconnect u_ic (
        .HCLK(clk), .HRESETn(rst_n),
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
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[0]), .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWSTRB(HWSTRB), .HWDATA(slv_HWDATA),
        .HRDATA(s0_HRDATA), .HREADY(s0_HREADY), .HRESP(s0_HRESP)
    );

    // ---- peripheral tier ----
    logic        PSEL, PENABLE, PWRITE, PREADY;
    logic [31:0] PADDR, PWDATA, PRDATA;

    ahb_to_apb u_bridge (
        .HCLK(clk), .HRESETn(rst_n),
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

    apb_gpio #(.NUM_IO(NUM_IO)) u_gpio (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(gpio_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(gpio_PRDATA), .PREADY(gpio_PREADY),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

    apb_uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(uart_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(uart_PRDATA), .PREADY(uart_PREADY),
        .tx(uart_tx), .rx(uart_rx)
    );

    apb_spi #(.CLK_DIV(SPI_CLK_DIV)) u_spi (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(spi_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(spi_PRDATA), .PREADY(spi_PREADY),
        .sclk(spi_sclk), .mosi(spi_mosi), .miso(spi_miso), .cs_n(spi_cs_n)
    );

endmodule
