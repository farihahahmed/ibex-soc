// ============================================================================
// chip_top.sv - my SoC top level (v0.3: Ibex + memory + GPIO, all on the bus).
//
// Adds to v0.2: the peripheral path. GPIO now hangs off the bus as slave 1, via
// the two-tier fabric:
//     interconnect slave 1 -> ahb_to_apb (bridge) -> apb_decoder -> apb_gpio
//
// Full data-side topology:
//   Ibex data -> ibex_to_ahb -> ahb_interconnect -+-> ahb_mem   (slave 0, memory @ 0x0000_xxxx)
//                                                  +-> bridge -> apb_decoder -> apb_gpio (slave 1, @ 0x0001_xxxx)
// Instruction port still straight to imem.
//
// Memory map: mem region HADDR[17:16]=00 -> slave0; GPIO 0x0001_xxxx -> [17:16]=01 -> slave1.
// UART/SPI (slaves 2,3) not wired yet - added in v0.4/v0.5. The APB decoder's
// uart/spi PSELs are left open and their PRDATA/PREADY tied off.
//
// gpio_out/gpio_in are brought to the top level (they go to chip pads).
// ============================================================================

module chip_top import ibex_pkg::*; #(
    parameter int NUM_IO = 8
)(
    input  logic clk,
    input  logic rst_n,
    output logic [NUM_IO-1:0] gpio_out,
    input  logic [NUM_IO-1:0] gpio_in
);

    // ---- Ibex instruction port ----
    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;
    // ---- Ibex data port ----
    logic        data_req, data_gnt, data_rvalid, data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;
    // integrity (no ECC)
    logic [6:0]  instr_rdata_intg, data_rdata_intg;
    assign instr_rdata_intg = 7'b0;
    assign data_rdata_intg  = 7'b0;

    // ------------------------------------------------------------------
    // Ibex core (same tie-offs).
    // ------------------------------------------------------------------
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

    // ------------------------------------------------------------------
    // Instruction path: straight to imem (mem_subsystem). Data port of
    // mem_subsystem tied idle (data goes through the bus).
    // ------------------------------------------------------------------
    mem_subsystem u_mem (
        .clk(clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .data_req_i(1'b0), .data_gnt_o(), .data_we_i(1'b0), .data_be_i(4'b0),
        .data_addr_i(32'b0), .data_wdata_i(32'b0), .data_rvalid_o(), .data_rdata_o()
    );

    // ------------------------------------------------------------------
    // DATA path: adapter -> interconnect -> {ahb_mem (s0), bridge->APB->gpio (s1)}
    // ------------------------------------------------------------------
    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS;
    logic        HWRITE, HREADY, HRESP;
    logic [3:0]  HWSTRB;

    logic [3:0]  HSEL;
    logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0]  slv_HTRANS;
    logic        slv_HWRITE;

    // slave responses
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
        .s2_HRDATA(32'h0), .s2_HREADY(1'b1), .s2_HRESP(1'b0),
        .s3_HRDATA(32'h0), .s3_HREADY(1'b1), .s3_HRESP(1'b0)
    );

    // slave 0: data memory
    ahb_mem u_dmem_slave (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[0]), .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE),
        .HWSTRB(HWSTRB), .HWDATA(slv_HWDATA),
        .HRDATA(s0_HRDATA), .HREADY(s0_HREADY), .HRESP(s0_HRESP)
    );

    // ------------------------------------------------------------------
    // slave 1: peripheral tier. bridge -> apb_decoder -> apb_gpio.
    // ------------------------------------------------------------------
    // APB master stream from the bridge
    logic        PSEL, PENABLE, PWRITE, PREADY;
    logic [31:0] PADDR, PWDATA, PRDATA;

    ahb_to_apb u_bridge (
        .HCLK(clk), .HRESETn(rst_n),
        .HSEL(HSEL[1]),                 // slave 1 = peripheral region.
        .HADDR(slv_HADDR), .HTRANS(slv_HTRANS), .HWRITE(slv_HWRITE), .HWDATA(slv_HWDATA),
        .HRDATA(s1_HRDATA), .HREADY(s1_HREADY), .HRESP(s1_HRESP),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY)
    );

    // APB decoder fans the single APB stream to peripherals. Only GPIO wired now.
    logic        gpio_PSEL, uart_PSEL, spi_PSEL;
    logic [31:0] gpio_PRDATA;
    logic        gpio_PREADY;
    logic        p_PENABLE, p_PWRITE;
    logic [31:0] p_PADDR, p_PWDATA;

    apb_decoder u_apbdec (
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA), .PREADY(PREADY),
        .gpio_PSEL(gpio_PSEL), .gpio_PRDATA(gpio_PRDATA), .gpio_PREADY(gpio_PREADY),
        // UART/SPI not present yet -> tie their responses off.
        .uart_PSEL(uart_PSEL), .uart_PRDATA(32'h0), .uart_PREADY(1'b1),
        .spi_PSEL(spi_PSEL),  .spi_PRDATA(32'h0),  .spi_PREADY(1'b1),
        .p_PENABLE(p_PENABLE), .p_PWRITE(p_PWRITE), .p_PADDR(p_PADDR), .p_PWDATA(p_PWDATA)
    );

    apb_gpio #(.NUM_IO(NUM_IO)) u_gpio (
        .PCLK(clk), .PRESETn(rst_n),
        .PSEL(gpio_PSEL), .PENABLE(p_PENABLE), .PWRITE(p_PWRITE),
        .PADDR(p_PADDR), .PWDATA(p_PWDATA), .PRDATA(gpio_PRDATA), .PREADY(gpio_PREADY),
        .gpio_out(gpio_out), .gpio_in(gpio_in)
    );

endmodule
