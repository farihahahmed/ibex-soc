module ibex_top (
	clk_i,
	rst_ni,
	test_en_i,
	ram_cfg_icache_tag_i,
	ram_cfg_icache_tag_o,
	ram_cfg_icache_data_i,
	ram_cfg_icache_data_o,
	hart_id_i,
	boot_addr_i,
	instr_req_o,
	instr_gnt_i,
	instr_rvalid_i,
	instr_addr_o,
	instr_rdata_i,
	instr_rdata_intg_i,
	instr_err_i,
	data_req_o,
	data_gnt_i,
	data_rvalid_i,
	data_we_o,
	data_be_o,
	data_addr_o,
	data_wdata_o,
	data_wdata_intg_o,
	data_rdata_i,
	data_rdata_intg_i,
	data_err_i,
	irq_software_i,
	irq_timer_i,
	irq_external_i,
	irq_fast_i,
	irq_nm_i,
	scramble_key_valid_i,
	scramble_key_i,
	scramble_nonce_i,
	scramble_req_o,
	debug_req_i,
	crash_dump_o,
	double_fault_seen_o,
	fetch_enable_i,
	mcounteren_writable_i,
	alert_minor_o,
	alert_major_internal_o,
	alert_major_bus_o,
	core_sleep_o,
	scan_rst_ni,
	lockstep_cmp_en_o,
	data_req_shadow_o,
	data_we_shadow_o,
	data_be_shadow_o,
	data_addr_shadow_o,
	data_wdata_shadow_o,
	data_wdata_intg_shadow_o,
	instr_req_shadow_o,
	instr_addr_shadow_o
);
	reg _sv2v_0;
	parameter [0:0] PMPEnable = 1'b0;
	parameter [31:0] PMPGranularity = 0;
	parameter [31:0] PMPNumRegions = 4;
	parameter [31:0] MHPMCounterNum = 0;
	parameter [31:0] MHPMCounterWidth = 40;
	localparam [31:0] ibex_pkg_PMP_MAX_REGIONS = 16;
	localparam [95:0] ibex_pkg_PmpCfgRst = 96'b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000;
	parameter [95:0] PMPRstCfg = ibex_pkg_PmpCfgRst;
	localparam [31:0] ibex_pkg_PMP_ADDR_MSB = 33;
	localparam [543:0] ibex_pkg_PmpAddrRst = 544'h0;
	parameter [543:0] PMPRstAddr = ibex_pkg_PmpAddrRst;
	localparam [2:0] ibex_pkg_PmpMseccfgRst = 3'b000;
	parameter [2:0] PMPRstMsecCfg = ibex_pkg_PmpMseccfgRst;
	parameter [0:0] RV32E = 1'b0;
	parameter integer RV32M = 32'sd2;
	parameter integer RV32B = 32'sd0;
	parameter integer RV32ZC = 32'sd3;
	parameter integer RegFile = 32'sd0;
	parameter [0:0] BranchTargetALU = 1'b0;
	parameter [0:0] WritebackStage = 1'b0;
	parameter [0:0] ICache = 1'b0;
	parameter [0:0] ICacheECC = 1'b0;
	parameter [0:0] BranchPredictor = 1'b0;
	parameter [0:0] DbgTriggerEn = 1'b0;
	parameter [31:0] DbgHwBreakNum = 1;
	parameter [0:0] SecureIbex = 1'b0;
	parameter [31:0] LockstepOffset = 1;
	parameter [0:0] MemECC = SecureIbex;
	parameter [31:0] MemDataWidth = (MemECC ? 39 : 32);
	parameter [0:0] ICacheScramble = 1'b0;
	parameter [31:0] ICacheScrNumPrinceRoundsHalf = 2;
	parameter [0:0] ICacheTweakInfection = SecureIbex;
	localparam signed [31:0] ibex_pkg_LfsrWidth = 32;
	localparam [31:0] ibex_pkg_RndCnstLfsrSeedDefault = 32'hac533bf4;
	parameter [31:0] RndCnstLfsrSeed = ibex_pkg_RndCnstLfsrSeedDefault;
	localparam [159:0] ibex_pkg_RndCnstLfsrPermDefault = 160'h1e35ecba467fd1b12e958152c04fa43878a8daed;
	parameter [159:0] RndCnstLfsrPerm = ibex_pkg_RndCnstLfsrPermDefault;
	parameter [31:0] DmBaseAddr = 32'h1a110000;
	parameter [31:0] DmAddrMask = 32'h00000fff;
	parameter [31:0] DmHaltAddr = 32'h1a110800;
	parameter [31:0] DmExceptionAddr = 32'h1a110808;
	localparam [31:0] ibex_pkg_SCRAMBLE_KEY_W = 128;
	localparam [127:0] ibex_pkg_RndCnstIbexKeyDefault = 128'h14e8cecae3040d5e12286bb3cc113298;
	parameter [127:0] RndCnstIbexKey = ibex_pkg_RndCnstIbexKeyDefault;
	localparam [31:0] ibex_pkg_SCRAMBLE_NONCE_W = 64;
	localparam [63:0] ibex_pkg_RndCnstIbexNonceDefault = 64'hf79780bc735f3843;
	parameter [63:0] RndCnstIbexNonce = ibex_pkg_RndCnstIbexNonceDefault;
	parameter [31:0] CsrMvendorId = 32'b00000000000000000000000000000000;
	parameter [31:0] CsrMimpId = 32'b00000000000000000000000000000000;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	localparam [31:0] ibex_pkg_IC_NUM_WAYS = 2;
	localparam [31:0] prim_ram_1p_pkg_Ram1pReqWidth = 32'd12;
	input wire [(ibex_pkg_IC_NUM_WAYS * prim_ram_1p_pkg_Ram1pReqWidth) - 1:0] ram_cfg_icache_tag_i;
	localparam [31:0] prim_ram_1p_pkg_Ram1pRspWidth = 32'd1;
	output wire [(ibex_pkg_IC_NUM_WAYS * prim_ram_1p_pkg_Ram1pRspWidth) - 1:0] ram_cfg_icache_tag_o;
	input wire [(ibex_pkg_IC_NUM_WAYS * prim_ram_1p_pkg_Ram1pReqWidth) - 1:0] ram_cfg_icache_data_i;
	output wire [(ibex_pkg_IC_NUM_WAYS * prim_ram_1p_pkg_Ram1pRspWidth) - 1:0] ram_cfg_icache_data_o;
	input wire [31:0] hart_id_i;
	input wire [31:0] boot_addr_i;
	output wire instr_req_o;
	input wire instr_gnt_i;
	input wire instr_rvalid_i;
	output wire [31:0] instr_addr_o;
	input wire [31:0] instr_rdata_i;
	input wire [6:0] instr_rdata_intg_i;
	input wire instr_err_i;
	output wire data_req_o;
	input wire data_gnt_i;
	input wire data_rvalid_i;
	output wire data_we_o;
	output wire [3:0] data_be_o;
	output wire [31:0] data_addr_o;
	output wire [31:0] data_wdata_o;
	output wire [6:0] data_wdata_intg_o;
	input wire [31:0] data_rdata_i;
	input wire [6:0] data_rdata_intg_i;
	input wire data_err_i;
	input wire irq_software_i;
	input wire irq_timer_i;
	input wire irq_external_i;
	input wire [14:0] irq_fast_i;
	input wire irq_nm_i;
	input wire scramble_key_valid_i;
	input wire [127:0] scramble_key_i;
	input wire [63:0] scramble_nonce_i;
	output wire scramble_req_o;
	input wire debug_req_i;
	output wire [159:0] crash_dump_o;
	output wire double_fault_seen_o;
	localparam signed [31:0] ibex_pkg_IbexMuBiWidth = 4;
	input wire [3:0] fetch_enable_i;
	input wire [3:0] mcounteren_writable_i;
	output wire alert_minor_o;
	output wire alert_major_internal_o;
	output wire alert_major_bus_o;
	output wire core_sleep_o;
	input wire scan_rst_ni;
	output wire [3:0] lockstep_cmp_en_o;
	output wire data_req_shadow_o;
	output wire data_we_shadow_o;
	output wire [3:0] data_be_shadow_o;
	output wire [31:0] data_addr_shadow_o;
	output wire [31:0] data_wdata_shadow_o;
	output wire [6:0] data_wdata_intg_shadow_o;
	output wire instr_req_shadow_o;
	output wire [31:0] instr_addr_shadow_o;
	localparam [0:0] Lockstep = SecureIbex;
	localparam [0:0] ResetAll = Lockstep;
	localparam [0:0] DummyInstructions = SecureIbex;
	localparam [0:0] RegFileECC = 0;
	localparam [0:0] RegFileLockstepECC = Lockstep;
	localparam [31:0] RegFileDataWidth = 32;
	localparam [31:0] RegFileDataEccWidth = 39;
	localparam [31:0] ibex_pkg_BUS_SIZE = 32;
	localparam [31:0] ibex_pkg_IC_DATA_ECC_SIZE = 7;
	localparam [31:0] BusSizeECC = (ICacheECC ? ibex_pkg_BUS_SIZE + ibex_pkg_IC_DATA_ECC_SIZE : ibex_pkg_BUS_SIZE);
	localparam [31:0] ibex_pkg_BUS_BYTES = 4;
	localparam [31:0] ibex_pkg_IC_LINE_SIZE = 64;
	localparam [31:0] ibex_pkg_IC_LINE_BYTES = 8;
	localparam [31:0] ibex_pkg_IC_LINE_BEATS = ibex_pkg_IC_LINE_BYTES / ibex_pkg_BUS_BYTES;
	localparam [31:0] LineSizeECC = BusSizeECC * ibex_pkg_IC_LINE_BEATS;
	localparam [31:0] ibex_pkg_IC_TAG_ECC_SIZE = 6;
	localparam [31:0] ibex_pkg_ADDR_W = 32;
	localparam [31:0] ibex_pkg_IC_SIZE_BYTES = 4096;
	localparam [31:0] ibex_pkg_IC_NUM_LINES = (ibex_pkg_IC_SIZE_BYTES / ibex_pkg_IC_NUM_WAYS) / ibex_pkg_IC_LINE_BYTES;
	localparam [31:0] ibex_pkg_IC_INDEX_W = $clog2(ibex_pkg_IC_NUM_LINES);
	localparam [31:0] ibex_pkg_IC_LINE_W = 3;
	localparam [31:0] ibex_pkg_IC_TAG_SIZE = ((ibex_pkg_ADDR_W - ibex_pkg_IC_INDEX_W) - ibex_pkg_IC_LINE_W) + 1;
	localparam [31:0] TagSizeECC = (ICacheECC ? ibex_pkg_IC_TAG_SIZE + ibex_pkg_IC_TAG_ECC_SIZE : ibex_pkg_IC_TAG_SIZE);
	localparam [31:0] NumAddrScrRounds = (ICacheScramble ? 2 : 0);
	wire clk;
	wire [3:0] core_busy_d;
	reg [3:0] core_busy_q;
	wire clock_en;
	wire irq_pending;
	wire dummy_instr_id;
	wire dummy_instr_wb;
	wire [4:0] rf_raddr_a;
	wire [4:0] rf_raddr_b;
	wire [4:0] rf_waddr_wb;
	wire rf_we_wb;
	wire [31:0] rf_wdata_wb;
	wire [31:0] rf_rdata_a;
	wire [31:0] rf_rdata_b;
	wire [MemDataWidth - 1:0] data_wdata_core;
	wire [MemDataWidth - 1:0] data_rdata_core;
	wire [MemDataWidth - 1:0] instr_rdata_core;
	wire [1:0] ic_tag_req;
	wire ic_tag_write;
	wire [ibex_pkg_IC_INDEX_W - 1:0] ic_tag_addr;
	wire [TagSizeECC - 1:0] ic_tag_wdata;
	wire [(ibex_pkg_IC_NUM_WAYS * TagSizeECC) - 1:0] ic_tag_rdata;
	wire [1:0] ic_data_req;
	wire ic_data_write;
	wire [ibex_pkg_IC_INDEX_W - 1:0] ic_data_addr;
	wire [LineSizeECC - 1:0] ic_data_wdata;
	wire [(ibex_pkg_IC_NUM_WAYS * LineSizeECC) - 1:0] ic_data_rdata;
	wire ic_scr_key_req;
	wire core_alert_major_internal;
	wire core_alert_major_bus;
	wire core_alert_minor;
	wire lockstep_alert_major_internal;
	wire lockstep_alert_major_bus;
	wire lockstep_alert_minor;
	reg [127:0] scramble_key_q;
	reg [63:0] scramble_nonce_q;
	wire scramble_key_valid_d;
	reg scramble_key_valid_q;
	wire scramble_req_d;
	reg scramble_req_q;
	wire [3:0] fetch_enable_buf;
	wire [3:0] mcounteren_writable_buf;
	localparam [3:0] ibex_pkg_IbexMuBiOff = 4'b1010;
	generate
		if (SecureIbex) begin : g_clock_en_secure
			prim_flop #(
				.Width(ibex_pkg_IbexMuBiWidth),
				.ResetValue(ibex_pkg_IbexMuBiOff)
			) u_prim_core_busy_flop(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.d_i(core_busy_d),
				.q_o(core_busy_q)
			);
			assign clock_en = (((core_busy_q != ibex_pkg_IbexMuBiOff) | debug_req_i) | irq_pending) | irq_nm_i;
		end
		else begin : g_clock_en_non_secure
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni)
					core_busy_q <= ibex_pkg_IbexMuBiOff;
				else
					core_busy_q <= core_busy_d;
			assign clock_en = ((core_busy_q[0] | debug_req_i) | irq_pending) | irq_nm_i;
			wire unused_core_busy;
			assign unused_core_busy = ^core_busy_q[3:1];
		end
	endgenerate
	assign core_sleep_o = ~clock_en;
	prim_clock_gating core_clock_gate_i(
		.clk_i(clk_i),
		.en_i(clock_en),
		.test_en_i(test_en_i),
		.clk_o(clk)
	);
	prim_buf #(.Width(ibex_pkg_IbexMuBiWidth)) u_fetch_enable_buf(
		.in_i(fetch_enable_i),
		.out_o(fetch_enable_buf)
	);
	prim_buf #(.Width(ibex_pkg_IbexMuBiWidth)) u_mcounteren_writable_buf(
		.in_i(mcounteren_writable_i),
		.out_o(mcounteren_writable_buf)
	);
	assign data_rdata_core[31:0] = data_rdata_i;
	assign instr_rdata_core[31:0] = instr_rdata_i;
	generate
		if (MemECC) begin : gen_mem_rdata_ecc
			assign data_rdata_core[38:32] = data_rdata_intg_i;
			assign instr_rdata_core[38:32] = instr_rdata_intg_i;
		end
		else begin : gen_non_mem_rdata_ecc
			wire unused_intg;
			assign unused_intg = ^{instr_rdata_intg_i, data_rdata_intg_i};
		end
	endgenerate
	ibex_core #(
		.PMPEnable(PMPEnable),
		.PMPGranularity(PMPGranularity),
		.PMPNumRegions(PMPNumRegions),
		.PMPRstCfg(PMPRstCfg),
		.PMPRstAddr(PMPRstAddr),
		.PMPRstMsecCfg(PMPRstMsecCfg),
		.MHPMCounterNum(MHPMCounterNum),
		.MHPMCounterWidth(MHPMCounterWidth),
		.RV32E(RV32E),
		.RV32M(RV32M),
		.RV32B(RV32B),
		.RV32ZC(RV32ZC),
		.BranchTargetALU(BranchTargetALU),
		.ICache(ICache),
		.ICacheECC(ICacheECC),
		.ICacheTweakInfection(ICacheTweakInfection),
		.BusSizeECC(BusSizeECC),
		.TagSizeECC(TagSizeECC),
		.LineSizeECC(LineSizeECC),
		.BranchPredictor(BranchPredictor),
		.DbgTriggerEn(DbgTriggerEn),
		.DbgHwBreakNum(DbgHwBreakNum),
		.WritebackStage(WritebackStage),
		.ResetAll(ResetAll),
		.RndCnstLfsrSeed(RndCnstLfsrSeed),
		.RndCnstLfsrPerm(RndCnstLfsrPerm),
		.SecureIbex(SecureIbex),
		.DummyInstructions(DummyInstructions),
		.RegFileECC(RegFileECC),
		.RegFileDataWidth(RegFileDataWidth),
		.MemECC(MemECC),
		.MemDataWidth(MemDataWidth),
		.DmBaseAddr(DmBaseAddr),
		.DmAddrMask(DmAddrMask),
		.DmHaltAddr(DmHaltAddr),
		.DmExceptionAddr(DmExceptionAddr),
		.CsrMvendorId(CsrMvendorId),
		.CsrMimpId(CsrMimpId)
	) u_ibex_core(
		.clk_i(clk),
		.rst_ni(rst_ni),
		.hart_id_i(hart_id_i),
		.boot_addr_i(boot_addr_i),
		.instr_req_o(instr_req_o),
		.instr_gnt_i(instr_gnt_i),
		.instr_rvalid_i(instr_rvalid_i),
		.instr_addr_o(instr_addr_o),
		.instr_rdata_i(instr_rdata_core),
		.instr_err_i(instr_err_i),
		.data_req_o(data_req_o),
		.data_gnt_i(data_gnt_i),
		.data_rvalid_i(data_rvalid_i),
		.data_we_o(data_we_o),
		.data_be_o(data_be_o),
		.data_addr_o(data_addr_o),
		.data_wdata_o(data_wdata_core),
		.data_rdata_i(data_rdata_core),
		.data_err_i(data_err_i),
		.dummy_instr_id_o(dummy_instr_id),
		.dummy_instr_wb_o(dummy_instr_wb),
		.rf_raddr_a_o(rf_raddr_a),
		.rf_raddr_b_o(rf_raddr_b),
		.rf_waddr_wb_o(rf_waddr_wb),
		.rf_we_wb_o(rf_we_wb),
		.rf_wdata_wb_ecc_o(rf_wdata_wb),
		.rf_rdata_a_ecc_i(rf_rdata_a),
		.rf_rdata_b_ecc_i(rf_rdata_b),
		.ic_tag_req_o(ic_tag_req),
		.ic_tag_write_o(ic_tag_write),
		.ic_tag_addr_o(ic_tag_addr),
		.ic_tag_wdata_o(ic_tag_wdata),
		.ic_tag_rdata_i(ic_tag_rdata),
		.ic_data_req_o(ic_data_req),
		.ic_data_write_o(ic_data_write),
		.ic_data_addr_o(ic_data_addr),
		.ic_data_wdata_o(ic_data_wdata),
		.ic_data_rdata_i(ic_data_rdata),
		.ic_scr_key_valid_i(scramble_key_valid_q),
		.ic_scr_key_req_o(ic_scr_key_req),
		.irq_software_i(irq_software_i),
		.irq_timer_i(irq_timer_i),
		.irq_external_i(irq_external_i),
		.irq_fast_i(irq_fast_i),
		.irq_nm_i(irq_nm_i),
		.irq_pending_o(irq_pending),
		.debug_req_i(debug_req_i),
		.crash_dump_o(crash_dump_o),
		.double_fault_seen_o(double_fault_seen_o),
		.fetch_enable_i(fetch_enable_buf),
		.mcounteren_writable_i(mcounteren_writable_buf),
		.alert_minor_o(core_alert_minor),
		.alert_major_internal_o(core_alert_major_internal),
		.alert_major_bus_o(core_alert_major_bus),
		.core_busy_o(core_busy_d)
	);
	localparam [38:0] prim_secded_pkg_SecdedInv3932ZeroWord = 39'h2a00000000;
	function automatic [31:0] sv2v_cast_C9EDF;
		input reg [31:0] inp;
		sv2v_cast_C9EDF = inp;
	endfunction
	generate
		if (RegFile == 32'sd0) begin : gen_regfile_ff
			ibex_register_file_ff #(
				.RV32E(RV32E),
				.DataWidth(RegFileDataWidth),
				.DummyInstructions(DummyInstructions),
				.WordZeroVal(sv2v_cast_C9EDF(prim_secded_pkg_SecdedInv3932ZeroWord))
			) register_file_i(
				.clk_i(clk),
				.rst_ni(rst_ni),
				.test_en_i(test_en_i),
				.dummy_instr_id_i(dummy_instr_id),
				.dummy_instr_wb_i(dummy_instr_wb),
				.raddr_a_i(rf_raddr_a),
				.rdata_a_o(rf_rdata_a),
				.raddr_b_i(rf_raddr_b),
				.rdata_b_o(rf_rdata_b),
				.waddr_a_i(rf_waddr_wb),
				.wdata_a_i(rf_wdata_wb),
				.we_a_i(rf_we_wb)
			);
		end
		else if (RegFile == 32'sd1) begin : gen_regfile_fpga
			ibex_register_file_fpga #(
				.RV32E(RV32E),
				.DataWidth(RegFileDataWidth),
				.DummyInstructions(DummyInstructions),
				.WordZeroVal(sv2v_cast_C9EDF(prim_secded_pkg_SecdedInv3932ZeroWord))
			) register_file_i(
				.clk_i(clk),
				.rst_ni(rst_ni),
				.test_en_i(test_en_i),
				.dummy_instr_id_i(dummy_instr_id),
				.dummy_instr_wb_i(dummy_instr_wb),
				.raddr_a_i(rf_raddr_a),
				.rdata_a_o(rf_rdata_a),
				.raddr_b_i(rf_raddr_b),
				.rdata_b_o(rf_rdata_b),
				.waddr_a_i(rf_waddr_wb),
				.wdata_a_i(rf_wdata_wb),
				.we_a_i(rf_we_wb)
			);
		end
		else if (RegFile == 32'sd2) begin : gen_regfile_latch
			ibex_register_file_latch #(
				.RV32E(RV32E),
				.DataWidth(RegFileDataWidth),
				.DummyInstructions(DummyInstructions),
				.WordZeroVal(sv2v_cast_C9EDF(prim_secded_pkg_SecdedInv3932ZeroWord))
			) register_file_i(
				.clk_i(clk),
				.rst_ni(rst_ni),
				.test_en_i(test_en_i),
				.dummy_instr_id_i(dummy_instr_id),
				.dummy_instr_wb_i(dummy_instr_wb),
				.raddr_a_i(rf_raddr_a),
				.rdata_a_o(rf_rdata_a),
				.raddr_b_i(rf_raddr_b),
				.rdata_b_o(rf_rdata_b),
				.waddr_a_i(rf_waddr_wb),
				.wdata_a_i(rf_wdata_wb),
				.we_a_i(rf_we_wb)
			);
		end
		if (ICacheScramble) begin : gen_scramble
			assign scramble_key_valid_d = (scramble_req_q ? scramble_key_valid_i : (ic_scr_key_req ? 1'b0 : scramble_key_valid_q));
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni) begin
					scramble_key_q <= RndCnstIbexKey;
					scramble_nonce_q <= RndCnstIbexNonce;
				end
				else if (scramble_key_valid_i) begin
					scramble_key_q <= scramble_key_i;
					scramble_nonce_q <= scramble_nonce_i;
				end
			always @(posedge clk_i or negedge rst_ni)
				if (!rst_ni) begin
					scramble_key_valid_q <= 1'b1;
					scramble_req_q <= 1'sb0;
				end
				else begin
					scramble_key_valid_q <= scramble_key_valid_d;
					scramble_req_q <= scramble_req_d;
				end
			assign scramble_req_d = (scramble_req_q ? ~scramble_key_valid_i : ic_scr_key_req);
			assign scramble_req_o = scramble_req_q;
		end
		else begin : gen_noscramble
			reg unused_scramble_inputs = (((((((((((scramble_key_valid_i & |scramble_key_i) & |RndCnstIbexKey) & |scramble_nonce_i) & |RndCnstIbexNonce) & scramble_req_q) & ic_scr_key_req) & scramble_key_valid_d) & scramble_req_d) & |scramble_key_q) & |scramble_nonce_q) & scramble_key_valid_q) & scramble_key_valid_d;
			assign scramble_req_d = 1'b0;
			wire [1:1] sv2v_tmp_B6560;
			assign sv2v_tmp_B6560 = 1'b0;
			always @(*) scramble_req_q = sv2v_tmp_B6560;
			assign scramble_req_o = 1'b0;
			wire [128:1] sv2v_tmp_2A187;
			assign sv2v_tmp_2A187 = 1'sb0;
			always @(*) scramble_key_q = sv2v_tmp_2A187;
			wire [64:1] sv2v_tmp_A799D;
			assign sv2v_tmp_A799D = 1'sb0;
			always @(*) scramble_nonce_q = sv2v_tmp_A799D;
			wire [1:1] sv2v_tmp_12FB7;
			assign sv2v_tmp_12FB7 = 1'b1;
			always @(*) scramble_key_valid_q = sv2v_tmp_12FB7;
			assign scramble_key_valid_d = 1'b1;
		end
	endgenerate
	wire [1:0] icache_tag_alert;
	wire [1:0] icache_data_alert;
	localparam [0:0] prim_ram_1p_pkg_RAM_1P_CFG_RSP_DEFAULT = 1'sb0;
	function automatic [0:0] sv2v_cast_C9369;
		input reg [0:0] inp;
		sv2v_cast_C9369 = inp;
	endfunction
	function automatic [TagSizeECC - 1:0] sv2v_cast_51117;
		input reg [TagSizeECC - 1:0] inp;
		sv2v_cast_51117 = inp;
	endfunction
	function automatic [LineSizeECC - 1:0] sv2v_cast_C86ED;
		input reg [LineSizeECC - 1:0] inp;
		sv2v_cast_C86ED = inp;
	endfunction
	generate
		if (ICache) begin : gen_rams
			genvar _gv_way_1;
			for (_gv_way_1 = 0; _gv_way_1 < ibex_pkg_IC_NUM_WAYS; _gv_way_1 = _gv_way_1 + 1) begin : gen_rams_inner
				localparam way = _gv_way_1;
				if (ICacheScramble) begin : gen_scramble_rams
					prim_ram_1p_scr #(
						.Width(TagSizeECC),
						.Depth(ibex_pkg_IC_NUM_LINES),
						.DataBitsPerMask(TagSizeECC),
						.EnableParity(0),
						.NumPrinceRoundsHalf(ICacheScrNumPrinceRoundsHalf),
						.NumAddrScrRounds(NumAddrScrRounds)
					) tag_bank(
						.clk_i(clk_i),
						.rst_ni(rst_ni),
						.key_valid_i(scramble_key_valid_q),
						.key_i(scramble_key_q),
						.nonce_i(scramble_nonce_q),
						.req_i(ic_tag_req[way]),
						.gnt_o(),
						.write_i(ic_tag_write),
						.addr_i(ic_tag_addr),
						.wdata_i(ic_tag_wdata),
						.wmask_i({TagSizeECC {1'b1}}),
						.intg_error_i(1'b0),
						.rdata_o(ic_tag_rdata[(1 - way) * TagSizeECC+:TagSizeECC]),
						.rvalid_o(),
						.raddr_o(),
						.rerror_o(),
						.cfg_i(ram_cfg_icache_tag_i[way * prim_ram_1p_pkg_Ram1pReqWidth+:prim_ram_1p_pkg_Ram1pReqWidth]),
						.cfg_o(ram_cfg_icache_tag_o[way * prim_ram_1p_pkg_Ram1pRspWidth+:prim_ram_1p_pkg_Ram1pRspWidth]),
						.wr_collision_o(),
						.write_pending_o(),
						.alert_o(icache_tag_alert[way])
					);
					prim_ram_1p_scr #(
						.Width(LineSizeECC),
						.Depth(ibex_pkg_IC_NUM_LINES),
						.DataBitsPerMask(LineSizeECC),
						.ReplicateKeyStream(1),
						.EnableParity(0),
						.NumPrinceRoundsHalf(ICacheScrNumPrinceRoundsHalf),
						.NumAddrScrRounds(NumAddrScrRounds)
					) data_bank(
						.clk_i(clk_i),
						.rst_ni(rst_ni),
						.key_valid_i(scramble_key_valid_q),
						.key_i(scramble_key_q),
						.nonce_i(scramble_nonce_q),
						.req_i(ic_data_req[way]),
						.gnt_o(),
						.write_i(ic_data_write),
						.addr_i(ic_data_addr),
						.wdata_i(ic_data_wdata),
						.wmask_i({LineSizeECC {1'b1}}),
						.intg_error_i(1'b0),
						.rdata_o(ic_data_rdata[(1 - way) * LineSizeECC+:LineSizeECC]),
						.rvalid_o(),
						.raddr_o(),
						.rerror_o(),
						.cfg_i(ram_cfg_icache_data_i[way * prim_ram_1p_pkg_Ram1pReqWidth+:prim_ram_1p_pkg_Ram1pReqWidth]),
						.cfg_o(ram_cfg_icache_data_o[way * prim_ram_1p_pkg_Ram1pRspWidth+:prim_ram_1p_pkg_Ram1pRspWidth]),
						.wr_collision_o(),
						.write_pending_o(),
						.alert_o(icache_data_alert[way])
					);
					reg [127:0] sampled_scramble_key;
					always @(posedge clk_i or negedge rst_ni)
						if (!rst_ni)
							sampled_scramble_key <= 1'sbx;
						else if (scramble_key_valid_i)
							sampled_scramble_key <= scramble_key_i;
				end
				else begin : gen_noscramble_rams
					prim_ram_1p #(
						.Width(TagSizeECC),
						.Depth(ibex_pkg_IC_NUM_LINES),
						.DataBitsPerMask(TagSizeECC)
					) tag_bank(
						.clk_i(clk_i),
						.rst_ni(rst_ni),
						.req_i(ic_tag_req[way]),
						.write_i(ic_tag_write),
						.addr_i(ic_tag_addr),
						.wdata_i(ic_tag_wdata),
						.wmask_i({TagSizeECC {1'b1}}),
						.rdata_o(ic_tag_rdata[(1 - way) * TagSizeECC+:TagSizeECC]),
						.cfg_i(ram_cfg_icache_tag_i[way * prim_ram_1p_pkg_Ram1pReqWidth+:prim_ram_1p_pkg_Ram1pReqWidth]),
						.cfg_o(ram_cfg_icache_tag_o[way * prim_ram_1p_pkg_Ram1pRspWidth+:prim_ram_1p_pkg_Ram1pRspWidth])
					);
					prim_ram_1p #(
						.Width(LineSizeECC),
						.Depth(ibex_pkg_IC_NUM_LINES),
						.DataBitsPerMask(LineSizeECC)
					) data_bank(
						.clk_i(clk_i),
						.rst_ni(rst_ni),
						.req_i(ic_data_req[way]),
						.write_i(ic_data_write),
						.addr_i(ic_data_addr),
						.wdata_i(ic_data_wdata),
						.wmask_i({LineSizeECC {1'b1}}),
						.rdata_o(ic_data_rdata[(1 - way) * LineSizeECC+:LineSizeECC]),
						.cfg_i(ram_cfg_icache_data_i[way * prim_ram_1p_pkg_Ram1pReqWidth+:prim_ram_1p_pkg_Ram1pReqWidth]),
						.cfg_o(ram_cfg_icache_data_o[way * prim_ram_1p_pkg_Ram1pRspWidth+:prim_ram_1p_pkg_Ram1pRspWidth])
					);
					assign icache_tag_alert = {ibex_pkg_IC_NUM_WAYS {1'b0}};
					assign icache_data_alert = {ibex_pkg_IC_NUM_WAYS {1'b0}};
				end
			end
		end
		else begin : gen_norams
			wire unused_ram_cfg;
			wire unused_ram_inputs;
			assign unused_ram_cfg = |{ram_cfg_icache_tag_i, ram_cfg_icache_data_i};
			assign ram_cfg_icache_tag_o = {ibex_pkg_IC_NUM_WAYS {sv2v_cast_C9369(prim_ram_1p_pkg_RAM_1P_CFG_RSP_DEFAULT)}};
			assign ram_cfg_icache_data_o = {ibex_pkg_IC_NUM_WAYS {sv2v_cast_C9369(prim_ram_1p_pkg_RAM_1P_CFG_RSP_DEFAULT)}};
			assign unused_ram_inputs = (((((((|ic_tag_req & ic_tag_write) & |ic_tag_addr) & |ic_tag_wdata) & |ic_data_req) & ic_data_write) & |ic_data_addr) & |ic_data_wdata) & |NumAddrScrRounds;
			assign ic_tag_rdata = {ibex_pkg_IC_NUM_WAYS {sv2v_cast_51117('b0)}};
			assign ic_data_rdata = {ibex_pkg_IC_NUM_WAYS {sv2v_cast_C86ED('b0)}};
			assign icache_tag_alert = {ibex_pkg_IC_NUM_WAYS {1'b0}};
			assign icache_data_alert = {ibex_pkg_IC_NUM_WAYS {1'b0}};
		end
	endgenerate
	assign data_wdata_o = data_wdata_core[31:0];
	generate
		if (MemECC) begin : gen_mem_wdata_ecc
			prim_buf #(.Width(7)) u_prim_buf_data_wdata_intg(
				.in_i(data_wdata_core[38:32]),
				.out_o(data_wdata_intg_o)
			);
		end
		else begin : gen_no_mem_ecc
			assign data_wdata_intg_o = 1'sb0;
		end
		if (Lockstep) begin : gen_lockstep
			localparam signed [31:0] NumBufferBits = (((((((((((((((((99 + MemDataWidth) + 73) + MemDataWidth) + 1) + RegFileDataWidth) + RegFileDataWidth) + ibex_pkg_IC_NUM_WAYS) + 1) + ibex_pkg_IC_INDEX_W) + TagSizeECC) + ibex_pkg_IC_NUM_WAYS) + 1) + ibex_pkg_IC_INDEX_W) + LineSizeECC) + 184) + ibex_pkg_IbexMuBiWidth) + ibex_pkg_IbexMuBiWidth) + ibex_pkg_IbexMuBiWidth;
			wire [NumBufferBits - 1:0] buf_in;
			wire [NumBufferBits - 1:0] buf_out;
			wire [31:0] hart_id_local;
			wire [31:0] boot_addr_local;
			wire instr_req_local;
			wire instr_gnt_local;
			wire instr_rvalid_local;
			wire [31:0] instr_addr_local;
			wire [MemDataWidth - 1:0] instr_rdata_local;
			wire instr_err_local;
			wire data_req_local;
			wire data_gnt_local;
			wire data_rvalid_local;
			wire data_we_local;
			wire [3:0] data_be_local;
			wire [31:0] data_addr_local;
			wire [31:0] data_wdata_local;
			wire [MemDataWidth - 1:0] data_rdata_local;
			wire data_err_local;
			wire [31:0] rf_rdata_a_local;
			wire [31:0] rf_rdata_b_local;
			wire [1:0] ic_tag_req_local;
			wire ic_tag_write_local;
			wire [ibex_pkg_IC_INDEX_W - 1:0] ic_tag_addr_local;
			wire [TagSizeECC - 1:0] ic_tag_wdata_local;
			wire [1:0] ic_data_req_local;
			wire ic_data_write_local;
			wire [ibex_pkg_IC_INDEX_W - 1:0] ic_data_addr_local;
			wire [LineSizeECC - 1:0] ic_data_wdata_local;
			wire scramble_key_valid_local;
			wire ic_scr_key_req_local;
			wire irq_software_local;
			wire irq_timer_local;
			wire irq_external_local;
			wire [14:0] irq_fast_local;
			wire irq_nm_local;
			wire irq_pending_local;
			wire debug_req_local;
			wire [159:0] crash_dump_local;
			wire double_fault_seen_local;
			wire [3:0] fetch_enable_local;
			wire [3:0] mcounteren_writable_local;
			wire [3:0] core_busy_local;
			assign buf_in = {hart_id_i, boot_addr_i, instr_req_o, instr_gnt_i, instr_rvalid_i, instr_addr_o, instr_rdata_core, instr_err_i, data_req_o, data_gnt_i, data_rvalid_i, data_we_o, data_be_o, data_addr_o, data_wdata_o, data_rdata_core, data_err_i, rf_rdata_a, rf_rdata_b, ic_tag_req, ic_tag_write, ic_tag_addr, ic_tag_wdata, ic_data_req, ic_data_write, ic_data_addr, ic_data_wdata, scramble_key_valid_q, ic_scr_key_req, irq_software_i, irq_timer_i, irq_external_i, irq_fast_i, irq_nm_i, irq_pending, debug_req_i, crash_dump_o, double_fault_seen_o, fetch_enable_i, mcounteren_writable_i, core_busy_d};
			assign {hart_id_local, boot_addr_local, instr_req_local, instr_gnt_local, instr_rvalid_local, instr_addr_local, instr_rdata_local, instr_err_local, data_req_local, data_gnt_local, data_rvalid_local, data_we_local, data_be_local, data_addr_local, data_wdata_local, data_rdata_local, data_err_local, rf_rdata_a_local, rf_rdata_b_local, ic_tag_req_local, ic_tag_write_local, ic_tag_addr_local, ic_tag_wdata_local, ic_data_req_local, ic_data_write_local, ic_data_addr_local, ic_data_wdata_local, scramble_key_valid_local, ic_scr_key_req_local, irq_software_local, irq_timer_local, irq_external_local, irq_fast_local, irq_nm_local, irq_pending_local, debug_req_local, crash_dump_local, double_fault_seen_local, fetch_enable_local, mcounteren_writable_local, core_busy_local} = buf_out;
			prim_buf #(.Width(NumBufferBits)) u_signals_prim_buf(
				.in_i(buf_in),
				.out_o(buf_out)
			);
			wire [(ibex_pkg_IC_NUM_WAYS * TagSizeECC) - 1:0] ic_tag_rdata_local;
			wire [(ibex_pkg_IC_NUM_WAYS * LineSizeECC) - 1:0] ic_data_rdata_local;
			genvar _gv_k_1;
			for (_gv_k_1 = 0; _gv_k_1 < ibex_pkg_IC_NUM_WAYS; _gv_k_1 = _gv_k_1 + 1) begin : gen_ways
				localparam k = _gv_k_1;
				prim_buf #(.Width(TagSizeECC)) u_tag_prim_buf(
					.in_i(ic_tag_rdata[(1 - k) * TagSizeECC+:TagSizeECC]),
					.out_o(ic_tag_rdata_local[(1 - k) * TagSizeECC+:TagSizeECC])
				);
				prim_buf #(.Width(LineSizeECC)) u_data_prim_buf(
					.in_i(ic_data_rdata[(1 - k) * LineSizeECC+:LineSizeECC]),
					.out_o(ic_data_rdata_local[(1 - k) * LineSizeECC+:LineSizeECC])
				);
			end
			wire lockstep_alert_minor_local;
			wire lockstep_alert_major_internal_local;
			wire lockstep_alert_major_bus_local;
			ibex_lockstep #(
				.PMPEnable(PMPEnable),
				.PMPGranularity(PMPGranularity),
				.PMPNumRegions(PMPNumRegions),
				.PMPRstCfg(PMPRstCfg),
				.PMPRstAddr(PMPRstAddr),
				.PMPRstMsecCfg(PMPRstMsecCfg),
				.MHPMCounterNum(MHPMCounterNum),
				.MHPMCounterWidth(MHPMCounterWidth),
				.RV32E(RV32E),
				.RV32M(RV32M),
				.RV32B(RV32B),
				.RV32ZC(RV32ZC),
				.BranchTargetALU(BranchTargetALU),
				.ICache(ICache),
				.ICacheECC(ICacheECC),
				.ICacheTweakInfection(ICacheTweakInfection),
				.BusSizeECC(BusSizeECC),
				.TagSizeECC(TagSizeECC),
				.LineSizeECC(LineSizeECC),
				.BranchPredictor(BranchPredictor),
				.DbgTriggerEn(DbgTriggerEn),
				.DbgHwBreakNum(DbgHwBreakNum),
				.WritebackStage(WritebackStage),
				.ResetAll(ResetAll),
				.RndCnstLfsrSeed(RndCnstLfsrSeed),
				.RndCnstLfsrPerm(RndCnstLfsrPerm),
				.SecureIbex(SecureIbex),
				.LockstepOffset(LockstepOffset),
				.DummyInstructions(DummyInstructions),
				.RegFileECC(RegFileLockstepECC),
				.RegFileDataWidth(RegFileDataWidth),
				.RegFileDataEccWidth(RegFileDataEccWidth),
				.RegFile(RegFile),
				.MemECC(MemECC),
				.DmBaseAddr(DmBaseAddr),
				.DmAddrMask(DmAddrMask),
				.DmHaltAddr(DmHaltAddr),
				.DmExceptionAddr(DmExceptionAddr),
				.CsrMvendorId(CsrMvendorId),
				.CsrMimpId(CsrMimpId)
			) u_ibex_lockstep(
				.clk_i(clk),
				.rst_ni(rst_ni),
				.hart_id_i(hart_id_local),
				.boot_addr_i(boot_addr_local),
				.instr_req_i(instr_req_local),
				.instr_gnt_i(instr_gnt_local),
				.instr_rvalid_i(instr_rvalid_local),
				.instr_addr_i(instr_addr_local),
				.instr_rdata_i(instr_rdata_local),
				.instr_err_i(instr_err_local),
				.data_req_i(data_req_local),
				.data_gnt_i(data_gnt_local),
				.data_rvalid_i(data_rvalid_local),
				.data_we_i(data_we_local),
				.data_be_i(data_be_local),
				.data_addr_i(data_addr_local),
				.data_wdata_i(data_wdata_local),
				.data_rdata_i(data_rdata_local),
				.data_err_i(data_err_local),
				.rf_rdata_a_i(rf_rdata_a_local),
				.rf_rdata_b_i(rf_rdata_b_local),
				.ic_tag_req_i(ic_tag_req_local),
				.ic_tag_write_i(ic_tag_write_local),
				.ic_tag_addr_i(ic_tag_addr_local),
				.ic_tag_wdata_i(ic_tag_wdata_local),
				.ic_tag_rdata_i(ic_tag_rdata_local),
				.ic_data_req_i(ic_data_req_local),
				.ic_data_write_i(ic_data_write_local),
				.ic_data_addr_i(ic_data_addr_local),
				.ic_data_wdata_i(ic_data_wdata_local),
				.ic_data_rdata_i(ic_data_rdata_local),
				.ic_scr_key_valid_i(scramble_key_valid_local),
				.ic_scr_key_req_i(ic_scr_key_req_local),
				.irq_software_i(irq_software_local),
				.irq_timer_i(irq_timer_local),
				.irq_external_i(irq_external_local),
				.irq_fast_i(irq_fast_local),
				.irq_nm_i(irq_nm_local),
				.irq_pending_i(irq_pending_local),
				.debug_req_i(debug_req_local),
				.crash_dump_i(crash_dump_local),
				.double_fault_seen_i(double_fault_seen_local),
				.fetch_enable_i(fetch_enable_local),
				.mcounteren_writable_i(mcounteren_writable_local),
				.alert_minor_o(lockstep_alert_minor_local),
				.alert_major_internal_o(lockstep_alert_major_internal_local),
				.alert_major_bus_o(lockstep_alert_major_bus_local),
				.core_busy_i(core_busy_local),
				.test_en_i(test_en_i),
				.scan_rst_ni(scan_rst_ni),
				.lockstep_cmp_en_o(lockstep_cmp_en_o),
				.data_req_shadow_o(data_req_shadow_o),
				.data_we_shadow_o(data_we_shadow_o),
				.data_be_shadow_o(data_be_shadow_o),
				.data_addr_shadow_o(data_addr_shadow_o),
				.data_wdata_shadow_o(data_wdata_shadow_o),
				.data_wdata_intg_shadow_o(data_wdata_intg_shadow_o),
				.instr_req_shadow_o(instr_req_shadow_o),
				.instr_addr_shadow_o(instr_addr_shadow_o)
			);
			prim_buf u_prim_buf_alert_minor(
				.in_i(lockstep_alert_minor_local),
				.out_o(lockstep_alert_minor)
			);
			prim_buf u_prim_buf_alert_major_internal(
				.in_i(lockstep_alert_major_internal_local),
				.out_o(lockstep_alert_major_internal)
			);
			prim_buf u_prim_buf_alert_major_bus(
				.in_i(lockstep_alert_major_bus_local),
				.out_o(lockstep_alert_major_bus)
			);
		end
		else begin : gen_no_lockstep
			assign lockstep_alert_major_internal = 1'b0;
			assign lockstep_alert_major_bus = 1'b0;
			assign lockstep_alert_minor = 1'b0;
			assign lockstep_cmp_en_o = ibex_pkg_IbexMuBiOff;
			assign data_req_shadow_o = 1'b0;
			assign data_we_shadow_o = 1'b0;
			assign data_be_shadow_o = 1'sb0;
			assign data_addr_shadow_o = 1'sb0;
			assign data_wdata_shadow_o = 1'sb0;
			assign data_wdata_intg_shadow_o = 1'sb0;
			assign instr_req_shadow_o = 1'b0;
			assign instr_addr_shadow_o = 1'sb0;
			wire unused_scan;
			assign unused_scan = scan_rst_ni;
		end
	endgenerate
	wire icache_alert_major_internal;
	assign icache_alert_major_internal = |icache_tag_alert | (|icache_data_alert);
	assign alert_major_internal_o = (core_alert_major_internal | lockstep_alert_major_internal) | icache_alert_major_internal;
	assign alert_major_bus_o = core_alert_major_bus | lockstep_alert_major_bus;
	assign alert_minor_o = core_alert_minor | lockstep_alert_minor;
	localparam [31:0] MaxOutstandingDSideAccesses = 2;
	reg [1:0] pending_dside_accesses_q [0:1];
	reg [1:0] pending_dside_accesses_d [0:1];
	reg [1:0] pending_dside_accesses_shifted [0:1];
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < MaxOutstandingDSideAccesses; _gv_i_1 = _gv_i_1 + 1) begin : g_dside_tracker
			localparam i = _gv_i_1;
			always @(posedge clk or negedge rst_ni)
				if (!rst_ni)
					pending_dside_accesses_q[i] <= 1'sb0;
				else
					pending_dside_accesses_q[i] <= pending_dside_accesses_d[i];
			always @(*) begin
				if (_sv2v_0)
					;
				pending_dside_accesses_shifted[i] = pending_dside_accesses_q[i];
				if (data_rvalid_i) begin
					if (i != 1)
						pending_dside_accesses_shifted[i] = pending_dside_accesses_q[i + 1];
					else
						pending_dside_accesses_shifted[i] = 1'sb0;
				end
			end
			if (i == 0) begin : g_track_first_entry
				always @(*) begin
					if (_sv2v_0)
						;
					pending_dside_accesses_d[i] = pending_dside_accesses_shifted[i];
					if ((data_req_o && data_gnt_i) && !pending_dside_accesses_shifted[i][1]) begin
						pending_dside_accesses_d[i][1] = 1'b1;
						pending_dside_accesses_d[i][0] = ~data_we_o;
					end
				end
			end
			else begin : g_track_other_entries
				always @(*) begin
					if (_sv2v_0)
						;
					pending_dside_accesses_d[i] = pending_dside_accesses_shifted[i];
					if (((data_req_o && data_gnt_i) && pending_dside_accesses_shifted[i - 1][1]) && !pending_dside_accesses_shifted[i][1]) begin
						pending_dside_accesses_d[i][1] = 1'b1;
						pending_dside_accesses_d[i][0] = ~data_we_o;
					end
				end
			end
		end
		if (MemECC) begin : g_mem_ecc_asserts
			wire [1:0] data_ecc_err;
			wire [1:0] instr_ecc_err;
			prim_secded_inv_39_32_dec u_data_intg_dec(
				.data_i(data_rdata_core),
				.data_o(),
				.syndrome_o(),
				.err_o(data_ecc_err)
			);
			prim_secded_inv_39_32_dec u_instr_intg_dec(
				.data_i(instr_rdata_core),
				.data_o(),
				.syndrome_o(),
				.err_o(instr_ecc_err)
			);
		end
	endgenerate
	initial _sv2v_0 = 0;
endmodule
module chip_top_full (
	clk,
	clk_int,
	rst_n,
	scan_in,
	scan_shift,
	scan_load,
	scan_i0o1,
	scan_out,
	gpio_out,
	gpio_in,
	uart_tx,
	uart_rx,
	spi_sclk,
	spi_mosi,
	spi_cs_n
);
	parameter signed [31:0] NUM_OUT = 5;
	parameter signed [31:0] NUM_IN = 2;
	parameter signed [31:0] CLK_FREQ = 8;
	parameter signed [31:0] BAUD_RATE = 1;
	parameter signed [31:0] SPI_CLK_DIV = 2;
	input wire clk;
	input wire clk_int;
	input wire rst_n;
	input wire scan_in;
	input wire scan_shift;
	input wire scan_load;
	input wire scan_i0o1;
	output wire scan_out;
	output wire [NUM_OUT - 1:0] gpio_out;
	input wire [NUM_IN - 1:0] gpio_in;
	output wire uart_tx;
	input wire uart_rx;
	output wire spi_sclk;
	output wire spi_mosi;
	output wire spi_cs_n;
	wire clkgen_cfg_load;
	wire clkgen_int;
	wire [7:0] clkgen_div;
	wire sys_clk;
	wire use_internal;
	assign use_internal = clkgen_int & clk_int;
	clk_gen u_clkgen(
		.ref_clk(clk),
		.clk_ext(clk),
		.rst_n(rst_n),
		.clk_int(use_internal),
		.cfg_load(clkgen_cfg_load),
		.cfg_div_in(clkgen_div),
		.clk_out(sys_clk)
	);
	wire scan_mem_we;
	wire [15:0] scan_mem_addr;
	wire [31:0] scan_mem_wdata;
	wire [31:0] scan_mem_rdata;
	wire fsm_cfg_load;
	wire [1:0] fsm_mode;
	wire [15:0] fsm_count;
	scan_chain u_scan(
		.clk(sys_clk),
		.rst_n(rst_n),
		.scan_in(scan_in),
		.scan_shift(scan_shift),
		.scan_load(scan_load),
		.scan_i0o1(scan_i0o1),
		.scan_out(scan_out),
		.mem_we(scan_mem_we),
		.mem_addr(scan_mem_addr),
		.mem_wdata(scan_mem_wdata),
		.mem_rdata(scan_mem_rdata),
		.fsm_cfg_load(fsm_cfg_load),
		.fsm_mode(fsm_mode),
		.fsm_count(fsm_count),
		.clk_cfg_load(clkgen_cfg_load),
		.clk_int(clkgen_int),
		.clk_div(clkgen_div)
	);
	wire cpu_clk;
	wire scan_owns_mem;
	wire [1:0] fsm_mode_o;
	test_fsm u_fsm(
		.clk(sys_clk),
		.rst_n(rst_n),
		.cfg_load(fsm_cfg_load),
		.cfg_mode_in(fsm_mode),
		.cfg_count_in(fsm_count),
		.cpu_clk(cpu_clk),
		.scan_owns_mem(scan_owns_mem),
		.mode_o(fsm_mode_o)
	);
	wire instr_req;
	wire instr_gnt;
	wire instr_rvalid;
	wire [31:0] instr_addr;
	wire [31:0] instr_rdata;
	wire data_req;
	wire data_gnt;
	wire data_rvalid;
	wire data_we;
	wire [3:0] data_be;
	wire [31:0] data_addr;
	wire [31:0] data_wdata;
	wire [31:0] data_rdata;
	wire [6:0] instr_rdata_intg;
	wire [6:0] data_rdata_intg;
	assign instr_rdata_intg = 7'b0000000;
	assign data_rdata_intg = 7'b0000000;
	localparam signed [31:0] ibex_pkg_IbexMuBiWidth = 4;
	localparam [3:0] ibex_pkg_IbexMuBiOn = 4'b0101;
	localparam [31:0] prim_ram_1p_pkg_Ram1pReqWidth = 32'd12;
	localparam [11:0] prim_ram_1p_pkg_RAM_1P_CFG_REQ_DEFAULT = 1'sb0;
	localparam [31:0] sv2v_uu_u_ibex_ibex_pkg_SCRAMBLE_KEY_W = 128;
	localparam [127:0] sv2v_uu_u_ibex_ext_scramble_key_i_0 = 1'sb0;
	localparam [31:0] sv2v_uu_u_ibex_ibex_pkg_SCRAMBLE_NONCE_W = 64;
	localparam [63:0] sv2v_uu_u_ibex_ext_scramble_nonce_i_0 = 1'sb0;
	ibex_top #(
		.PMPEnable(1'b0),
		.MHPMCounterNum(0),
		.RV32E(1'b0),
		.RV32M(32'sd2),
		.RV32B(32'sd0),
		.ICache(1'b0),
		.DbgTriggerEn(1'b0),
		.SecureIbex(1'b0)
	) u_ibex(
		.clk_i(cpu_clk),
		.rst_ni(rst_n),
		.test_en_i(1'b0),
		.scan_rst_ni(1'b1),
		.ram_cfg_icache_tag_i('0),
		.ram_cfg_icache_tag_o(),
		.ram_cfg_icache_data_i('0),
		.ram_cfg_icache_data_o(),
		.hart_id_i(32'b00000000000000000000000000000000),
		.boot_addr_i(32'h00000000),
		.instr_req_o(instr_req),
		.instr_gnt_i(instr_gnt),
		.instr_rvalid_i(instr_rvalid),
		.instr_addr_o(instr_addr),
		.instr_rdata_i(instr_rdata),
		.instr_rdata_intg_i(instr_rdata_intg),
		.instr_err_i(1'b0),
		.data_req_o(data_req),
		.data_gnt_i(data_gnt),
		.data_rvalid_i(data_rvalid),
		.data_we_o(data_we),
		.data_be_o(data_be),
		.data_addr_o(data_addr),
		.data_wdata_o(data_wdata),
		.data_wdata_intg_o(),
		.data_rdata_i(data_rdata),
		.data_rdata_intg_i(data_rdata_intg),
		.data_err_i(1'b0),
		.irq_software_i(1'b0),
		.irq_timer_i(1'b0),
		.irq_external_i(1'b0),
		.irq_fast_i(15'b000000000000000),
		.irq_nm_i(1'b0),
		.scramble_key_valid_i(1'b0),
		.scramble_key_i(sv2v_uu_u_ibex_ext_scramble_key_i_0),
		.scramble_nonce_i(sv2v_uu_u_ibex_ext_scramble_nonce_i_0),
		.scramble_req_o(),
		.debug_req_i(1'b0),
		.crash_dump_o(),
		.double_fault_seen_o(),
		.fetch_enable_i(ibex_pkg_IbexMuBiOn),
		.mcounteren_writable_i(ibex_pkg_IbexMuBiOn),
		.alert_minor_o(),
		.alert_major_internal_o(),
		.alert_major_bus_o(),
		.core_sleep_o(),
		.lockstep_cmp_en_o(),
		.data_req_shadow_o(),
		.data_we_shadow_o(),
		.data_be_shadow_o(),
		.data_addr_shadow_o(),
		.data_wdata_shadow_o(),
		.data_wdata_intg_shadow_o(),
		.instr_req_shadow_o(),
		.instr_addr_shadow_o()
	);
	mem_subsystem u_mem(
		.clk(sys_clk),
		.rst_n_in(rst_n),
		.instr_req_i(instr_req),
		.instr_gnt_o(instr_gnt),
		.instr_addr_i(instr_addr),
		.instr_rvalid_o(instr_rvalid),
		.instr_rdata_o(instr_rdata),
		.data_req_i(1'b0),
		.data_gnt_o(),
		.data_we_i(1'b0),
		.data_be_i(4'b0000),
		.data_addr_i(32'b00000000000000000000000000000000),
		.data_wdata_i(32'b00000000000000000000000000000000),
		.data_rvalid_o(),
		.data_rdata_o(),
		.scan_owns_mem(scan_owns_mem),
		.scan_we(scan_mem_we),
		.scan_addr(scan_mem_addr),
		.scan_wdata(scan_mem_wdata),
		.scan_sel_dmem(1'b0)
	);
	wire [31:0] HADDR;
	wire [31:0] HWDATA;
	wire [31:0] HRDATA;
	wire [1:0] HTRANS;
	wire HWRITE;
	wire HREADY;
	wire HRESP;
	wire [3:0] HWSTRB;
	wire [3:0] HSEL;
	wire [31:0] slv_HADDR;
	wire [31:0] slv_HWDATA;
	wire [1:0] slv_HTRANS;
	wire slv_HWRITE;
	wire [31:0] s0_HRDATA;
	wire [31:0] s1_HRDATA;
	wire s0_HREADY;
	wire s0_HRESP;
	wire s1_HREADY;
	wire s1_HRESP;
	ibex_to_ahb u_adapter(
		.clk(cpu_clk),
		.rst_n(rst_n),
		.req(data_req),
		.gnt(data_gnt),
		.we(data_we),
		.be(data_be),
		.addr(data_addr),
		.wdata(data_wdata),
		.rvalid(data_rvalid),
		.rdata(data_rdata),
		.HADDR(HADDR),
		.HTRANS(HTRANS),
		.HWRITE(HWRITE),
		.HWSTRB(HWSTRB),
		.HWDATA(HWDATA),
		.HRDATA(HRDATA),
		.HREADY(HREADY),
		.HRESP(HRESP)
	);
	ahb_interconnect u_ic(
		.HCLK(cpu_clk),
		.HRESETn(rst_n),
		.HADDR(HADDR),
		.HTRANS(HTRANS),
		.HWRITE(HWRITE),
		.HWDATA(HWDATA),
		.HRDATA(HRDATA),
		.HREADY(HREADY),
		.HRESP(HRESP),
		.HSEL(HSEL),
		.slv_HADDR(slv_HADDR),
		.slv_HTRANS(slv_HTRANS),
		.slv_HWRITE(slv_HWRITE),
		.slv_HWDATA(slv_HWDATA),
		.s0_HRDATA(s0_HRDATA),
		.s0_HREADY(s0_HREADY),
		.s0_HRESP(s0_HRESP),
		.s1_HRDATA(s1_HRDATA),
		.s1_HREADY(s1_HREADY),
		.s1_HRESP(s1_HRESP),
		.s2_HRDATA(s1_HRDATA),
		.s2_HREADY(s1_HREADY),
		.s2_HRESP(s1_HRESP),
		.s3_HRDATA(s1_HRDATA),
		.s3_HREADY(s1_HREADY),
		.s3_HRESP(s1_HRESP)
	);
	ahb_mem u_dmem_slave(
		.HCLK(cpu_clk),
		.HRESETn(rst_n),
		.HSEL(HSEL[0]),
		.HADDR(slv_HADDR),
		.HTRANS(slv_HTRANS),
		.HWRITE(slv_HWRITE),
		.HWSTRB(HWSTRB),
		.HWDATA(slv_HWDATA),
		.HRDATA(s0_HRDATA),
		.HREADY(s0_HREADY),
		.HRESP(s0_HRESP)
	);
	wire PSEL;
	wire PENABLE;
	wire PWRITE;
	wire PREADY;
	wire [31:0] PADDR;
	wire [31:0] PWDATA;
	wire [31:0] PRDATA;
	ahb_to_apb u_bridge(
		.HCLK(cpu_clk),
		.HRESETn(rst_n),
		.HSEL((HSEL[1] | HSEL[2]) | HSEL[3]),
		.HADDR(slv_HADDR),
		.HTRANS(slv_HTRANS),
		.HWRITE(slv_HWRITE),
		.HWDATA(slv_HWDATA),
		.HRDATA(s1_HRDATA),
		.HREADY(s1_HREADY),
		.HRESP(s1_HRESP),
		.PSEL(PSEL),
		.PENABLE(PENABLE),
		.PWRITE(PWRITE),
		.PADDR(PADDR),
		.PWDATA(PWDATA),
		.PRDATA(PRDATA),
		.PREADY(PREADY)
	);
	wire gpio_PSEL;
	wire uart_PSEL;
	wire spi_PSEL;
	wire [31:0] gpio_PRDATA;
	wire [31:0] uart_PRDATA;
	wire [31:0] spi_PRDATA;
	wire gpio_PREADY;
	wire uart_PREADY;
	wire spi_PREADY;
	wire p_PENABLE;
	wire p_PWRITE;
	wire [31:0] p_PADDR;
	wire [31:0] p_PWDATA;
	apb_decoder u_apbdec(
		.PSEL(PSEL),
		.PENABLE(PENABLE),
		.PWRITE(PWRITE),
		.PADDR(PADDR),
		.PWDATA(PWDATA),
		.PRDATA(PRDATA),
		.PREADY(PREADY),
		.gpio_PSEL(gpio_PSEL),
		.gpio_PRDATA(gpio_PRDATA),
		.gpio_PREADY(gpio_PREADY),
		.uart_PSEL(uart_PSEL),
		.uart_PRDATA(uart_PRDATA),
		.uart_PREADY(uart_PREADY),
		.spi_PSEL(spi_PSEL),
		.spi_PRDATA(spi_PRDATA),
		.spi_PREADY(spi_PREADY),
		.p_PENABLE(p_PENABLE),
		.p_PWRITE(p_PWRITE),
		.p_PADDR(p_PADDR),
		.p_PWDATA(p_PWDATA)
	);
	apb_gpio #(
		.NUM_OUT(NUM_OUT),
		.NUM_IN(NUM_IN)
	) u_gpio(
		.PCLK(cpu_clk),
		.PRESETn(rst_n),
		.PSEL(gpio_PSEL),
		.PENABLE(p_PENABLE),
		.PWRITE(p_PWRITE),
		.PADDR(p_PADDR),
		.PWDATA(p_PWDATA),
		.PRDATA(gpio_PRDATA),
		.PREADY(gpio_PREADY),
		.gpio_out(gpio_out),
		.gpio_in(gpio_in)
	);
	apb_uart #(
		.CLK_FREQ(CLK_FREQ),
		.BAUD_RATE(BAUD_RATE)
	) u_uart(
		.PCLK(cpu_clk),
		.PRESETn(rst_n),
		.PSEL(uart_PSEL),
		.PENABLE(p_PENABLE),
		.PWRITE(p_PWRITE),
		.PADDR(p_PADDR),
		.PWDATA(p_PWDATA),
		.PRDATA(uart_PRDATA),
		.PREADY(uart_PREADY),
		.tx(uart_tx),
		.rx(uart_rx)
	);
	apb_spi #(.CLK_DIV(SPI_CLK_DIV)) u_spi(
		.PCLK(cpu_clk),
		.PRESETn(rst_n),
		.PSEL(spi_PSEL),
		.PENABLE(p_PENABLE),
		.PWRITE(p_PWRITE),
		.PADDR(p_PADDR),
		.PWDATA(p_PWDATA),
		.PRDATA(spi_PRDATA),
		.PREADY(spi_PREADY),
		.sclk(spi_sclk),
		.mosi(spi_mosi),
		.miso(1'b0),
		.cs_n(spi_cs_n)
	);
endmodule
module mem_subsystem (
	clk,
	rst_n_in,
	instr_req_i,
	instr_gnt_o,
	instr_addr_i,
	instr_rvalid_o,
	instr_rdata_o,
	data_req_i,
	data_gnt_o,
	data_we_i,
	data_be_i,
	data_addr_i,
	data_wdata_i,
	data_rvalid_o,
	data_rdata_o,
	scan_owns_mem,
	scan_we,
	scan_addr,
	scan_wdata,
	scan_sel_dmem
);
	input wire clk;
	input wire rst_n_in;
	input wire instr_req_i;
	output wire instr_gnt_o;
	input wire [31:0] instr_addr_i;
	output wire instr_rvalid_o;
	output wire [31:0] instr_rdata_o;
	input wire data_req_i;
	output wire data_gnt_o;
	input wire data_we_i;
	input wire [3:0] data_be_i;
	input wire [31:0] data_addr_i;
	input wire [31:0] data_wdata_i;
	output wire data_rvalid_o;
	output wire [31:0] data_rdata_o;
	input wire scan_owns_mem;
	input wire scan_we;
	input wire [15:0] scan_addr;
	input wire [31:0] scan_wdata;
	input wire scan_sel_dmem;
	wire rst_n;
	rst_sync u_rst_sync(
		.clk(clk),
		.rst_n_in(rst_n_in),
		.rst_n_out(rst_n)
	);
	wire imem_ld_en;
	assign imem_ld_en = (scan_owns_mem & ~scan_sel_dmem) & scan_we;
	imem_narrow_top u_imem(
		.clk(clk),
		.rst_n(rst_n),
		.req(instr_req_i),
		.gnt(instr_gnt_o),
		.addr(instr_addr_i),
		.rvalid(instr_rvalid_o),
		.rdata(instr_rdata_o),
		.ld_word_en(imem_ld_en),
		.ld_word_addr(scan_addr),
		.ld_word_data(scan_wdata),
		.ld_busy()
	);
	wire dmem_ld_en;
	assign dmem_ld_en = (scan_owns_mem & scan_sel_dmem) & scan_we;
	dmem_narrow_top u_dmem(
		.clk(clk),
		.rst_n(rst_n),
		.req(data_req_i),
		.gnt(data_gnt_o),
		.we(data_we_i),
		.be(data_be_i),
		.addr(data_addr_i),
		.wdata(data_wdata_i),
		.rvalid(data_rvalid_o),
		.rdata(data_rdata_o),
		.ld_word_en(dmem_ld_en),
		.ld_word_addr(scan_addr),
		.ld_word_data(scan_wdata),
		.ld_busy()
	);
endmodule
module imem_narrow_top (
	clk,
	rst_n,
	req,
	gnt,
	addr,
	rvalid,
	rdata,
	ld_word_en,
	ld_word_addr,
	ld_word_data,
	ld_busy
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire req;
	output wire gnt;
	input wire [31:0] addr;
	output wire rvalid;
	output wire [31:0] rdata;
	input wire ld_word_en;
	input wire [15:0] ld_word_addr;
	input wire [31:0] ld_word_data;
	output wire ld_busy;
	wire g_m_req;
	wire g_m_sel;
	wire g_m_gnt;
	wire g_m_rvalid;
	wire [31:0] g_m_addr;
	wire [7:0] g_m_rdata;
	reg s_ld_en;
	reg [8:0] s_ld_addr;
	reg [7:0] s_ld_data;
	reg [2:0] sstate;
	reg [31:0] word_lat;
	reg [8:0] base_lat;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			sstate <= 3'd0;
			word_lat <= 32'b00000000000000000000000000000000;
			base_lat <= 9'b000000000;
		end
		else
			case (sstate)
				3'd0:
					if (ld_word_en) begin
						word_lat <= ld_word_data;
						base_lat <= {ld_word_addr[6:0], 2'b00};
						sstate <= 3'd1;
					end
				3'd1: sstate <= 3'd2;
				3'd2: sstate <= 3'd3;
				3'd3: sstate <= 3'd4;
				3'd4: sstate <= 3'd0;
				default: sstate <= 3'd0;
			endcase
	always @(*) begin
		if (_sv2v_0)
			;
		s_ld_en = 1'b0;
		s_ld_addr = 9'b000000000;
		s_ld_data = 8'b00000000;
		case (sstate)
			3'd1: begin
				s_ld_en = 1;
				s_ld_addr = base_lat + 9'd0;
				s_ld_data = word_lat[7:0];
			end
			3'd2: begin
				s_ld_en = 1;
				s_ld_addr = base_lat + 9'd1;
				s_ld_data = word_lat[15:8];
			end
			3'd3: begin
				s_ld_en = 1;
				s_ld_addr = base_lat + 9'd2;
				s_ld_data = word_lat[23:16];
			end
			3'd4: begin
				s_ld_en = 1;
				s_ld_addr = base_lat + 9'd3;
				s_ld_data = word_lat[31:24];
			end
			default:
				;
		endcase
	end
	assign ld_busy = sstate != 3'd0;
	fetch_gather u_gather(
		.clk(clk),
		.rst_n(rst_n),
		.c_req(req),
		.c_gnt(gnt),
		.c_addr(addr),
		.c_rvalid(rvalid),
		.c_rdata(rdata),
		.m_req(g_m_req),
		.m_sel(g_m_sel),
		.m_gnt(g_m_gnt),
		.m_addr(g_m_addr),
		.m_rvalid(g_m_rvalid),
		.m_rdata(g_m_rdata)
	);
	imem_narrow u_mem(
		.clk(clk),
		.rst_n(rst_n),
		.m_req(g_m_req),
		.m_sel(g_m_sel),
		.m_gnt(g_m_gnt),
		.m_addr(g_m_addr),
		.m_rvalid(g_m_rvalid),
		.m_rdata(g_m_rdata),
		.ld_en(s_ld_en),
		.ld_addr(s_ld_addr),
		.ld_data(s_ld_data)
	);
	initial _sv2v_0 = 0;
endmodule
module imem_narrow (
	clk,
	rst_n,
	m_req,
	m_sel,
	m_gnt,
	m_addr,
	m_rvalid,
	m_rdata,
	ld_en,
	ld_addr,
	ld_data
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire m_req;
	input wire m_sel;
	output wire m_gnt;
	input wire [31:0] m_addr;
	output wire m_rvalid;
	output wire [7:0] m_rdata;
	input wire ld_en;
	input wire [8:0] ld_addr;
	input wire [7:0] ld_data;
	assign m_gnt = 1'b1;
	reg cen;
	reg gwen;
	reg [7:0] wen;
	reg [7:0] d;
	wire [7:0] q;
	reg [8:0] a;
	wire [8:0] rd_addr;
	assign rd_addr = m_addr[8:0];
	always @(*) begin
		if (_sv2v_0)
			;
		if (ld_en) begin
			cen = 1'b0;
			gwen = 1'b0;
			wen = 8'h00;
			a = ld_addr;
			d = ld_data;
		end
		else if (m_sel) begin
			cen = 1'b0;
			gwen = 1'b1;
			wen = 8'hff;
			a = rd_addr;
			d = 8'h00;
		end
		else begin
			cen = 1'b1;
			gwen = 1'b1;
			wen = 8'hff;
			a = 9'b000000000;
			d = 8'h00;
		end
	end
	supply1 vdd;
	supply0 vss;
	gf180mcu_fd_ip_sram__sram512x8m8wm1 u_sram(
		.CLK(clk),
		.CEN(cen),
		.GWEN(gwen),
		.WEN(wen),
		.A(a),
		.D(d),
		.Q(q),
		.VDD(vdd),
		.VSS(vss)
	);
	reg rd_pending;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			rd_pending <= 1'b0;
		else
			rd_pending <= m_req & ~ld_en;
	assign m_rvalid = rd_pending;
	assign m_rdata = q;
	initial _sv2v_0 = 0;
endmodule
module fetch_gather (
	clk,
	rst_n,
	c_req,
	c_gnt,
	c_addr,
	c_rvalid,
	c_rdata,
	m_req,
	m_sel,
	m_gnt,
	m_addr,
	m_rvalid,
	m_rdata
);
	input wire clk;
	input wire rst_n;
	input wire c_req;
	output wire c_gnt;
	input wire [31:0] c_addr;
	output wire c_rvalid;
	output wire [31:0] c_rdata;
	output wire m_req;
	output wire m_sel;
	input wire m_gnt;
	output wire [31:0] m_addr;
	input wire m_rvalid;
	input wire [7:0] m_rdata;
	reg [1:0] state;
	reg [31:0] base_addr;
	reg [2:0] issue_cnt;
	reg [2:0] cap_cnt;
	reg [7:0] b0;
	reg [7:0] b1;
	reg [7:0] b2;
	reg [7:0] b3;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			state <= 2'd0;
			base_addr <= 32'b00000000000000000000000000000000;
			issue_cnt <= 0;
			cap_cnt <= 0;
			b0 <= 0;
			b1 <= 0;
			b2 <= 0;
			b3 <= 0;
		end
		else
			case (state)
				2'd0:
					if (c_req) begin
						base_addr <= c_addr;
						issue_cnt <= 0;
						cap_cnt <= 0;
						state <= 2'd1;
					end
				2'd1: begin
					if (issue_cnt < 3'd4)
						issue_cnt <= issue_cnt + 3'd1;
					if (m_rvalid) begin
						case (cap_cnt[1:0])
							2'd0: b0 <= m_rdata;
							2'd1: b1 <= m_rdata;
							2'd2: b2 <= m_rdata;
							2'd3: b3 <= m_rdata;
						endcase
						cap_cnt <= cap_cnt + 3'd1;
					end
					if (issue_cnt == 3'd4)
						state <= 2'd2;
				end
				2'd2: begin
					if (m_rvalid) begin
						case (cap_cnt[1:0])
							2'd0: b0 <= m_rdata;
							2'd1: b1 <= m_rdata;
							2'd2: b2 <= m_rdata;
							2'd3: b3 <= m_rdata;
						endcase
						cap_cnt <= cap_cnt + 3'd1;
					end
					if (cap_cnt == 3'd4)
						state <= 2'd3;
				end
				2'd3: state <= 2'd0;
				default: state <= 2'd0;
			endcase
	assign m_req = (state == 2'd1) && (issue_cnt < 3'd4);
	assign m_sel = (state == 2'd1) || (state == 2'd2);
	assign m_addr = (state == 2'd2 ? base_addr + 32'd3 : base_addr + {29'b00000000000000000000000000000, issue_cnt[1:0]});
	assign c_gnt = (state == 2'd0) && c_req;
	assign c_rvalid = state == 2'd3;
	assign c_rdata = {b3, b2, b1, b0};
endmodule
module dmem_narrow_top (
	clk,
	rst_n,
	req,
	gnt,
	we,
	be,
	addr,
	wdata,
	rvalid,
	rdata,
	ld_word_en,
	ld_word_addr,
	ld_word_data,
	ld_busy
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire req;
	output wire gnt;
	input wire we;
	input wire [3:0] be;
	input wire [31:0] addr;
	input wire [31:0] wdata;
	output wire rvalid;
	output wire [31:0] rdata;
	input wire ld_word_en;
	input wire [15:0] ld_word_addr;
	input wire [31:0] ld_word_data;
	output wire ld_busy;
	reg b_req;
	reg b_sel;
	reg b_we;
	wire b_rvalid;
	reg [31:0] b_addr;
	reg [7:0] b_wdata;
	wire [7:0] b_rdata;
	dmem_narrow #(.ADDR_BITS(6)) u_mem(
		.clk(clk),
		.rst_n(rst_n),
		.b_req(b_req),
		.b_sel(b_sel),
		.b_we(b_we),
		.b_addr(b_addr),
		.b_wdata(b_wdata),
		.b_rvalid(b_rvalid),
		.b_rdata(b_rdata)
	);
	reg [3:0] state;
	reg [31:0] base_addr;
	reg [31:0] wdata_lat;
	reg [3:0] be_lat;
	reg [2:0] issue_cnt;
	reg [2:0] cap_cnt;
	reg [7:0] b0;
	reg [7:0] b1;
	reg [7:0] b2;
	reg [7:0] b3;
	reg [31:0] lword;
	reg [5:0] lbase;
	wire [31:0] addr_aligned;
	assign addr_aligned = {addr[31:2], 2'b00};
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			state <= 4'd0;
			base_addr <= 0;
			wdata_lat <= 0;
			be_lat <= 0;
			issue_cnt <= 0;
			cap_cnt <= 0;
			b0 <= 0;
			b1 <= 0;
			b2 <= 0;
			b3 <= 0;
			lword <= 0;
			lbase <= 0;
		end
		else
			case (state)
				4'd0:
					if (ld_word_en) begin
						lword <= ld_word_data;
						lbase <= {ld_word_addr[3:0], 2'b00};
						state <= 4'd9;
					end
					else if (req) begin
						base_addr <= addr_aligned;
						wdata_lat <= wdata;
						be_lat <= be;
						issue_cnt <= 0;
						cap_cnt <= 0;
						if (we)
							state <= 4'd4;
						else
							state <= 4'd1;
					end
				4'd1: begin
					if (issue_cnt < 3'd4)
						issue_cnt <= issue_cnt + 3'd1;
					if (b_rvalid) begin
						case (cap_cnt[1:0])
							2'd0: b0 <= b_rdata;
							2'd1: b1 <= b_rdata;
							2'd2: b2 <= b_rdata;
							2'd3: b3 <= b_rdata;
						endcase
						cap_cnt <= cap_cnt + 3'd1;
					end
					if (issue_cnt == 3'd4)
						state <= 4'd2;
				end
				4'd2: begin
					if (b_rvalid) begin
						case (cap_cnt[1:0])
							2'd0: b0 <= b_rdata;
							2'd1: b1 <= b_rdata;
							2'd2: b2 <= b_rdata;
							2'd3: b3 <= b_rdata;
						endcase
						cap_cnt <= cap_cnt + 3'd1;
					end
					if (cap_cnt == 3'd4)
						state <= 4'd3;
				end
				4'd3: state <= 4'd0;
				4'd4: state <= 4'd5;
				4'd5: state <= 4'd6;
				4'd6: state <= 4'd7;
				4'd7: state <= 4'd8;
				4'd8: state <= 4'd0;
				4'd9: state <= 4'd10;
				4'd10: state <= 4'd11;
				4'd11: state <= 4'd12;
				4'd12: state <= 4'd0;
				default: state <= 4'd0;
			endcase
	always @(*) begin
		if (_sv2v_0)
			;
		b_req = 1'b0;
		b_sel = 1'b0;
		b_we = 1'b0;
		b_addr = 32'b00000000000000000000000000000000;
		b_wdata = 8'b00000000;
		case (state)
			4'd1: begin
				b_sel = 1'b1;
				if (issue_cnt < 3'd4) begin
					b_req = 1'b1;
					b_addr = base_addr + {29'b00000000000000000000000000000, issue_cnt[1:0]};
				end
				else
					b_addr = base_addr + 32'd3;
			end
			4'd2: begin
				b_sel = 1'b1;
				b_addr = base_addr + 32'd3;
			end
			4'd4:
				if (be_lat[0]) begin
					b_req = 1;
					b_we = 1;
					b_addr = base_addr + 0;
					b_wdata = wdata_lat[7:0];
				end
			4'd5:
				if (be_lat[1]) begin
					b_req = 1;
					b_we = 1;
					b_addr = base_addr + 1;
					b_wdata = wdata_lat[15:8];
				end
			4'd6:
				if (be_lat[2]) begin
					b_req = 1;
					b_we = 1;
					b_addr = base_addr + 2;
					b_wdata = wdata_lat[23:16];
				end
			4'd7:
				if (be_lat[3]) begin
					b_req = 1;
					b_we = 1;
					b_addr = base_addr + 3;
					b_wdata = wdata_lat[31:24];
				end
			4'd9: begin
				b_req = 1;
				b_we = 1;
				b_addr = {26'b00000000000000000000000000, lbase} + 0;
				b_wdata = lword[7:0];
			end
			4'd10: begin
				b_req = 1;
				b_we = 1;
				b_addr = {26'b00000000000000000000000000, lbase} + 1;
				b_wdata = lword[15:8];
			end
			4'd11: begin
				b_req = 1;
				b_we = 1;
				b_addr = {26'b00000000000000000000000000, lbase} + 2;
				b_wdata = lword[23:16];
			end
			4'd12: begin
				b_req = 1;
				b_we = 1;
				b_addr = {26'b00000000000000000000000000, lbase} + 3;
				b_wdata = lword[31:24];
			end
			default:
				;
		endcase
	end
	assign gnt = ((state == 4'd0) && req) && !ld_word_en;
	assign rvalid = (state == 4'd3) || (state == 4'd8);
	assign rdata = {b3, b2, b1, b0};
	assign ld_busy = (((state == 4'd9) || (state == 4'd10)) || (state == 4'd11)) || (state == 4'd12);
	initial _sv2v_0 = 0;
endmodule
module dmem_narrow (
	clk,
	rst_n,
	b_req,
	b_sel,
	b_we,
	b_addr,
	b_wdata,
	b_rvalid,
	b_rdata
);
	reg _sv2v_0;
	parameter signed [31:0] ADDR_BITS = 6;
	input wire clk;
	input wire rst_n;
	input wire b_req;
	input wire b_sel;
	input wire b_we;
	input wire [31:0] b_addr;
	input wire [7:0] b_wdata;
	output wire b_rvalid;
	output wire [7:0] b_rdata;
	reg cen;
	reg gwen;
	reg [7:0] wen;
	reg [7:0] d;
	wire [7:0] q;
	reg [ADDR_BITS - 1:0] a;
	wire [ADDR_BITS - 1:0] acc_addr;
	assign acc_addr = b_addr[ADDR_BITS - 1:0];
	always @(*) begin
		if (_sv2v_0)
			;
		if (b_req && b_we) begin
			cen = 1'b0;
			gwen = 1'b0;
			wen = 8'h00;
			a = acc_addr;
			d = b_wdata;
		end
		else if (b_sel) begin
			cen = 1'b0;
			gwen = 1'b1;
			wen = 8'hff;
			a = acc_addr;
			d = 8'h00;
		end
		else begin
			cen = 1'b1;
			gwen = 1'b1;
			wen = 8'hff;
			a = 1'sb0;
			d = 8'h00;
		end
	end
	supply1 vdd;
	supply0 vss;
	gf180mcu_fd_ip_sram__sram64x8m8wm1 u_sram(
		.CLK(clk),
		.CEN(cen),
		.GWEN(gwen),
		.WEN(wen),
		.A(a),
		.D(d),
		.Q(q),
		.VDD(vdd),
		.VSS(vss)
	);
	reg rd_pending;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			rd_pending <= 1'b0;
		else
			rd_pending <= b_req & ~b_we;
	assign b_rvalid = rd_pending;
	assign b_rdata = q;
	initial _sv2v_0 = 0;
endmodule
module ahb_mem (
	HCLK,
	HRESETn,
	HSEL,
	HADDR,
	HTRANS,
	HWRITE,
	HWSTRB,
	HWDATA,
	HRDATA,
	HREADY,
	HRESP
);
	input wire HCLK;
	input wire HRESETn;
	input wire HSEL;
	input wire [31:0] HADDR;
	input wire [1:0] HTRANS;
	input wire HWRITE;
	input wire [3:0] HWSTRB;
	input wire [31:0] HWDATA;
	output wire [31:0] HRDATA;
	output wire HREADY;
	output wire HRESP;
	assign HRESP = 1'b0;
	wire sel_access;
	assign sel_access = HSEL & HTRANS[1];
	wire m_req;
	wire m_gnt;
	wire m_we;
	wire m_rvalid;
	wire [3:0] m_be;
	wire [31:0] m_addr;
	wire [31:0] m_wdata;
	wire [31:0] m_rdata;
	dmem_narrow_top u_dmem(
		.clk(HCLK),
		.rst_n(HRESETn),
		.req(m_req),
		.gnt(m_gnt),
		.we(m_we),
		.be(m_be),
		.addr(m_addr),
		.wdata(m_wdata),
		.rvalid(m_rvalid),
		.rdata(m_rdata),
		.ld_word_en(1'b0),
		.ld_word_addr(16'b0000000000000000),
		.ld_word_data(32'b00000000000000000000000000000000),
		.ld_busy()
	);
	reg [1:0] astate;
	reg acc_we;
	reg [3:0] acc_be;
	reg [31:0] acc_addr;
	reg [31:0] acc_wdata;
	reg kicked;
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn) begin
			astate <= 2'd0;
			acc_we <= 0;
			acc_be <= 0;
			acc_addr <= 0;
			acc_wdata <= 0;
			kicked <= 0;
		end
		else
			case (astate)
				2'd0: begin
					kicked <= 1'b0;
					if (sel_access) begin
						acc_we <= HWRITE;
						acc_be <= HWSTRB;
						acc_addr <= HADDR;
						astate <= 2'd1;
					end
				end
				2'd1: begin
					if (!kicked)
						acc_wdata <= HWDATA;
					if (!kicked && m_gnt)
						kicked <= 1'b1;
					if (m_rvalid)
						astate <= 2'd2;
				end
				2'd2: astate <= 2'd0;
				default: astate <= 2'd0;
			endcase
	assign m_req = (astate == 2'd1) && !kicked;
	assign m_we = acc_we;
	assign m_be = acc_be;
	assign m_addr = acc_addr;
	assign m_wdata = (kicked ? acc_wdata : HWDATA);
	assign HREADY = (astate == 2'd0) || (astate == 2'd2);
	assign HRDATA = m_rdata;
endmodule
module rst_sync (
	clk,
	rst_n_in,
	rst_n_out
);
	input wire clk;
	input wire rst_n_in;
	output wire rst_n_out;
	reg sync_ff1;
	reg sync_ff2;
	always @(posedge clk or negedge rst_n_in)
		if (!rst_n_in) begin
			sync_ff1 <= 1'b0;
			sync_ff2 <= 1'b0;
		end
		else begin
			sync_ff1 <= 1'b1;
			sync_ff2 <= sync_ff1;
		end
	assign rst_n_out = sync_ff2;
endmodule
module ibex_to_ahb (
	clk,
	rst_n,
	req,
	gnt,
	we,
	be,
	addr,
	wdata,
	rvalid,
	rdata,
	HADDR,
	HTRANS,
	HWRITE,
	HWSTRB,
	HWDATA,
	HRDATA,
	HREADY,
	HRESP
);
	input wire clk;
	input wire rst_n;
	input wire req;
	output wire gnt;
	input wire we;
	input wire [3:0] be;
	input wire [31:0] addr;
	input wire [31:0] wdata;
	output reg rvalid;
	output wire [31:0] rdata;
	output wire [31:0] HADDR;
	output wire [1:0] HTRANS;
	output wire HWRITE;
	output wire [3:0] HWSTRB;
	output wire [31:0] HWDATA;
	input wire [31:0] HRDATA;
	input wire HREADY;
	input wire HRESP;
	localparam [1:0] TRANS_IDLE = 2'b00;
	localparam [1:0] TRANS_NONSEQ = 2'b10;
	assign HADDR = addr;
	assign HTRANS = (req ? TRANS_NONSEQ : TRANS_IDLE);
	assign HWRITE = we;
	assign HWSTRB = be;
	assign gnt = req & HREADY;
	assign HWDATA = wdata;
	reg access_inflight;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			access_inflight <= 1'b0;
		else if (gnt)
			access_inflight <= 1'b1;
		else if (HREADY)
			access_inflight <= 1'b0;
	wire data_phase_done;
	assign data_phase_done = access_inflight & HREADY;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			rvalid <= 1'b0;
		else
			rvalid <= data_phase_done;
	assign rdata = HRDATA;
endmodule
module ahb_interconnect (
	HCLK,
	HRESETn,
	HADDR,
	HTRANS,
	HWRITE,
	HWDATA,
	HRDATA,
	HREADY,
	HRESP,
	HSEL,
	slv_HADDR,
	slv_HTRANS,
	slv_HWRITE,
	slv_HWDATA,
	s0_HRDATA,
	s0_HREADY,
	s0_HRESP,
	s1_HRDATA,
	s1_HREADY,
	s1_HRESP,
	s2_HRDATA,
	s2_HREADY,
	s2_HRESP,
	s3_HRDATA,
	s3_HREADY,
	s3_HRESP
);
	reg _sv2v_0;
	input wire HCLK;
	input wire HRESETn;
	input wire [31:0] HADDR;
	input wire [1:0] HTRANS;
	input wire HWRITE;
	input wire [31:0] HWDATA;
	output reg [31:0] HRDATA;
	output reg HREADY;
	output reg HRESP;
	output reg [3:0] HSEL;
	output wire [31:0] slv_HADDR;
	output wire [1:0] slv_HTRANS;
	output wire slv_HWRITE;
	output wire [31:0] slv_HWDATA;
	input wire [31:0] s0_HRDATA;
	input wire s0_HREADY;
	input wire s0_HRESP;
	input wire [31:0] s1_HRDATA;
	input wire s1_HREADY;
	input wire s1_HRESP;
	input wire [31:0] s2_HRDATA;
	input wire s2_HREADY;
	input wire s2_HRESP;
	input wire [31:0] s3_HRDATA;
	input wire s3_HREADY;
	input wire s3_HRESP;
	assign slv_HADDR = HADDR;
	assign slv_HTRANS = HTRANS;
	assign slv_HWRITE = HWRITE;
	assign slv_HWDATA = HWDATA;
	wire active;
	wire [1:0] region;
	assign active = HTRANS[1];
	assign region = HADDR[17:16];
	always @(*) begin
		if (_sv2v_0)
			;
		HSEL = 4'b0000;
		if (active)
			HSEL[region] = 1'b1;
	end
	reg [1:0] region_q;
	reg active_q;
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn) begin
			region_q <= 2'b00;
			active_q <= 1'b0;
		end
		else begin
			region_q <= region;
			active_q <= active;
		end
	always @(*) begin
		if (_sv2v_0)
			;
		case (region_q)
			2'b00: begin
				HRDATA = s0_HRDATA;
				HREADY = s0_HREADY;
				HRESP = s0_HRESP;
			end
			2'b01: begin
				HRDATA = s1_HRDATA;
				HREADY = s1_HREADY;
				HRESP = s1_HRESP;
			end
			2'b10: begin
				HRDATA = s2_HRDATA;
				HREADY = s2_HREADY;
				HRESP = s2_HRESP;
			end
			2'b11: begin
				HRDATA = s3_HRDATA;
				HREADY = s3_HREADY;
				HRESP = s3_HRESP;
			end
			default: begin
				HRDATA = 32'h00000000;
				HREADY = 1'b1;
				HRESP = 1'b0;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module ahb_to_apb (
	HCLK,
	HRESETn,
	HSEL,
	HADDR,
	HTRANS,
	HWRITE,
	HWDATA,
	HRDATA,
	HREADY,
	HRESP,
	PSEL,
	PENABLE,
	PWRITE,
	PADDR,
	PWDATA,
	PRDATA,
	PREADY
);
	reg _sv2v_0;
	input wire HCLK;
	input wire HRESETn;
	input wire HSEL;
	input wire [31:0] HADDR;
	input wire [1:0] HTRANS;
	input wire HWRITE;
	input wire [31:0] HWDATA;
	output wire [31:0] HRDATA;
	output reg HREADY;
	output wire HRESP;
	output reg PSEL;
	output reg PENABLE;
	output wire PWRITE;
	output wire [31:0] PADDR;
	output wire [31:0] PWDATA;
	input wire [31:0] PRDATA;
	input wire PREADY;
	assign HRESP = 1'b0;
	reg [1:0] state;
	reg [1:0] next_state;
	wire ahb_access;
	assign ahb_access = HSEL & HTRANS[1];
	reg [31:0] addr_q;
	reg write_q;
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn) begin
			addr_q <= 32'h00000000;
			write_q <= 1'b0;
		end
		else if (ahb_access && (state == 2'd0)) begin
			addr_q <= HADDR;
			write_q <= HWRITE;
		end
	reg [31:0] wdata_q;
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn)
			wdata_q <= 32'h00000000;
		else if (state == 2'd1)
			wdata_q <= HWDATA;
	always @(*) begin
		if (_sv2v_0)
			;
		next_state = state;
		case (state)
			2'd0:
				if (ahb_access)
					next_state = 2'd1;
			2'd1: next_state = 2'd2;
			2'd2:
				if (PREADY)
					next_state = 2'd0;
		endcase
	end
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn)
			state <= 2'd0;
		else
			state <= next_state;
	always @(*) begin
		if (_sv2v_0)
			;
		PSEL = (state == 2'd1) || (state == 2'd2);
		PENABLE = state == 2'd2;
	end
	assign PWRITE = write_q;
	assign PADDR = addr_q;
	assign PWDATA = wdata_q;
	assign HRDATA = PRDATA;
	always @(*) begin
		if (_sv2v_0)
			;
		if ((state == 2'd0) && !ahb_access)
			HREADY = 1'b1;
		else if ((state == 2'd2) && PREADY)
			HREADY = 1'b1;
		else
			HREADY = 1'b0;
	end
	initial _sv2v_0 = 0;
endmodule
module apb_decoder (
	PSEL,
	PENABLE,
	PWRITE,
	PADDR,
	PWDATA,
	PRDATA,
	PREADY,
	gpio_PSEL,
	gpio_PRDATA,
	gpio_PREADY,
	uart_PSEL,
	uart_PRDATA,
	uart_PREADY,
	spi_PSEL,
	spi_PRDATA,
	spi_PREADY,
	p_PENABLE,
	p_PWRITE,
	p_PADDR,
	p_PWDATA
);
	reg _sv2v_0;
	input wire PSEL;
	input wire PENABLE;
	input wire PWRITE;
	input wire [31:0] PADDR;
	input wire [31:0] PWDATA;
	output reg [31:0] PRDATA;
	output reg PREADY;
	output reg gpio_PSEL;
	input wire [31:0] gpio_PRDATA;
	input wire gpio_PREADY;
	output reg uart_PSEL;
	input wire [31:0] uart_PRDATA;
	input wire uart_PREADY;
	output reg spi_PSEL;
	input wire [31:0] spi_PRDATA;
	input wire spi_PREADY;
	output wire p_PENABLE;
	output wire p_PWRITE;
	output wire [31:0] p_PADDR;
	output wire [31:0] p_PWDATA;
	assign p_PENABLE = PENABLE;
	assign p_PWRITE = PWRITE;
	assign p_PADDR = PADDR;
	assign p_PWDATA = PWDATA;
	wire [1:0] region;
	assign region = PADDR[17:16];
	always @(*) begin
		if (_sv2v_0)
			;
		gpio_PSEL = 1'b0;
		uart_PSEL = 1'b0;
		spi_PSEL = 1'b0;
		if (PSEL)
			case (region)
				2'b01: gpio_PSEL = 1'b1;
				2'b10: uart_PSEL = 1'b1;
				2'b11: spi_PSEL = 1'b1;
				default:
					;
			endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		case (region)
			2'b01: begin
				PRDATA = gpio_PRDATA;
				PREADY = gpio_PREADY;
			end
			2'b10: begin
				PRDATA = uart_PRDATA;
				PREADY = uart_PREADY;
			end
			2'b11: begin
				PRDATA = spi_PRDATA;
				PREADY = spi_PREADY;
			end
			default: begin
				PRDATA = 32'h00000000;
				PREADY = 1'b1;
			end
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
module apb_gpio (
	PCLK,
	PRESETn,
	PSEL,
	PENABLE,
	PWRITE,
	PADDR,
	PWDATA,
	PRDATA,
	PREADY,
	gpio_out,
	gpio_in
);
	parameter signed [31:0] NUM_OUT = 5;
	parameter signed [31:0] NUM_IN = 2;
	input wire PCLK;
	input wire PRESETn;
	input wire PSEL;
	input wire PENABLE;
	input wire PWRITE;
	input wire [31:0] PADDR;
	input wire [31:0] PWDATA;
	output wire [31:0] PRDATA;
	output wire PREADY;
	output wire [NUM_OUT - 1:0] gpio_out;
	input wire [NUM_IN - 1:0] gpio_in;
	assign PREADY = 1'b1;
	wire access_phase;
	assign access_phase = PSEL & PENABLE;
	wire gpio_sel;
	wire gpio_we;
	wire [31:0] gpio_rdata;
	assign gpio_sel = access_phase;
	assign gpio_we = access_phase & PWRITE;
	gpio #(
		.NUM_OUT(NUM_OUT),
		.NUM_IN(NUM_IN)
	) u_gpio(
		.clk(PCLK),
		.rst_n(PRESETn),
		.sel(gpio_sel),
		.we(gpio_we),
		.wdata(PWDATA),
		.rdata(gpio_rdata),
		.gpio_out(gpio_out),
		.gpio_in(gpio_in)
	);
	assign PRDATA = gpio_rdata;
endmodule
module apb_uart (
	PCLK,
	PRESETn,
	PSEL,
	PENABLE,
	PWRITE,
	PADDR,
	PWDATA,
	PRDATA,
	PREADY,
	tx,
	rx
);
	parameter signed [31:0] CLK_FREQ = 10000000;
	parameter signed [31:0] BAUD_RATE = 115200;
	input wire PCLK;
	input wire PRESETn;
	input wire PSEL;
	input wire PENABLE;
	input wire PWRITE;
	input wire [31:0] PADDR;
	input wire [31:0] PWDATA;
	output wire [31:0] PRDATA;
	output wire PREADY;
	output wire tx;
	input wire rx;
	assign PREADY = 1'b1;
	wire access_phase;
	assign access_phase = PSEL & PENABLE;
	wire uart_sel;
	wire uart_we;
	wire [31:0] uart_rdata;
	assign uart_sel = access_phase;
	assign uart_we = access_phase & PWRITE;
	uart #(
		.CLK_FREQ(CLK_FREQ),
		.BAUD_RATE(BAUD_RATE)
	) u_uart(
		.clk(PCLK),
		.rst_n(PRESETn),
		.sel(uart_sel),
		.we(uart_we),
		.addr(PADDR),
		.wdata(PWDATA),
		.rdata(uart_rdata),
		.tx(tx),
		.rx(rx)
	);
	assign PRDATA = uart_rdata;
endmodule
module apb_spi (
	PCLK,
	PRESETn,
	PSEL,
	PENABLE,
	PWRITE,
	PADDR,
	PWDATA,
	PRDATA,
	PREADY,
	sclk,
	mosi,
	miso,
	cs_n
);
	parameter signed [31:0] CLK_DIV = 4;
	input wire PCLK;
	input wire PRESETn;
	input wire PSEL;
	input wire PENABLE;
	input wire PWRITE;
	input wire [31:0] PADDR;
	input wire [31:0] PWDATA;
	output wire [31:0] PRDATA;
	output wire PREADY;
	output wire sclk;
	output wire mosi;
	input wire miso;
	output wire cs_n;
	assign PREADY = 1'b1;
	wire access_phase;
	assign access_phase = PSEL & PENABLE;
	wire spi_sel;
	wire spi_we;
	wire [31:0] spi_rdata;
	assign spi_sel = access_phase;
	assign spi_we = access_phase & PWRITE;
	spi #(.CLK_DIV(CLK_DIV)) u_spi(
		.clk(PCLK),
		.rst_n(PRESETn),
		.sel(spi_sel),
		.we(spi_we),
		.wdata(PWDATA),
		.rdata(spi_rdata),
		.sclk(sclk),
		.mosi(mosi),
		.miso(miso),
		.cs_n(cs_n)
	);
	assign PRDATA = spi_rdata;
endmodule
module ahb_gpio (
	HCLK,
	HRESETn,
	HSEL,
	HADDR,
	HTRANS,
	HWRITE,
	HWDATA,
	HRDATA,
	HREADY,
	HRESP,
	gpio_out,
	gpio_in
);
	parameter signed [31:0] NUM_OUT = 5;
	parameter signed [31:0] NUM_IN = 2;
	input wire HCLK;
	input wire HRESETn;
	input wire HSEL;
	input wire [31:0] HADDR;
	input wire [1:0] HTRANS;
	input wire HWRITE;
	input wire [31:0] HWDATA;
	output wire [31:0] HRDATA;
	output wire HREADY;
	output wire HRESP;
	output wire [NUM_OUT - 1:0] gpio_out;
	input wire [NUM_IN - 1:0] gpio_in;
	assign HREADY = 1'b1;
	assign HRESP = 1'b0;
	reg write_phase;
	reg read_phase;
	always @(posedge HCLK or negedge HRESETn)
		if (!HRESETn) begin
			write_phase <= 1'b0;
			read_phase <= 1'b0;
		end
		else begin
			write_phase <= (HSEL & HTRANS[1]) & HWRITE;
			read_phase <= (HSEL & HTRANS[1]) & ~HWRITE;
		end
	wire gpio_sel;
	wire gpio_we;
	wire [31:0] gpio_rdata;
	assign gpio_we = write_phase;
	assign gpio_sel = write_phase | read_phase;
	gpio #(
		.NUM_OUT(NUM_OUT),
		.NUM_IN(NUM_IN)
	) u_gpio(
		.clk(HCLK),
		.rst_n(HRESETn),
		.sel(gpio_sel),
		.we(gpio_we),
		.wdata(HWDATA),
		.rdata(gpio_rdata),
		.gpio_out(gpio_out),
		.gpio_in(gpio_in)
	);
	assign HRDATA = gpio_rdata;
endmodule
module gpio (
	clk,
	rst_n,
	sel,
	we,
	wdata,
	rdata,
	gpio_out,
	gpio_in
);
	parameter signed [31:0] NUM_OUT = 5;
	parameter signed [31:0] NUM_IN = 2;
	input wire clk;
	input wire rst_n;
	input wire sel;
	input wire we;
	input wire [31:0] wdata;
	output wire [31:0] rdata;
	output wire [NUM_OUT - 1:0] gpio_out;
	input wire [NUM_IN - 1:0] gpio_in;
	reg [NUM_OUT - 1:0] out_reg;
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			out_reg <= 1'sb0;
		else if (sel && we)
			out_reg <= wdata[NUM_OUT - 1:0];
	assign gpio_out = out_reg;
	reg [NUM_IN - 1:0] sync1;
	reg [NUM_IN - 1:0] sync2;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			sync1 <= 1'sb0;
			sync2 <= 1'sb0;
		end
		else begin
			sync1 <= gpio_in;
			sync2 <= sync1;
		end
	assign rdata = {{32 - NUM_IN {1'b0}}, sync2};
endmodule
module uart (
	clk,
	rst_n,
	sel,
	we,
	addr,
	wdata,
	rdata,
	tx,
	rx
);
	reg _sv2v_0;
	parameter signed [31:0] CLK_FREQ = 10000000;
	parameter signed [31:0] BAUD_RATE = 115200;
	input wire clk;
	input wire rst_n;
	input wire sel;
	input wire we;
	input wire [31:0] addr;
	input wire [31:0] wdata;
	output reg [31:0] rdata;
	output reg tx;
	input wire rx;
	localparam signed [31:0] BAUD_DIV = CLK_FREQ / BAUD_RATE;
	reg [$clog2(BAUD_DIV) - 1:0] baud_cnt;
	reg baud_tick;
	reg tx_busy;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			baud_cnt <= 1'sb0;
			baud_tick <= 1'b0;
		end
		else if (tx_busy) begin
			if (baud_cnt == (BAUD_DIV - 1)) begin
				baud_cnt <= 1'sb0;
				baud_tick <= 1'b1;
			end
			else begin
				baud_cnt <= baud_cnt + 1'b1;
				baud_tick <= 1'b0;
			end
		end
		else begin
			baud_cnt <= 1'sb0;
			baud_tick <= 1'b0;
		end
	reg [1:0] tstate;
	reg [7:0] tx_shift;
	reg [2:0] tx_index;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			tstate <= 2'd0;
			tx <= 1'b1;
			tx_busy <= 1'b0;
			tx_shift <= 8'h00;
			tx_index <= 3'h0;
		end
		else
			case (tstate)
				2'd0: begin
					tx <= 1'b1;
					if (sel && we) begin
						tx_shift <= wdata[7:0];
						tx_busy <= 1'b1;
						tx_index <= 3'h0;
						tstate <= 2'd1;
					end
				end
				2'd1: begin
					tx <= 1'b0;
					if (baud_tick)
						tstate <= 2'd2;
				end
				2'd2: begin
					tx <= tx_shift[0];
					if (baud_tick) begin
						tx_shift <= {1'b0, tx_shift[7:1]};
						if (tx_index == 3'd7)
							tstate <= 2'd3;
						else
							tx_index <= tx_index + 1'b1;
					end
				end
				2'd3: begin
					tx <= 1'b1;
					if (baud_tick) begin
						tx_busy <= 1'b0;
						tstate <= 2'd0;
					end
				end
			endcase
	reg rx_sync1;
	reg rx_sync2;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rx_sync1 <= 1'b1;
			rx_sync2 <= 1'b1;
		end
		else begin
			rx_sync1 <= rx;
			rx_sync2 <= rx_sync1;
		end
	wire rx_in;
	assign rx_in = rx_sync2;
	reg [$clog2(BAUD_DIV) - 1:0] rx_cnt;
	reg rx_active;
	reg [1:0] rstate;
	reg [7:0] rx_shift;
	reg [2:0] rx_index;
	reg [7:0] rx_data;
	reg rx_valid;
	wire data_read;
	assign data_read = (sel && !we) && addr[2];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rstate <= 2'd0;
			rx_cnt <= 1'sb0;
			rx_index <= 3'h0;
			rx_shift <= 8'h00;
			rx_data <= 8'h00;
			rx_valid <= 1'b0;
			rx_active <= 1'b0;
		end
		else begin
			if (data_read)
				rx_valid <= 1'b0;
			case (rstate)
				2'd0: begin
					rx_cnt <= 1'sb0;
					if (rx_in == 1'b0) begin
						rstate <= 2'd1;
						rx_active <= 1'b1;
					end
				end
				2'd1:
					if (rx_cnt == ((BAUD_DIV / 2) - 1)) begin
						rx_cnt <= 1'sb0;
						if (rx_in == 1'b0) begin
							rstate <= 2'd2;
							rx_index <= 3'h0;
						end
						else begin
							rstate <= 2'd0;
							rx_active <= 1'b0;
						end
					end
					else
						rx_cnt <= rx_cnt + 1'b1;
				2'd2:
					if (rx_cnt == (BAUD_DIV - 1)) begin
						rx_cnt <= 1'sb0;
						rx_shift <= {rx_in, rx_shift[7:1]};
						if (rx_index == 3'd7)
							rstate <= 2'd3;
						else
							rx_index <= rx_index + 1'b1;
					end
					else
						rx_cnt <= rx_cnt + 1'b1;
				2'd3:
					if (rx_cnt == (BAUD_DIV - 1)) begin
						rx_cnt <= 1'sb0;
						rx_data <= rx_shift;
						rx_valid <= 1'b1;
						rx_active <= 1'b0;
						rstate <= 2'd0;
					end
					else
						rx_cnt <= rx_cnt + 1'b1;
			endcase
		end
	always @(*) begin
		if (_sv2v_0)
			;
		if (addr[2])
			rdata = {24'b000000000000000000000000, rx_data};
		else
			rdata = {30'b000000000000000000000000000000, rx_valid, tx_busy};
	end
	initial _sv2v_0 = 0;
endmodule
module spi (
	clk,
	rst_n,
	sel,
	we,
	wdata,
	rdata,
	sclk,
	mosi,
	miso,
	cs_n
);
	parameter signed [31:0] CLK_DIV = 4;
	input wire clk;
	input wire rst_n;
	input wire sel;
	input wire we;
	input wire [31:0] wdata;
	output wire [31:0] rdata;
	output wire sclk;
	output wire mosi;
	input wire miso;
	output reg cs_n;
	reg [$clog2(CLK_DIV) - 1:0] div_cnt;
	reg tick;
	reg busy;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			div_cnt <= 1'sb0;
			tick <= 1'b0;
		end
		else if (busy) begin
			if (div_cnt == (CLK_DIV - 1)) begin
				div_cnt <= 1'sb0;
				tick <= 1'b1;
			end
			else begin
				div_cnt <= div_cnt + 1'b1;
				tick <= 1'b0;
			end
		end
		else begin
			div_cnt <= 1'sb0;
			tick <= 1'b0;
		end
	reg state;
	reg [7:0] tx_shift;
	reg [7:0] rx_shift;
	reg [3:0] bit_count;
	reg sclk_int;
	reg [7:0] rx_data;
	assign sclk = sclk_int;
	assign mosi = tx_shift[7];
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			state <= 1'd0;
			busy <= 1'b0;
			cs_n <= 1'b1;
			sclk_int <= 1'b0;
			tx_shift <= 8'h00;
			rx_shift <= 8'h00;
			rx_data <= 8'h00;
			bit_count <= 4'h0;
		end
		else
			case (state)
				1'd0: begin
					sclk_int <= 1'b0;
					cs_n <= 1'b1;
					if (sel && we) begin
						tx_shift <= wdata[7:0];
						busy <= 1'b1;
						cs_n <= 1'b0;
						bit_count <= 4'h0;
						state <= 1'd1;
					end
				end
				1'd1:
					if (tick) begin
						sclk_int <= ~sclk_int;
						if (~sclk_int)
							rx_shift <= {rx_shift[6:0], miso};
						else begin
							tx_shift <= {tx_shift[6:0], 1'b0};
							bit_count <= bit_count + 1'b1;
						end
						if (bit_count == 4'd8) begin
							state <= 1'd0;
							busy <= 1'b0;
							cs_n <= 1'b1;
							sclk_int <= 1'b0;
							rx_data <= rx_shift;
						end
					end
			endcase
	assign rdata = {16'b0000000000000000, rx_data, 7'b0000000, busy};
endmodule
module scan_chain (
	clk,
	rst_n,
	scan_in,
	scan_shift,
	scan_load,
	scan_i0o1,
	scan_out,
	mem_we,
	mem_addr,
	mem_wdata,
	mem_rdata,
	fsm_cfg_load,
	fsm_mode,
	fsm_count,
	clk_cfg_load,
	clk_int,
	clk_div
);
	input wire clk;
	input wire rst_n;
	input wire scan_in;
	input wire scan_shift;
	input wire scan_load;
	input wire scan_i0o1;
	output wire scan_out;
	output wire mem_we;
	output wire [15:0] mem_addr;
	output wire [31:0] mem_wdata;
	input wire [31:0] mem_rdata;
	output wire fsm_cfg_load;
	output wire [1:0] fsm_mode;
	output wire [15:0] fsm_count;
	output wire clk_cfg_load;
	output wire clk_int;
	output wire [7:0] clk_div;
	localparam signed [31:0] FRAME_BITS = 48;
	reg [47:0] shift_reg;
	assign scan_out = shift_reg[0];
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			shift_reg <= 1'sb0;
		else if (scan_i0o1)
			shift_reg[31:0] <= mem_rdata;
		else if (scan_shift)
			shift_reg <= {scan_in, shift_reg[47:1]};
	wire [1:0] tgt;
	assign tgt = shift_reg[47:46];
	assign mem_addr = {2'b00, shift_reg[45:32]};
	assign mem_wdata = shift_reg[31:0];
	assign mem_we = scan_load & (tgt == 2'd0);
	assign fsm_cfg_load = scan_load & (tgt == 2'd1);
	assign clk_cfg_load = scan_load & (tgt == 2'd2);
	assign fsm_mode = shift_reg[17:16];
	assign fsm_count = shift_reg[15:0];
	assign clk_int = shift_reg[8];
	assign clk_div = shift_reg[7:0];
endmodule
module test_fsm (
	clk,
	rst_n,
	cfg_load,
	cfg_mode_in,
	cfg_count_in,
	cpu_clk,
	scan_owns_mem,
	mode_o
);
	reg _sv2v_0;
	input wire clk;
	input wire rst_n;
	input wire cfg_load;
	input wire [1:0] cfg_mode_in;
	input wire [15:0] cfg_count_in;
	output wire cpu_clk;
	output wire scan_owns_mem;
	output wire [1:0] mode_o;
	localparam [1:0] IDLE = 2'd0;
	localparam [1:0] RUN = 2'd1;
	localparam [1:0] COUNTDOWN = 2'd2;
	reg [1:0] mode;
	reg [15:0] count;
	reg run_gate;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			mode <= IDLE;
			count <= 16'd0;
		end
		else if (cfg_load) begin
			mode <= cfg_mode_in;
			count <= cfg_count_in;
		end
		else if ((mode == COUNTDOWN) && (count != 16'd0))
			count <= count - 16'd1;
	always @(*) begin
		if (_sv2v_0)
			;
		case (mode)
			RUN: run_gate = 1'b1;
			COUNTDOWN: run_gate = count != 16'd0;
			default: run_gate = 1'b0;
		endcase
	end
	assign cpu_clk = clk & run_gate;
	assign scan_owns_mem = mode == IDLE;
	assign mode_o = mode;
	initial _sv2v_0 = 0;
endmodule
module clk_gen (
	ref_clk,
	clk_ext,
	rst_n,
	clk_int,
	cfg_load,
	cfg_div_in,
	clk_out
);
	input wire ref_clk;
	input wire clk_ext;
	input wire rst_n;
	input wire clk_int;
	input wire cfg_load;
	input wire [7:0] cfg_div_in;
	output wire clk_out;
	reg [7:0] div;
	reg [7:0] cnt;
	reg div_clk;
	always @(posedge ref_clk or negedge rst_n)
		if (!rst_n) begin
			div <= 8'd0;
			cnt <= 8'd0;
			div_clk <= 1'b0;
		end
		else if (cfg_load) begin
			div <= cfg_div_in;
			cnt <= 8'd0;
		end
		else if (cnt == div) begin
			cnt <= 8'd0;
			div_clk <= ~div_clk;
		end
		else
			cnt <= cnt + 8'd1;
	assign clk_out = (clk_int ? div_clk : clk_ext);
endmodule
