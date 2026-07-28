// ============================================================================
// chip_top.sv - my SoC top level (v0.2: Ibex + memory THROUGH THE BUS).
//
// Change from v0.1: the DATA port no longer wires straight to memory. Now it
// goes through my bus:
//     Ibex data port -> ibex_to_ahb -> ahb_interconnect -> ahb_mem (its own dmem)
// This is the real SoC shape - the CPU reaches data memory over the AHB fabric.
// The INSTRUCTION port still goes straight to imem (fast fetch, no bus needed).
//
// ahb_mem is a self-contained AHB slave (it has its own mem_wrapper+SRAM inside),
// so it IS the data memory hanging on the bus as slave 0. Slaves 1..3 are tied
// off for now - GPIO/UART/SPI get added in v0.3+.
//
// mem_subsystem still holds imem (used) + a dmem (now unused - data lives in
// ahb_mem). Leaving its dmem in place costs nothing and avoids touching a
// verified module; I'll trim later if I care.
//
// boot_addr_i=0 -> Ibex first-fetches at 0x80. fetch_enable MUST be on.
// ============================================================================

module chip_top import ibex_pkg::*; (
    input  logic clk,
    input  logic rst_n
);

    // ---- Ibex instruction port wires ----
    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;

    // ---- Ibex data port wires ----
    logic        data_req, data_gnt, data_rvalid, data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;

    // integrity inputs (no ECC)
    logic [6:0]  instr_rdata_intg, data_rdata_intg;
    assign instr_rdata_intg = 7'b0;
    assign data_rdata_intg  = 7'b0;

    // ------------------------------------------------------------------
    // The Ibex core (same tie-offs as v0.1).
    // ------------------------------------------------------------------
    ibex_top #(
        .PMPEnable       (1'b0),
        .MHPMCounterNum  (0),
        .RV32E           (1'b0),
        .RV32M           (ibex_pkg::RV32MFast),
        .RV32B           (ibex_pkg::RV32BNone),
        .ICache          (1'b0),
        .DbgTriggerEn    (1'b0),
        .SecureIbex      (1'b0)
    ) u_ibex (
        .clk_i           (clk),
        .rst_ni          (rst_n),
        .test_en_i       (1'b0),
        .scan_rst_ni     (1'b1),
        .ram_cfg_icache_tag_i  ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
        .ram_cfg_icache_tag_o  (),
        .ram_cfg_icache_data_i ('{default: prim_ram_1p_pkg::RAM_1P_CFG_REQ_DEFAULT}),
        .ram_cfg_icache_data_o (),
        .hart_id_i       (32'b0),
        .boot_addr_i     (32'h0000_0000),

        .instr_req_o        (instr_req),
        .instr_gnt_i        (instr_gnt),
        .instr_rvalid_i     (instr_rvalid),
        .instr_addr_o       (instr_addr),
        .instr_rdata_i      (instr_rdata),
        .instr_rdata_intg_i (instr_rdata_intg),
        .instr_err_i        (1'b0),

        .data_req_o         (data_req),
        .data_gnt_i         (data_gnt),
        .data_rvalid_i      (data_rvalid),
        .data_we_o          (data_we),
        .data_be_o          (data_be),
        .data_addr_o        (data_addr),
        .data_wdata_o       (data_wdata),
        .data_wdata_intg_o  (),
        .data_rdata_i       (data_rdata),
        .data_rdata_intg_i  (data_rdata_intg),
        .data_err_i         (1'b0),

        .irq_software_i  (1'b0),
        .irq_timer_i     (1'b0),
        .irq_external_i  (1'b0),
        .irq_fast_i      (15'b0),
        .irq_nm_i        (1'b0),

        .scramble_key_valid_i (1'b0),
        .scramble_key_i       ('0),
        .scramble_nonce_i     ('0),
        .scramble_req_o       (),

        .debug_req_i     (1'b0),
        .crash_dump_o    (),
        .double_fault_seen_o (),

        .fetch_enable_i         (ibex_pkg::IbexMuBiOn),
        .mcounteren_writable_i  (ibex_pkg::IbexMuBiOn),
        .alert_minor_o          (),
        .alert_major_internal_o (),
        .alert_major_bus_o      (),
        .core_sleep_o           (),
        .lockstep_cmp_en_o      (),

        .data_req_shadow_o        (),
        .data_we_shadow_o         (),
        .data_be_shadow_o         (),
        .data_addr_shadow_o       (),
        .data_wdata_shadow_o      (),
        .data_wdata_intg_shadow_o (),
        .instr_req_shadow_o       (),
        .instr_addr_shadow_o      ()
    );

    // ------------------------------------------------------------------
    // INSTRUCTION path: straight to mem_subsystem's imem (unchanged from v0.1).
    // I still feed mem_subsystem's data port too (Ibex data wires), but the CPU's
    // real data traffic now goes through the bus below. The mem_subsystem data
    // port just sits here harmlessly - to avoid dangling inputs I tie it idle.
    // ------------------------------------------------------------------
    mem_subsystem u_mem (
        .clk         (clk),
        .rst_n_in    (rst_n),

        .instr_req_i    (instr_req),
        .instr_gnt_o    (instr_gnt),
        .instr_addr_i   (instr_addr),
        .instr_rvalid_o (instr_rvalid),
        .instr_rdata_o  (instr_rdata),

        // data port of mem_subsystem is NOT used for CPU data now (bus handles it).
        // tie it to idle so it does nothing.
        .data_req_i    (1'b0),
        .data_gnt_o    (),
        .data_we_i     (1'b0),
        .data_be_i     (4'b0),
        .data_addr_i   (32'b0),
        .data_wdata_i  (32'b0),
        .data_rvalid_o (),
        .data_rdata_o  ()
    );

    // ------------------------------------------------------------------
    // DATA path: Ibex data port -> adapter -> interconnect -> ahb_mem.
    // ------------------------------------------------------------------

    // AHB master signals (adapter output)
    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [1:0]  HTRANS;
    logic        HWRITE, HREADY, HRESP;
    logic [3:0]  HWSTRB;

    // shared slave-side broadcast from interconnect
    logic [3:0]  HSEL;
    logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0]  slv_HTRANS;
    logic        slv_HWRITE;

    // slave 0 (ahb_mem) response
    logic [31:0] s0_HRDATA;
    logic        s0_HREADY, s0_HRESP;

    // Ibex data port -> AHB master
    ibex_to_ahb u_adapter (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (data_req),
        .gnt   (data_gnt),
        .we    (data_we),
        .be    (data_be),
        .addr  (data_addr),
        .wdata (data_wdata),
        .rvalid(data_rvalid),
        .rdata (data_rdata),
        .HADDR (HADDR),
        .HTRANS(HTRANS),
        .HWRITE(HWRITE),
        .HWSTRB(HWSTRB),
        .HWDATA(HWDATA),
        .HRDATA(HRDATA),
        .HREADY(HREADY),
        .HRESP (HRESP)
    );

    // interconnect: routes by address, broadcasts to slaves, muxes responses.
    ahb_interconnect u_ic (
        .HCLK    (clk),
        .HRESETn (rst_n),
        .HADDR   (HADDR),
        .HTRANS  (HTRANS),
        .HWRITE  (HWRITE),
        .HWDATA  (HWDATA),
        .HRDATA  (HRDATA),
        .HREADY  (HREADY),
        .HRESP   (HRESP),
        .HSEL      (HSEL),
        .slv_HADDR (slv_HADDR),
        .slv_HTRANS(slv_HTRANS),
        .slv_HWRITE(slv_HWRITE),
        .slv_HWDATA(slv_HWDATA),
        // slave 0 = data memory
        .s0_HRDATA(s0_HRDATA), .s0_HREADY(s0_HREADY), .s0_HRESP(s0_HRESP),
        // slaves 1..3 tied off (no peripherals yet)
        .s1_HRDATA(32'h0), .s1_HREADY(1'b1), .s1_HRESP(1'b0),
        .s2_HRDATA(32'h0), .s2_HREADY(1'b1), .s2_HRESP(1'b0),
        .s3_HRDATA(32'h0), .s3_HREADY(1'b1), .s3_HRESP(1'b0)
    );

    // slave 0: the data memory (self-contained: has its own SRAM inside).
    ahb_mem u_dmem_slave (
        .HCLK    (clk),
        .HRESETn (rst_n),
        .HSEL    (HSEL[0]),
        .HADDR   (slv_HADDR),
        .HTRANS  (slv_HTRANS),
        .HWRITE  (slv_HWRITE),
        .HWSTRB  (HWSTRB),
        .HWDATA  (slv_HWDATA),
        .HRDATA  (s0_HRDATA),
        .HREADY  (s0_HREADY),
        .HRESP   (s0_HRESP)
    );

endmodule
