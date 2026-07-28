// ============================================================================
// chip_top.sv - my SoC top level (v0.1 MINIMAL: Ibex + memory only).
//
// This is the first time my memory meets the real Ibex core. No bus, no
// peripherals yet - just:
//   - ibex_top (the RISC-V core)
//   - my mem_subsystem (imem + dmem, with synchronized reset)
//
// Ibex has two memory ports; I wire them straight to my mem_subsystem:
//   instruction port -> imem (fetch)
//   data port        -> dmem (load/store)
//
// All the extra Ibex signals (integrity/ECC, icache config, scramble, debug,
// interrupts, alerts, shadows) are tied off exactly like the ibex_simple_system
// example does, since I'm running a minimal core (no ECC, no icache, no debug).
//
// boot_addr_i sets where Ibex starts fetching. My imem is at 0x0, so I boot at 0x0.
// fetch_enable_i MUST be asserted (IbexMuBiOn) or the core never fetches.
// ============================================================================

module chip_top import ibex_pkg::*; (
    input  logic clk,
    input  logic rst_n
);

    // ---- wires between Ibex and my memory ----
    // instruction port
    logic        instr_req;
    logic        instr_gnt;
    logic        instr_rvalid;
    logic [31:0] instr_addr;
    logic [31:0] instr_rdata;

    // data port
    logic        data_req;
    logic        data_gnt;
    logic        data_rvalid;
    logic        data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;

    // integrity inputs Ibex expects (I'm not using ECC, so drive zeros / ignore)
    logic [6:0]  instr_rdata_intg;
    logic [6:0]  data_rdata_intg;
    assign instr_rdata_intg = 7'b0;
    assign data_rdata_intg  = 7'b0;

    // --------------------------------------------------------------------
    // The Ibex core. Parameters kept minimal: no ICache, no PMP, fast M.
    // Tie-offs copied from the ibex_simple_system example.
    // --------------------------------------------------------------------
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
        .boot_addr_i     (32'h0000_0000),   // start fetching from my imem base.

        // instruction port -> my imem
        .instr_req_o        (instr_req),
        .instr_gnt_i        (instr_gnt),
        .instr_rvalid_i     (instr_rvalid),
        .instr_addr_o       (instr_addr),
        .instr_rdata_i      (instr_rdata),
        .instr_rdata_intg_i (instr_rdata_intg),
        .instr_err_i        (1'b0),

        // data port -> my dmem
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

        // interrupts - none for now
        .irq_software_i  (1'b0),
        .irq_timer_i     (1'b0),
        .irq_external_i  (1'b0),
        .irq_fast_i      (15'b0),
        .irq_nm_i        (1'b0),

        // scrambling - unused
        .scramble_key_valid_i (1'b0),
        .scramble_key_i       ('0),
        .scramble_nonce_i     ('0),
        .scramble_req_o       (),

        // debug - unused
        .debug_req_i     (1'b0),
        .crash_dump_o    (),
        .double_fault_seen_o (),

        // fetch enable MUST be on or the core won't run.
        .fetch_enable_i         (ibex_pkg::IbexMuBiOn),
        .mcounteren_writable_i  (ibex_pkg::IbexMuBiOn),
        .alert_minor_o          (),
        .alert_major_internal_o (),
        .alert_major_bus_o      (),
        .core_sleep_o           (),

        .lockstep_cmp_en_o      (),

        // shadow outputs - unused
        .data_req_shadow_o        (),
        .data_we_shadow_o         (),
        .data_be_shadow_o         (),
        .data_addr_shadow_o       (),
        .data_wdata_shadow_o      (),
        .data_wdata_intg_shadow_o (),
        .instr_req_shadow_o       (),
        .instr_addr_shadow_o      ()
    );

    // --------------------------------------------------------------------
    // My memory subsystem. Ibex "_o" outputs feed my "_i" inputs and vice versa.
    // --------------------------------------------------------------------
    mem_subsystem u_mem (
        .clk         (clk),
        .rst_n_in    (rst_n),

        // instruction port
        .instr_req_i    (instr_req),
        .instr_gnt_o    (instr_gnt),
        .instr_addr_i   (instr_addr),
        .instr_rvalid_o (instr_rvalid),
        .instr_rdata_o  (instr_rdata),

        // data port
        .data_req_i    (data_req),
        .data_gnt_o    (data_gnt),
        .data_we_i     (data_we),
        .data_be_i     (data_be),
        .data_addr_i   (data_addr),
        .data_wdata_i  (data_wdata),
        .data_rvalid_o (data_rvalid),
        .data_rdata_o  (data_rdata)
    );

endmodule

