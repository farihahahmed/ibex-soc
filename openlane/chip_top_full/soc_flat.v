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
		.mem_rdata(32'b00000000000000000000000000000000),
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
	ibex_top u_ibex(
		.clk_i(cpu_clk),
		.rst_ni(rst_n),
		.test_en_i(1'b0),
		.scan_rst_ni(1'b1),
		.ram_cfg_icache_tag_i(24'b000000000000000000000000),
		.ram_cfg_icache_tag_o(),
		.ram_cfg_icache_data_i(24'b000000000000000000000000),
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
		.scramble_key_i(1'sb0),
		.scramble_nonce_i(1'sb0),
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
	parameter signed [31:0] ADDR_BITS = 9;
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
	gf180mcu_fd_ip_sram__sram512x8m8wm1 u_sram(
		.CLK(clk),
		.CEN(cen),
		.GWEN(gwen),
		.WEN(wen),
		.A(a),
		.D(d),
		.Q(q)
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
	dmem_narrow #(.ADDR_BITS(9)) u_mem(
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
	reg [8:0] lbase;
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
						lbase <= {ld_word_addr[6:0], 2'b00};
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
				b_addr = {23'b00000000000000000000000, lbase} + 0;
				b_wdata = lword[7:0];
			end
			4'd10: begin
				b_req = 1;
				b_we = 1;
				b_addr = {23'b00000000000000000000000, lbase} + 1;
				b_wdata = lword[15:8];
			end
			4'd11: begin
				b_req = 1;
				b_we = 1;
				b_addr = {23'b00000000000000000000000, lbase} + 2;
				b_wdata = lword[23:16];
			end
			4'd12: begin
				b_req = 1;
				b_we = 1;
				b_addr = {23'b00000000000000000000000, lbase} + 3;
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
	gf180mcu_fd_ip_sram__sram512x8m8wm1 u_sram(
		.CLK(clk),
		.CEN(cen),
		.GWEN(gwen),
		.WEN(wen),
		.A(a),
		.D(d),
		.Q(q)
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
module mem_subsystem (
	clk,
	rst_n_in,
	instr_req_i,
	instr_gnt_o,
	instr_addr_i,
	instr_rvalid_o,
	instr_rdata_o,
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
	reg run_gate_q;
	always @(negedge clk or negedge rst_n)
		if (!rst_n)
			run_gate_q <= 1'b0;
		else
			run_gate_q <= run_gate;
	assign cpu_clk = clk & run_gate_q;
	assign scan_owns_mem = mode == IDLE;
	assign mode_o = mode;
	initial _sv2v_0 = 0;
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
