// ============================================================================
// chip_top.sv - my SoC top level (v0.5: FULL SoC - Ibex + memory + GPIO + UART + SPI).
//
// Adds to v0.4: apb_spi hangs on the APB decoder (peripheral 3, @ 0x0003_xxxx).
// This is the complete Columbia peripheral set on the two-tier bus:
//   Ibex data -> ibex_to_ahb -> ahb_interconnect -+-> ahb_mem   (slave 0, mem @ 0x0000)
//                                                  +-> bridge -> apb_decoder -+-> apb_gpio (@0x0001)
//                                                                             +-> apb_uart (@0x0002)
//                                                                             +-> apb_spi  (@0x0003)
// Instruction port straight to imem.
//
// All peripheral regions (0x0001/0x0002/0x0003 -> HSEL[1]/[2]/[3]) route through
// the single bridge; the interconnect's s1/s2/s3 response inputs all come from
// the bridge so any selected peripheral returns the bridge's response.
//
// Top-level pins: gpio_out/in, uart_tx/rx, spi sclk/mosi/miso/cs_n -> chip pads.
// ============================================================================

module chip_top import ibex_pkg::*; #(
    parameter int NUM_IO    = 8,
    parameter int CLK_FREQ  = 8,
    parameter int BAUD_RATE = 1,
    parameter int SPI_CLK_DIV = 2
)(
    input  logic clk,
    input  logic rst_n,
    output logic [NUM_IO-1:0] gpio_out,
    input  logic [NUM_IO-1:0] gpio_in,
    output logic uart_tx,
    input  logic uart_rx,
    output logic spi_sclk,
    output logic spi_mosi,
    input  logic spi_miso,
    output logic spi_cs_n
);

    // ---- Ibex ports ----
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
        .clk_i(clk), .rst_ni(rst_n),
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
        .clk(clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .data_req_i(1'b0), .data_gnt_o(), .data_we_i(1'b0), .data_be_i(4'b0),
        .data_addr_i(32'b0), .data_wdata_i(32'b0), .data_rvalid_o(), .data_rdata_o()
    );

    // ---- data-side AHB bus ----
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
        // GPIO/UART/SPI (s1/s2/s3) all share the bridge -> all response inputs = bridge.
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

    // ---- peripheral tier: bridge -> decoder -> {gpio, uart, spi} ----
    logic        PSEL, PENABLE, PWRITE, PREADY;
    logic [31:0] PADDR, PWDATA, PRDATA;

    ahb_to_apb u_bridge (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[1] | HSEL[2] | HSEL[3]),   // any peripheral region -> the bridge.
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
