// ============================================================================
// chip_top_load.sv - load-then-run top (v0.6): scan chain + test FSM load the
// program into memory, then release the CPU to run it. No testbench force.
//
// This proves the real bring-up path my chip uses after tapeout:
//   1. FSM RESET_HOLD: CPU held.
//   2. start -> FSM LOAD: scan chain owns memory; I shift each program word in
//      through scan_in and pulse scan_load; it writes into imem.
//   3. load_done -> FSM RUN: CPU released (cpu_rst_n=1); it fetches the loaded
//      program from imem and runs.
//
// Proof of execution: the testbench watches the CPU's fetch address climb through
// the program I scan-loaded. No force-loading of memory - the scan chain does it.
//
// The CPU reset = chip reset AND the FSM's cpu_rst_n, so the FSM holds the core
// off during load and releases it for run.
// ============================================================================

module chip_top_load import ibex_pkg::*; (
    input  logic clk,
    input  logic rst_n,

    // scan chain pins (chip pads)
    input  logic scan_in,
    input  logic scan_shift,
    input  logic scan_load,
    input  logic scan_capture,
    output logic scan_out,
    input  logic scan_sel_dmem,     // 0 = load imem, 1 = load dmem

    // test FSM control pins
    input  logic start,
    input  logic load_done,
    output logic [1:0] fsm_state,

    // expose the CPU fetch address so bring-up can watch execution
    output logic [31:0] cpu_instr_addr,
    output logic        cpu_instr_req
);

    // ---- test FSM: the conductor ----
    logic cpu_rst_n_fsm;
    logic scan_owns_mem;

    test_fsm u_fsm (
        .clk(clk), .rst_n(rst_n),
        .start(start), .load_done(load_done),
        .cpu_rst_n(cpu_rst_n_fsm), .scan_owns_mem(scan_owns_mem), .state_o(fsm_state)
    );

    logic cpu_rst_n;
    assign cpu_rst_n = rst_n & cpu_rst_n_fsm;   // chip reset AND FSM hold.

    // ---- scan chain: serial program loader ----
    logic        scan_mem_we;
    logic [15:0] scan_mem_addr;
    logic [31:0] scan_mem_wdata;
    logic [31:0] scan_mem_rdata;

    scan_chain u_scan (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_capture(scan_capture), .scan_out(scan_out),
        .mem_we(scan_mem_we), .mem_addr(scan_mem_addr),
        .mem_wdata(scan_mem_wdata), .mem_rdata(scan_mem_rdata)
    );

    // ---- Ibex core (reset gated by the FSM) ----
    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;
    logic        data_req, data_gnt, data_rvalid, data_we;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;
    logic [6:0]  instr_rdata_intg, data_rdata_intg;
    assign instr_rdata_intg = 7'b0;
    assign data_rdata_intg  = 7'b0;

    assign cpu_instr_addr = instr_addr;
    assign cpu_instr_req  = instr_req;

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

    // ---- memory subsystem with scan-load port ----
    mem_subsystem u_mem (
        .clk(clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .data_req_i(data_req), .data_gnt_o(data_gnt), .data_we_i(data_we),
        .data_be_i(data_be), .data_addr_i(data_addr), .data_wdata_i(data_wdata),
        .data_rvalid_o(data_rvalid), .data_rdata_o(data_rdata),
        .scan_owns_mem(scan_owns_mem),
        .scan_we(scan_mem_we), .scan_addr(scan_mem_addr), .scan_wdata(scan_mem_wdata),
        .scan_sel_dmem(scan_sel_dmem)
    );

endmodule
