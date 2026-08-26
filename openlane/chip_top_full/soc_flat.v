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
	parameter signed [31:0] CLK_FREQ = 31250000;
	parameter signed [31:0] BAUD_RATE = 115200;
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
	wire [31:0] status_word;
	wire scan_mem_we;
	wire scan_mem_re;
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
		.mem_re(scan_mem_re),
		.mem_addr(scan_mem_addr),
		.mem_wdata(scan_mem_wdata),
		.mem_rdata(scan_mem_rdata),
		.status_in(status_word),
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
	wire pico_resetn;
	reg [1:0] pico_rst_sync;
	always @(posedge cpu_clk or negedge rst_n)
		if (!rst_n)
			pico_rst_sync <= 2'b00;
		else
			pico_rst_sync <= {pico_rst_sync[0], 1'b1};
	assign pico_resetn = pico_rst_sync[1];
	wire p_mem_valid;
	wire p_mem_instr;
	wire p_mem_ready;
	wire [31:0] p_mem_addr;
	wire [31:0] p_mem_wdata;
	wire [31:0] p_mem_rdata;
	wire [3:0] p_mem_wstrb;
	wire p_trap;
	reg trap_sync1;
	reg trap_sync2;
	reg trap_sticky;
	always @(posedge sys_clk or negedge rst_n)
		if (!rst_n) begin
			trap_sync1 <= 1'b0;
			trap_sync2 <= 1'b0;
			trap_sticky <= 1'b0;
		end
		else begin
			trap_sync1 <= p_trap;
			trap_sync2 <= trap_sync1;
			if (trap_sync2)
				trap_sticky <= 1'b1;
		end
	assign status_word = {28'b0000000000000000000000000000, scan_owns_mem, fsm_mode_o, trap_sticky};
	wire pcpi_valid;
	wire pcpi_wr;
	wire pcpi_wait;
	wire pcpi_ready;
	wire [31:0] pcpi_insn;
	wire [31:0] pcpi_rs1;
	wire [31:0] pcpi_rs2;
	wire [31:0] pcpi_rd;
	pcpi_crc32 u_pcpi_crc32(
		.clk(cpu_clk),
		.resetn(pico_resetn),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready)
	);
	picorv32 #(
		.ENABLE_MUL(1),
		.ENABLE_DIV(1),
		.COMPRESSED_ISA(1),
		.ENABLE_IRQ(0),
		.PROGADDR_RESET(32'h00000000),
		.STACKADDR(32'h00000200),
		.ENABLE_PCPI(1),
		.BARREL_SHIFTER(0),
		.ENABLE_FAST_MUL(0),
		.ENABLE_COUNTERS(0),
		.ENABLE_COUNTERS64(0)
	) u_cpu(
		.clk(cpu_clk),
		.resetn(pico_resetn),
		.trap(p_trap),
		.mem_valid(p_mem_valid),
		.mem_instr(p_mem_instr),
		.mem_ready(p_mem_ready),
		.mem_addr(p_mem_addr),
		.mem_wdata(p_mem_wdata),
		.mem_wstrb(p_mem_wstrb),
		.mem_rdata(p_mem_rdata),
		.mem_la_read(),
		.mem_la_write(),
		.mem_la_addr(),
		.mem_la_wdata(),
		.mem_la_wstrb(),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready),
		.irq(32'b00000000000000000000000000000000),
		.eoi(),
		.trace_valid(),
		.trace_data()
	);
	pico_shim u_shim(
		.clk(cpu_clk),
		.rst_n(rst_n),
		.mem_valid(p_mem_valid),
		.mem_instr(p_mem_instr),
		.mem_ready(p_mem_ready),
		.mem_addr(p_mem_addr),
		.mem_wdata(p_mem_wdata),
		.mem_wstrb(p_mem_wstrb),
		.mem_rdata(p_mem_rdata),
		.instr_req(instr_req),
		.instr_gnt(instr_gnt),
		.instr_addr(instr_addr),
		.instr_rvalid(instr_rvalid),
		.instr_rdata(instr_rdata),
		.data_req(data_req),
		.data_gnt(data_gnt),
		.data_we(data_we),
		.data_be(data_be),
		.data_addr(data_addr),
		.data_wdata(data_wdata),
		.data_rvalid(data_rvalid),
		.data_rdata(data_rdata)
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
		.scan_re(scan_mem_re),
		.scan_rdata(scan_mem_rdata)
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
	wire spi_miso_tied;
	assign spi_miso_tied = 1'b0;
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
		.miso(spi_miso_tied),
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
	reg int_req;
	reg ext_req;
	always @(posedge ref_clk or negedge rst_n)
		if (!rst_n) begin
			int_req <= 1'b0;
			ext_req <= 1'b0;
		end
		else begin
			int_req <= clk_int & ~ext_req;
			ext_req <= ~clk_int & ~int_req;
		end
	wire int_gated;
	wire ext_gated;
	gf180mcu_fd_sc_mcu7t5v0__icgtp_1 u_icg_int(
		.CLK(div_clk),
		.E(int_req),
		.TE(1'b0),
		.Q(int_gated)
	);
	gf180mcu_fd_sc_mcu7t5v0__icgtp_1 u_icg_ext(
		.CLK(clk_ext),
		.E(ext_req),
		.TE(1'b0),
		.Q(ext_gated)
	);
	assign clk_out = int_gated | ext_gated;
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
	assign addr_aligned = {23'b00000000000000000000000, addr[8:2], 2'b00};
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
	assign rdata = {{(32 - NUM_IN) - NUM_OUT {1'b0}}, out_reg, sync2};
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
	assign HWRITE = we;
	assign HWSTRB = be;
	assign HWDATA = wdata;
	reg inflight;
	assign gnt = (req & ~inflight) & HREADY;
	assign HTRANS = (req & ~inflight ? TRANS_NONSEQ : TRANS_IDLE);
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			inflight <= 1'b0;
		else if (gnt)
			inflight <= 1'b1;
		else if (inflight && HREADY)
			inflight <= 1'b0;
	wire data_phase_done;
	assign data_phase_done = inflight & HREADY;
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
	ld_busy,
	scan_owns,
	rd_word_en,
	rd_word_addr,
	rd_word_data,
	rd_busy
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
	input wire scan_owns;
	input wire rd_word_en;
	input wire [15:0] rd_word_addr;
	output wire [31:0] rd_word_data;
	output wire rd_busy;
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
	wire g_c_req;
	wire g_c_gnt;
	wire g_c_rvalid;
	wire [31:0] g_c_addr;
	wire [31:0] g_c_rdata;
	reg [1:0] rbstate;
	reg [8:0] rb_addr;
	reg [31:0] rb_data_q;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			rbstate <= 2'd0;
			rb_addr <= 9'b000000000;
			rb_data_q <= 32'b00000000000000000000000000000000;
		end
		else
			case (rbstate)
				2'd0:
					if ((rd_word_en && !ld_busy) && scan_owns) begin
						rb_addr <= {rd_word_addr[6:0], 2'b00};
						rbstate <= 2'd1;
					end
				2'd1:
					if (g_c_gnt)
						rbstate <= 2'd2;
				2'd2:
					if (g_c_rvalid) begin
						rb_data_q <= g_c_rdata;
						rbstate <= 2'd0;
					end
				default: rbstate <= 2'd0;
			endcase
	assign rd_busy = rbstate != 2'd0;
	assign rd_word_data = rb_data_q;
	assign g_c_req = (scan_owns ? rbstate == 2'd1 : req);
	assign g_c_addr = (scan_owns ? {23'b00000000000000000000000, rb_addr} : addr);
	assign gnt = (scan_owns ? 1'b0 : g_c_gnt);
	assign rvalid = (scan_owns ? 1'b0 : g_c_rvalid);
	assign rdata = g_c_rdata;
	fetch_gather u_gather(
		.clk(clk),
		.rst_n(rst_n),
		.c_req(g_c_req),
		.c_gnt(g_c_gnt),
		.c_addr(g_c_addr),
		.c_rvalid(g_c_rvalid),
		.c_rdata(g_c_rdata),
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
	scan_re,
	scan_rdata
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
	input wire scan_re;
	output wire [31:0] scan_rdata;
	wire rst_n;
	rst_sync u_rst_sync(
		.clk(clk),
		.rst_n_in(rst_n_in),
		.rst_n_out(rst_n)
	);
	wire imem_ld_en;
	assign imem_ld_en = scan_owns_mem & scan_we;
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
		.ld_busy(),
		.scan_owns(scan_owns_mem),
		.rd_word_en(scan_re),
		.rd_word_addr(scan_addr),
		.rd_word_data(scan_rdata),
		.rd_busy()
	);
endmodule
module pcpi_crc32 (
	clk,
	resetn,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready
);
	input wire clk;
	input wire resetn;
	input wire pcpi_valid;
	input wire [31:0] pcpi_insn;
	input wire [31:0] pcpi_rs1;
	input wire [31:0] pcpi_rs2;
	output reg pcpi_wr;
	output reg [31:0] pcpi_rd;
	output wire pcpi_wait;
	output reg pcpi_ready;
	localparam [31:0] POLY = 32'hedb88320;
	wire is_crc32;
	assign is_crc32 = ((pcpi_valid && (pcpi_insn[6:0] == 7'b0001011)) && (pcpi_insn[14:12] == 3'b000)) && (pcpi_insn[31:25] == 7'b0000000);
	wire [31:0] c0;
	wire [31:0] c1;
	wire [31:0] c2;
	wire [31:0] c3;
	wire [31:0] c4;
	wire [31:0] c5;
	wire [31:0] c6;
	wire [31:0] c7;
	wire [31:0] c8;
	assign c0 = pcpi_rs1 ^ {24'b000000000000000000000000, pcpi_rs2[7:0]};
	assign c1 = (c0 >> 1) ^ (c0[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c2 = (c1 >> 1) ^ (c1[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c3 = (c2 >> 1) ^ (c2[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c4 = (c3 >> 1) ^ (c3[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c5 = (c4 >> 1) ^ (c4[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c6 = (c5 >> 1) ^ (c5[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c7 = (c6 >> 1) ^ (c6[0] ? POLY : 32'b00000000000000000000000000000000);
	assign c8 = (c7 >> 1) ^ (c7[0] ? POLY : 32'b00000000000000000000000000000000);
	assign pcpi_wait = 1'b0;
	always @(posedge clk)
		if (!resetn) begin
			pcpi_wr <= 1'b0;
			pcpi_rd <= 32'b00000000000000000000000000000000;
			pcpi_ready <= 1'b0;
		end
		else begin
			pcpi_wr <= 1'b0;
			pcpi_ready <= 1'b0;
			if (is_crc32 && !pcpi_ready) begin
				pcpi_rd <= c8;
				pcpi_wr <= 1'b1;
				pcpi_ready <= 1'b1;
			end
		end
endmodule
module pico_shim (
	clk,
	rst_n,
	mem_valid,
	mem_instr,
	mem_ready,
	mem_addr,
	mem_wdata,
	mem_wstrb,
	mem_rdata,
	instr_req,
	instr_gnt,
	instr_addr,
	instr_rvalid,
	instr_rdata,
	data_req,
	data_gnt,
	data_we,
	data_be,
	data_addr,
	data_wdata,
	data_rvalid,
	data_rdata
);
	input wire clk;
	input wire rst_n;
	input wire mem_valid;
	input wire mem_instr;
	output wire mem_ready;
	input wire [31:0] mem_addr;
	input wire [31:0] mem_wdata;
	input wire [3:0] mem_wstrb;
	output wire [31:0] mem_rdata;
	output wire instr_req;
	input wire instr_gnt;
	output wire [31:0] instr_addr;
	input wire instr_rvalid;
	input wire [31:0] instr_rdata;
	output wire data_req;
	input wire data_gnt;
	output wire data_we;
	output wire [3:0] data_be;
	output wire [31:0] data_addr;
	output wire [31:0] data_wdata;
	input wire data_rvalid;
	input wire [31:0] data_rdata;
	reg inflight;
	reg sel_instr;
	wire launch;
	assign launch = (mem_valid & ~inflight) & ~mem_ready;
	wire want_instr;
	assign want_instr = mem_instr;
	assign instr_req = (launch & want_instr) | (inflight & sel_instr);
	assign instr_addr = mem_addr;
	assign data_req = (launch & ~want_instr) | (inflight & ~sel_instr);
	assign data_we = |mem_wstrb;
	assign data_be = mem_wstrb;
	assign data_addr = mem_addr;
	assign data_wdata = mem_wdata;
	always @(posedge clk or negedge rst_n)
		if (!rst_n) begin
			inflight <= 1'b0;
			sel_instr <= 1'b0;
		end
		else if (launch) begin
			inflight <= 1'b1;
			sel_instr <= want_instr;
		end
		else if (mem_ready)
			inflight <= 1'b0;
	wire done;
	assign done = inflight & (sel_instr ? instr_rvalid : data_rvalid);
	assign mem_ready = done;
	assign mem_rdata = (sel_instr ? instr_rdata : data_rdata);
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
	mem_re,
	mem_addr,
	mem_wdata,
	mem_rdata,
	status_in,
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
	output wire mem_re;
	output wire [15:0] mem_addr;
	output wire [31:0] mem_wdata;
	input wire [31:0] mem_rdata;
	input wire [31:0] status_in;
	output wire fsm_cfg_load;
	output wire [1:0] fsm_mode;
	output wire [15:0] fsm_count;
	output wire clk_cfg_load;
	output wire clk_int;
	output wire [7:0] clk_div;
	localparam signed [31:0] FRAME_BITS = 48;
	reg [47:0] shift_reg;
	assign scan_out = shift_reg[0];
	wire [1:0] tgt_pre;
	assign tgt_pre = shift_reg[47:46];
	wire status_sel;
	assign status_sel = (tgt_pre == 2'd3) & shift_reg[45];
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			shift_reg <= 1'sb0;
		else if (scan_i0o1)
			shift_reg[31:0] <= (status_sel ? status_in : mem_rdata);
		else if (scan_shift)
			shift_reg <= {scan_in, shift_reg[47:1]};
	wire [1:0] tgt;
	assign tgt = shift_reg[47:46];
	assign mem_addr = {2'b00, shift_reg[45:32]};
	assign mem_wdata = shift_reg[31:0];
	assign mem_we = scan_load & (tgt == 2'd0);
	assign mem_re = (scan_load & (tgt == 2'd3)) & ~shift_reg[45];
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
						if (~sclk_int) begin
							rx_shift <= {rx_shift[6:0], miso};
							if (bit_count == 4'd7) begin
								state <= 1'd0;
								busy <= 1'b0;
								cs_n <= 1'b1;
								sclk_int <= 1'b0;
								rx_data <= {rx_shift[6:0], miso};
							end
							else
								bit_count <= bit_count + 1'b1;
						end
						else
							tx_shift <= {tx_shift[6:0], 1'b0};
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
module picorv32 (
	clk,
	resetn,
	trap,
	mem_valid,
	mem_instr,
	mem_ready,
	mem_addr,
	mem_wdata,
	mem_wstrb,
	mem_rdata,
	mem_la_read,
	mem_la_write,
	mem_la_addr,
	mem_la_wdata,
	mem_la_wstrb,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready,
	irq,
	eoi,
	trace_valid,
	trace_data
);
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_COUNTERS64 = 1;
	parameter [0:0] ENABLE_REGS_16_31 = 1;
	parameter [0:0] ENABLE_REGS_DUALPORT = 1;
	parameter [0:0] LATCHED_MEM_RDATA = 0;
	parameter [0:0] TWO_STAGE_SHIFT = 1;
	parameter [0:0] BARREL_SHIFTER = 0;
	parameter [0:0] TWO_CYCLE_COMPARE = 0;
	parameter [0:0] TWO_CYCLE_ALU = 0;
	parameter [0:0] COMPRESSED_ISA = 0;
	parameter [0:0] CATCH_MISALIGN = 1;
	parameter [0:0] CATCH_ILLINSN = 1;
	parameter [0:0] ENABLE_PCPI = 0;
	parameter [0:0] ENABLE_MUL = 0;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_DIV = 0;
	parameter [0:0] ENABLE_IRQ = 0;
	parameter [0:0] ENABLE_IRQ_QREGS = 1;
	parameter [0:0] ENABLE_IRQ_TIMER = 1;
	parameter [0:0] ENABLE_TRACE = 0;
	parameter [0:0] REGS_INIT_ZERO = 0;
	parameter [31:0] MASKED_IRQ = 32'h00000000;
	parameter [31:0] LATCHED_IRQ = 32'hffffffff;
	parameter [31:0] PROGADDR_RESET = 32'h00000000;
	parameter [31:0] PROGADDR_IRQ = 32'h00000010;
	parameter [31:0] STACKADDR = 32'hffffffff;
	input clk;
	input resetn;
	output reg trap;
	output reg mem_valid;
	output reg mem_instr;
	input mem_ready;
	output reg [31:0] mem_addr;
	output reg [31:0] mem_wdata;
	output reg [3:0] mem_wstrb;
	input [31:0] mem_rdata;
	output wire mem_la_read;
	output wire mem_la_write;
	output wire [31:0] mem_la_addr;
	output reg [31:0] mem_la_wdata;
	output reg [3:0] mem_la_wstrb;
	output reg pcpi_valid;
	output reg [31:0] pcpi_insn;
	output wire [31:0] pcpi_rs1;
	output wire [31:0] pcpi_rs2;
	input pcpi_wr;
	input [31:0] pcpi_rd;
	input pcpi_wait;
	input pcpi_ready;
	input [31:0] irq;
	output reg [31:0] eoi;
	output reg trace_valid;
	output reg [35:0] trace_data;
	localparam integer irq_timer = 0;
	localparam integer irq_ebreak = 1;
	localparam integer irq_buserror = 2;
	localparam integer irqregs_offset = (ENABLE_REGS_16_31 ? 32 : 16);
	localparam integer regfile_size = (ENABLE_REGS_16_31 ? 32 : 16) + ((4 * ENABLE_IRQ) * ENABLE_IRQ_QREGS);
	localparam integer regindex_bits = (ENABLE_REGS_16_31 ? 5 : 4) + (ENABLE_IRQ * ENABLE_IRQ_QREGS);
	localparam WITH_PCPI = ((ENABLE_PCPI || ENABLE_MUL) || ENABLE_FAST_MUL) || ENABLE_DIV;
	localparam [35:0] TRACE_BRANCH = 36'b000100000000000000000000000000000000;
	localparam [35:0] TRACE_ADDR = 36'b001000000000000000000000000000000000;
	localparam [35:0] TRACE_IRQ = 36'b100000000000000000000000000000000000;
	reg [63:0] count_cycle;
	reg [63:0] count_instr;
	reg [31:0] reg_pc;
	reg [31:0] reg_next_pc;
	reg [31:0] reg_op1;
	reg [31:0] reg_op2;
	reg [31:0] reg_out;
	reg [4:0] reg_sh;
	reg [31:0] next_insn_opcode;
	reg [31:0] dbg_insn_opcode;
	reg [31:0] dbg_insn_addr;
	wire dbg_mem_valid = mem_valid;
	wire dbg_mem_instr = mem_instr;
	wire dbg_mem_ready = mem_ready;
	wire [31:0] dbg_mem_addr = mem_addr;
	wire [31:0] dbg_mem_wdata = mem_wdata;
	wire [3:0] dbg_mem_wstrb = mem_wstrb;
	wire [31:0] dbg_mem_rdata = mem_rdata;
	assign pcpi_rs1 = reg_op1;
	assign pcpi_rs2 = reg_op2;
	wire [31:0] next_pc;
	reg irq_delay;
	reg irq_active;
	reg [31:0] irq_mask;
	reg [31:0] irq_pending;
	reg [31:0] timer;
	reg [31:0] cpuregs [0:regfile_size - 1];
	integer i;
	initial if (REGS_INIT_ZERO)
		for (i = 0; i < regfile_size; i = i + 1)
			cpuregs[i] = 0;
	task empty_statement;
		;
	endtask
	wire pcpi_mul_wr;
	wire [31:0] pcpi_mul_rd;
	wire pcpi_mul_wait;
	wire pcpi_mul_ready;
	wire pcpi_div_wr;
	wire [31:0] pcpi_div_rd;
	wire pcpi_div_wait;
	wire pcpi_div_ready;
	reg pcpi_int_wr;
	reg [31:0] pcpi_int_rd;
	reg pcpi_int_wait;
	reg pcpi_int_ready;
	generate
		if (ENABLE_FAST_MUL) begin : genblk1
			picorv32_pcpi_fast_mul pcpi_mul(
				.clk(clk),
				.resetn(resetn),
				.pcpi_valid(pcpi_valid),
				.pcpi_insn(pcpi_insn),
				.pcpi_rs1(pcpi_rs1),
				.pcpi_rs2(pcpi_rs2),
				.pcpi_wr(pcpi_mul_wr),
				.pcpi_rd(pcpi_mul_rd),
				.pcpi_wait(pcpi_mul_wait),
				.pcpi_ready(pcpi_mul_ready)
			);
		end
		else if (ENABLE_MUL) begin : genblk1
			picorv32_pcpi_mul pcpi_mul(
				.clk(clk),
				.resetn(resetn),
				.pcpi_valid(pcpi_valid),
				.pcpi_insn(pcpi_insn),
				.pcpi_rs1(pcpi_rs1),
				.pcpi_rs2(pcpi_rs2),
				.pcpi_wr(pcpi_mul_wr),
				.pcpi_rd(pcpi_mul_rd),
				.pcpi_wait(pcpi_mul_wait),
				.pcpi_ready(pcpi_mul_ready)
			);
		end
		else begin : genblk1
			assign pcpi_mul_wr = 0;
			assign pcpi_mul_rd = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			assign pcpi_mul_wait = 0;
			assign pcpi_mul_ready = 0;
		end
		if (ENABLE_DIV) begin : genblk2
			picorv32_pcpi_div pcpi_div(
				.clk(clk),
				.resetn(resetn),
				.pcpi_valid(pcpi_valid),
				.pcpi_insn(pcpi_insn),
				.pcpi_rs1(pcpi_rs1),
				.pcpi_rs2(pcpi_rs2),
				.pcpi_wr(pcpi_div_wr),
				.pcpi_rd(pcpi_div_rd),
				.pcpi_wait(pcpi_div_wait),
				.pcpi_ready(pcpi_div_ready)
			);
		end
		else begin : genblk2
			assign pcpi_div_wr = 0;
			assign pcpi_div_rd = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
			assign pcpi_div_wait = 0;
			assign pcpi_div_ready = 0;
		end
	endgenerate
	always @(*) begin
		pcpi_int_wr = 0;
		pcpi_int_rd = 32'bxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx;
		pcpi_int_wait = |{ENABLE_PCPI && pcpi_wait, (ENABLE_MUL || ENABLE_FAST_MUL) && pcpi_mul_wait, ENABLE_DIV && pcpi_div_wait};
		pcpi_int_ready = |{ENABLE_PCPI && pcpi_ready, (ENABLE_MUL || ENABLE_FAST_MUL) && pcpi_mul_ready, ENABLE_DIV && pcpi_div_ready};
		(* parallel_case *)
		case (1'b1)
			ENABLE_PCPI && pcpi_ready: begin
				pcpi_int_wr = (ENABLE_PCPI ? pcpi_wr : 0);
				pcpi_int_rd = (ENABLE_PCPI ? pcpi_rd : 0);
			end
			(ENABLE_MUL || ENABLE_FAST_MUL) && pcpi_mul_ready: begin
				pcpi_int_wr = pcpi_mul_wr;
				pcpi_int_rd = pcpi_mul_rd;
			end
			ENABLE_DIV && pcpi_div_ready: begin
				pcpi_int_wr = pcpi_div_wr;
				pcpi_int_rd = pcpi_div_rd;
			end
		endcase
	end
	reg [1:0] mem_state;
	reg [1:0] mem_wordsize;
	reg [31:0] mem_rdata_word;
	reg [31:0] mem_rdata_q;
	reg mem_do_prefetch;
	reg mem_do_rinst;
	reg mem_do_rdata;
	reg mem_do_wdata;
	wire mem_xfer;
	reg mem_la_secondword;
	reg mem_la_firstword_reg;
	reg last_mem_valid;
	wire mem_la_firstword = ((COMPRESSED_ISA && (mem_do_prefetch || mem_do_rinst)) && next_pc[1]) && !mem_la_secondword;
	wire mem_la_firstword_xfer = (COMPRESSED_ISA && mem_xfer) && (!last_mem_valid ? mem_la_firstword : mem_la_firstword_reg);
	reg prefetched_high_word;
	reg clear_prefetched_high_word;
	reg [15:0] mem_16bit_buffer;
	wire [31:0] mem_rdata_latched_noshuffle;
	wire [31:0] mem_rdata_latched;
	wire mem_la_use_prefetched_high_word = ((COMPRESSED_ISA && mem_la_firstword) && prefetched_high_word) && !clear_prefetched_high_word;
	assign mem_xfer = (mem_valid && mem_ready) || (mem_la_use_prefetched_high_word && mem_do_rinst);
	wire mem_busy = |{mem_do_prefetch, mem_do_rinst, mem_do_rdata, mem_do_wdata};
	wire mem_done = (resetn && (((mem_xfer && |mem_state) && ((mem_do_rinst || mem_do_rdata) || mem_do_wdata)) || (&mem_state && mem_do_rinst))) && (!mem_la_firstword || (~&mem_rdata_latched[1:0] && mem_xfer));
	assign mem_la_write = (resetn && !mem_state) && mem_do_wdata;
	assign mem_la_read = resetn && (((!mem_la_use_prefetched_high_word && !mem_state) && ((mem_do_rinst || mem_do_prefetch) || mem_do_rdata)) || ((((COMPRESSED_ISA && mem_xfer) && (!last_mem_valid ? mem_la_firstword : mem_la_firstword_reg)) && !mem_la_secondword) && &mem_rdata_latched[1:0]));
	assign mem_la_addr = (mem_do_prefetch || mem_do_rinst ? {next_pc[31:2] + mem_la_firstword_xfer, 2'b00} : {reg_op1[31:2], 2'b00});
	assign mem_rdata_latched_noshuffle = (mem_xfer || LATCHED_MEM_RDATA ? mem_rdata : mem_rdata_q);
	assign mem_rdata_latched = (COMPRESSED_ISA && mem_la_use_prefetched_high_word ? {16'bxxxxxxxxxxxxxxxx, mem_16bit_buffer} : (COMPRESSED_ISA && mem_la_secondword ? {mem_rdata_latched_noshuffle[15:0], mem_16bit_buffer} : (COMPRESSED_ISA && mem_la_firstword ? {16'bxxxxxxxxxxxxxxxx, mem_rdata_latched_noshuffle[31:16]} : mem_rdata_latched_noshuffle)));
	always @(posedge clk)
		if (!resetn) begin
			mem_la_firstword_reg <= 0;
			last_mem_valid <= 0;
		end
		else begin
			if (!last_mem_valid)
				mem_la_firstword_reg <= mem_la_firstword;
			last_mem_valid <= mem_valid && !mem_ready;
		end
	always @(*)
		(* full_case *)
		case (mem_wordsize)
			0: begin
				mem_la_wdata = reg_op2;
				mem_la_wstrb = 4'b1111;
				mem_rdata_word = mem_rdata;
			end
			1: begin
				mem_la_wdata = {2 {reg_op2[15:0]}};
				mem_la_wstrb = (reg_op1[1] ? 4'b1100 : 4'b0011);
				case (reg_op1[1])
					1'b0: mem_rdata_word = {16'b0000000000000000, mem_rdata[15:0]};
					1'b1: mem_rdata_word = {16'b0000000000000000, mem_rdata[31:16]};
				endcase
			end
			2: begin
				mem_la_wdata = {4 {reg_op2[7:0]}};
				mem_la_wstrb = 4'b0001 << reg_op1[1:0];
				case (reg_op1[1:0])
					2'b00: mem_rdata_word = {24'b000000000000000000000000, mem_rdata[7:0]};
					2'b01: mem_rdata_word = {24'b000000000000000000000000, mem_rdata[15:8]};
					2'b10: mem_rdata_word = {24'b000000000000000000000000, mem_rdata[23:16]};
					2'b11: mem_rdata_word = {24'b000000000000000000000000, mem_rdata[31:24]};
				endcase
			end
		endcase
	always @(posedge clk) begin
		if (mem_xfer) begin
			mem_rdata_q <= (COMPRESSED_ISA ? mem_rdata_latched : mem_rdata);
			next_insn_opcode <= (COMPRESSED_ISA ? mem_rdata_latched : mem_rdata);
		end
		if ((COMPRESSED_ISA && mem_done) && (mem_do_prefetch || mem_do_rinst))
			case (mem_rdata_latched[1:0])
				2'b00:
					case (mem_rdata_latched[15:13])
						3'b000: begin
							mem_rdata_q[14:12] <= 3'b000;
							mem_rdata_q[31:20] <= {2'b00, mem_rdata_latched[10:7], mem_rdata_latched[12:11], mem_rdata_latched[5], mem_rdata_latched[6], 2'b00};
						end
						3'b010: begin
							mem_rdata_q[31:20] <= {5'b00000, mem_rdata_latched[5], mem_rdata_latched[12:10], mem_rdata_latched[6], 2'b00};
							mem_rdata_q[14:12] <= 3'b010;
						end
						3'b110: begin
							{mem_rdata_q[31:25], mem_rdata_q[11:7]} <= {5'b00000, mem_rdata_latched[5], mem_rdata_latched[12:10], mem_rdata_latched[6], 2'b00};
							mem_rdata_q[14:12] <= 3'b010;
						end
					endcase
				2'b01:
					case (mem_rdata_latched[15:13])
						3'b000: begin
							mem_rdata_q[14:12] <= 3'b000;
							mem_rdata_q[31:20] <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:2]});
						end
						3'b010: begin
							mem_rdata_q[14:12] <= 3'b000;
							mem_rdata_q[31:20] <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:2]});
						end
						3'b011:
							if (mem_rdata_latched[11:7] == 2) begin
								mem_rdata_q[14:12] <= 3'b000;
								mem_rdata_q[31:20] <= $signed({mem_rdata_latched[12], mem_rdata_latched[4:3], mem_rdata_latched[5], mem_rdata_latched[2], mem_rdata_latched[6], 4'b0000});
							end
							else
								mem_rdata_q[31:12] <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:2]});
						3'b100: begin
							if (mem_rdata_latched[11:10] == 2'b00) begin
								mem_rdata_q[31:25] <= 7'b0000000;
								mem_rdata_q[14:12] <= 3'b101;
							end
							if (mem_rdata_latched[11:10] == 2'b01) begin
								mem_rdata_q[31:25] <= 7'b0100000;
								mem_rdata_q[14:12] <= 3'b101;
							end
							if (mem_rdata_latched[11:10] == 2'b10) begin
								mem_rdata_q[14:12] <= 3'b111;
								mem_rdata_q[31:20] <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:2]});
							end
							if (mem_rdata_latched[12:10] == 3'b011) begin
								if (mem_rdata_latched[6:5] == 2'b00)
									mem_rdata_q[14:12] <= 3'b000;
								if (mem_rdata_latched[6:5] == 2'b01)
									mem_rdata_q[14:12] <= 3'b100;
								if (mem_rdata_latched[6:5] == 2'b10)
									mem_rdata_q[14:12] <= 3'b110;
								if (mem_rdata_latched[6:5] == 2'b11)
									mem_rdata_q[14:12] <= 3'b111;
								mem_rdata_q[31:25] <= (mem_rdata_latched[6:5] == 2'b00 ? 7'b0100000 : 7'b0000000);
							end
						end
						3'b110: begin
							mem_rdata_q[14:12] <= 3'b000;
							{mem_rdata_q[31], mem_rdata_q[7], mem_rdata_q[30:25], mem_rdata_q[11:8]} <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:5], mem_rdata_latched[2], mem_rdata_latched[11:10], mem_rdata_latched[4:3]});
						end
						3'b111: begin
							mem_rdata_q[14:12] <= 3'b001;
							{mem_rdata_q[31], mem_rdata_q[7], mem_rdata_q[30:25], mem_rdata_q[11:8]} <= $signed({mem_rdata_latched[12], mem_rdata_latched[6:5], mem_rdata_latched[2], mem_rdata_latched[11:10], mem_rdata_latched[4:3]});
						end
					endcase
				2'b10:
					case (mem_rdata_latched[15:13])
						3'b000: begin
							mem_rdata_q[31:25] <= 7'b0000000;
							mem_rdata_q[14:12] <= 3'b001;
						end
						3'b010: begin
							mem_rdata_q[31:20] <= {4'b0000, mem_rdata_latched[3:2], mem_rdata_latched[12], mem_rdata_latched[6:4], 2'b00};
							mem_rdata_q[14:12] <= 3'b010;
						end
						3'b100: begin
							if ((mem_rdata_latched[12] == 0) && (mem_rdata_latched[6:2] == 0)) begin
								mem_rdata_q[14:12] <= 3'b000;
								mem_rdata_q[31:20] <= 12'b000000000000;
							end
							if ((mem_rdata_latched[12] == 0) && (mem_rdata_latched[6:2] != 0)) begin
								mem_rdata_q[14:12] <= 3'b000;
								mem_rdata_q[31:25] <= 7'b0000000;
							end
							if (((mem_rdata_latched[12] != 0) && (mem_rdata_latched[11:7] != 0)) && (mem_rdata_latched[6:2] == 0)) begin
								mem_rdata_q[14:12] <= 3'b000;
								mem_rdata_q[31:20] <= 12'b000000000000;
							end
							if ((mem_rdata_latched[12] != 0) && (mem_rdata_latched[6:2] != 0)) begin
								mem_rdata_q[14:12] <= 3'b000;
								mem_rdata_q[31:25] <= 7'b0000000;
							end
						end
						3'b110: begin
							{mem_rdata_q[31:25], mem_rdata_q[11:7]} <= {4'b0000, mem_rdata_latched[8:7], mem_rdata_latched[12:9], 2'b00};
							mem_rdata_q[14:12] <= 3'b010;
						end
					endcase
			endcase
	end
	always @(posedge clk)
		if (resetn && !trap) begin
			if ((mem_do_prefetch || mem_do_rinst) || mem_do_rdata)
				empty_statement;
			if (mem_do_prefetch || mem_do_rinst)
				empty_statement;
			if (mem_do_rdata)
				empty_statement;
			if (mem_do_wdata)
				empty_statement;
			if ((mem_state == 2) || (mem_state == 3))
				empty_statement;
		end
	always @(posedge clk) begin
		if (!resetn || trap) begin
			if (!resetn)
				mem_state <= 0;
			if (!resetn || mem_ready)
				mem_valid <= 0;
			mem_la_secondword <= 0;
			prefetched_high_word <= 0;
		end
		else begin
			if (mem_la_read || mem_la_write) begin
				mem_addr <= mem_la_addr;
				mem_wstrb <= mem_la_wstrb & {4 {mem_la_write}};
			end
			if (mem_la_write)
				mem_wdata <= mem_la_wdata;
			case (mem_state)
				0: begin
					if ((mem_do_prefetch || mem_do_rinst) || mem_do_rdata) begin
						mem_valid <= !mem_la_use_prefetched_high_word;
						mem_instr <= mem_do_prefetch || mem_do_rinst;
						mem_wstrb <= 0;
						mem_state <= 1;
					end
					if (mem_do_wdata) begin
						mem_valid <= 1;
						mem_instr <= 0;
						mem_state <= 2;
					end
				end
				1: begin
					empty_statement;
					empty_statement;
					empty_statement;
					empty_statement;
					if (mem_xfer) begin
						if (COMPRESSED_ISA && mem_la_read) begin
							mem_valid <= 1;
							mem_la_secondword <= 1;
							if (!mem_la_use_prefetched_high_word)
								mem_16bit_buffer <= mem_rdata[31:16];
						end
						else begin
							mem_valid <= 0;
							mem_la_secondword <= 0;
							if (COMPRESSED_ISA && !mem_do_rdata) begin
								if (~&mem_rdata[1:0] || mem_la_secondword) begin
									mem_16bit_buffer <= mem_rdata[31:16];
									prefetched_high_word <= 1;
								end
								else
									prefetched_high_word <= 0;
							end
							mem_state <= (mem_do_rinst || mem_do_rdata ? 0 : 3);
						end
					end
				end
				2: begin
					empty_statement;
					empty_statement;
					if (mem_xfer) begin
						mem_valid <= 0;
						mem_state <= 0;
					end
				end
				3: begin
					empty_statement;
					empty_statement;
					if (mem_do_rinst)
						mem_state <= 0;
				end
			endcase
		end
		if (clear_prefetched_high_word)
			prefetched_high_word <= 0;
	end
	reg instr_lui;
	reg instr_auipc;
	reg instr_jal;
	reg instr_jalr;
	reg instr_beq;
	reg instr_bne;
	reg instr_blt;
	reg instr_bge;
	reg instr_bltu;
	reg instr_bgeu;
	reg instr_lb;
	reg instr_lh;
	reg instr_lw;
	reg instr_lbu;
	reg instr_lhu;
	reg instr_sb;
	reg instr_sh;
	reg instr_sw;
	reg instr_addi;
	reg instr_slti;
	reg instr_sltiu;
	reg instr_xori;
	reg instr_ori;
	reg instr_andi;
	reg instr_slli;
	reg instr_srli;
	reg instr_srai;
	reg instr_add;
	reg instr_sub;
	reg instr_sll;
	reg instr_slt;
	reg instr_sltu;
	reg instr_xor;
	reg instr_srl;
	reg instr_sra;
	reg instr_or;
	reg instr_and;
	reg instr_rdcycle;
	reg instr_rdcycleh;
	reg instr_rdinstr;
	reg instr_rdinstrh;
	reg instr_ecall_ebreak;
	reg instr_fence;
	reg instr_getq;
	reg instr_setq;
	reg instr_retirq;
	reg instr_maskirq;
	reg instr_waitirq;
	reg instr_timer;
	wire instr_trap;
	reg [regindex_bits - 1:0] decoded_rd;
	reg [regindex_bits - 1:0] decoded_rs1;
	reg [4:0] decoded_rs2;
	reg [31:0] decoded_imm;
	reg [31:0] decoded_imm_j;
	reg decoder_trigger;
	reg decoder_trigger_q;
	reg decoder_pseudo_trigger;
	reg decoder_pseudo_trigger_q;
	reg compressed_instr;
	reg is_lui_auipc_jal;
	reg is_lb_lh_lw_lbu_lhu;
	reg is_slli_srli_srai;
	reg is_jalr_addi_slti_sltiu_xori_ori_andi;
	reg is_sb_sh_sw;
	reg is_sll_srl_sra;
	reg is_lui_auipc_jal_jalr_addi_add_sub;
	reg is_slti_blt_slt;
	reg is_sltiu_bltu_sltu;
	reg is_beq_bne_blt_bge_bltu_bgeu;
	reg is_lbu_lhu_lw;
	reg is_alu_reg_imm;
	reg is_alu_reg_reg;
	reg is_compare;
	assign instr_trap = (CATCH_ILLINSN || WITH_PCPI) && !{instr_lui, instr_auipc, instr_jal, instr_jalr, instr_beq, instr_bne, instr_blt, instr_bge, instr_bltu, instr_bgeu, instr_lb, instr_lh, instr_lw, instr_lbu, instr_lhu, instr_sb, instr_sh, instr_sw, instr_addi, instr_slti, instr_sltiu, instr_xori, instr_ori, instr_andi, instr_slli, instr_srli, instr_srai, instr_add, instr_sub, instr_sll, instr_slt, instr_sltu, instr_xor, instr_srl, instr_sra, instr_or, instr_and, instr_rdcycle, instr_rdcycleh, instr_rdinstr, instr_rdinstrh, instr_fence, instr_getq, instr_setq, instr_retirq, instr_maskirq, instr_waitirq, instr_timer};
	wire is_rdcycle_rdcycleh_rdinstr_rdinstrh;
	assign is_rdcycle_rdcycleh_rdinstr_rdinstrh = |{instr_rdcycle, instr_rdcycleh, instr_rdinstr, instr_rdinstrh};
	reg [63:0] new_ascii_instr;
	reg [63:0] dbg_ascii_instr;
	reg [31:0] dbg_insn_imm;
	reg [4:0] dbg_insn_rs1;
	reg [4:0] dbg_insn_rs2;
	reg [4:0] dbg_insn_rd;
	reg [31:0] dbg_rs1val;
	reg [31:0] dbg_rs2val;
	reg dbg_rs1val_valid;
	reg dbg_rs2val_valid;
	always @(*) begin
		new_ascii_instr = "";
		if (instr_lui)
			new_ascii_instr = "lui";
		if (instr_auipc)
			new_ascii_instr = "auipc";
		if (instr_jal)
			new_ascii_instr = "jal";
		if (instr_jalr)
			new_ascii_instr = "jalr";
		if (instr_beq)
			new_ascii_instr = "beq";
		if (instr_bne)
			new_ascii_instr = "bne";
		if (instr_blt)
			new_ascii_instr = "blt";
		if (instr_bge)
			new_ascii_instr = "bge";
		if (instr_bltu)
			new_ascii_instr = "bltu";
		if (instr_bgeu)
			new_ascii_instr = "bgeu";
		if (instr_lb)
			new_ascii_instr = "lb";
		if (instr_lh)
			new_ascii_instr = "lh";
		if (instr_lw)
			new_ascii_instr = "lw";
		if (instr_lbu)
			new_ascii_instr = "lbu";
		if (instr_lhu)
			new_ascii_instr = "lhu";
		if (instr_sb)
			new_ascii_instr = "sb";
		if (instr_sh)
			new_ascii_instr = "sh";
		if (instr_sw)
			new_ascii_instr = "sw";
		if (instr_addi)
			new_ascii_instr = "addi";
		if (instr_slti)
			new_ascii_instr = "slti";
		if (instr_sltiu)
			new_ascii_instr = "sltiu";
		if (instr_xori)
			new_ascii_instr = "xori";
		if (instr_ori)
			new_ascii_instr = "ori";
		if (instr_andi)
			new_ascii_instr = "andi";
		if (instr_slli)
			new_ascii_instr = "slli";
		if (instr_srli)
			new_ascii_instr = "srli";
		if (instr_srai)
			new_ascii_instr = "srai";
		if (instr_add)
			new_ascii_instr = "add";
		if (instr_sub)
			new_ascii_instr = "sub";
		if (instr_sll)
			new_ascii_instr = "sll";
		if (instr_slt)
			new_ascii_instr = "slt";
		if (instr_sltu)
			new_ascii_instr = "sltu";
		if (instr_xor)
			new_ascii_instr = "xor";
		if (instr_srl)
			new_ascii_instr = "srl";
		if (instr_sra)
			new_ascii_instr = "sra";
		if (instr_or)
			new_ascii_instr = "or";
		if (instr_and)
			new_ascii_instr = "and";
		if (instr_rdcycle)
			new_ascii_instr = "rdcycle";
		if (instr_rdcycleh)
			new_ascii_instr = "rdcycleh";
		if (instr_rdinstr)
			new_ascii_instr = "rdinstr";
		if (instr_rdinstrh)
			new_ascii_instr = "rdinstrh";
		if (instr_fence)
			new_ascii_instr = "fence";
		if (instr_getq)
			new_ascii_instr = "getq";
		if (instr_setq)
			new_ascii_instr = "setq";
		if (instr_retirq)
			new_ascii_instr = "retirq";
		if (instr_maskirq)
			new_ascii_instr = "maskirq";
		if (instr_waitirq)
			new_ascii_instr = "waitirq";
		if (instr_timer)
			new_ascii_instr = "timer";
	end
	reg [63:0] q_ascii_instr;
	reg [31:0] q_insn_imm;
	reg [31:0] q_insn_opcode;
	reg [4:0] q_insn_rs1;
	reg [4:0] q_insn_rs2;
	reg [4:0] q_insn_rd;
	reg dbg_next;
	wire launch_next_insn;
	reg dbg_valid_insn;
	reg [63:0] cached_ascii_instr;
	reg [31:0] cached_insn_imm;
	reg [31:0] cached_insn_opcode;
	reg [4:0] cached_insn_rs1;
	reg [4:0] cached_insn_rs2;
	reg [4:0] cached_insn_rd;
	always @(posedge clk) begin
		q_ascii_instr <= dbg_ascii_instr;
		q_insn_imm <= dbg_insn_imm;
		q_insn_opcode <= dbg_insn_opcode;
		q_insn_rs1 <= dbg_insn_rs1;
		q_insn_rs2 <= dbg_insn_rs2;
		q_insn_rd <= dbg_insn_rd;
		dbg_next <= launch_next_insn;
		if (!resetn || trap)
			dbg_valid_insn <= 0;
		else if (launch_next_insn)
			dbg_valid_insn <= 1;
		if (decoder_trigger_q) begin
			cached_ascii_instr <= new_ascii_instr;
			cached_insn_imm <= decoded_imm;
			if (&next_insn_opcode[1:0])
				cached_insn_opcode <= next_insn_opcode;
			else
				cached_insn_opcode <= {16'b0000000000000000, next_insn_opcode[15:0]};
			cached_insn_rs1 <= decoded_rs1;
			cached_insn_rs2 <= decoded_rs2;
			cached_insn_rd <= decoded_rd;
		end
		if (launch_next_insn)
			dbg_insn_addr <= next_pc;
	end
	always @(*) begin
		dbg_ascii_instr = q_ascii_instr;
		dbg_insn_imm = q_insn_imm;
		dbg_insn_opcode = q_insn_opcode;
		dbg_insn_rs1 = q_insn_rs1;
		dbg_insn_rs2 = q_insn_rs2;
		dbg_insn_rd = q_insn_rd;
		if (dbg_next) begin
			if (decoder_pseudo_trigger_q) begin
				dbg_ascii_instr = cached_ascii_instr;
				dbg_insn_imm = cached_insn_imm;
				dbg_insn_opcode = cached_insn_opcode;
				dbg_insn_rs1 = cached_insn_rs1;
				dbg_insn_rs2 = cached_insn_rs2;
				dbg_insn_rd = cached_insn_rd;
			end
			else begin
				dbg_ascii_instr = new_ascii_instr;
				if (&next_insn_opcode[1:0])
					dbg_insn_opcode = next_insn_opcode;
				else
					dbg_insn_opcode = {16'b0000000000000000, next_insn_opcode[15:0]};
				dbg_insn_imm = decoded_imm;
				dbg_insn_rs1 = decoded_rs1;
				dbg_insn_rs2 = decoded_rs2;
				dbg_insn_rd = decoded_rd;
			end
		end
	end
	always @(posedge clk) begin
		is_lui_auipc_jal <= |{instr_lui, instr_auipc, instr_jal};
		is_lui_auipc_jal_jalr_addi_add_sub <= |{instr_lui, instr_auipc, instr_jal, instr_jalr, instr_addi, instr_add, instr_sub};
		is_slti_blt_slt <= |{instr_slti, instr_blt, instr_slt};
		is_sltiu_bltu_sltu <= |{instr_sltiu, instr_bltu, instr_sltu};
		is_lbu_lhu_lw <= |{instr_lbu, instr_lhu, instr_lw};
		is_compare <= |{is_beq_bne_blt_bge_bltu_bgeu, instr_slti, instr_slt, instr_sltiu, instr_sltu};
		if (mem_do_rinst && mem_done) begin
			instr_lui <= mem_rdata_latched[6:0] == 7'b0110111;
			instr_auipc <= mem_rdata_latched[6:0] == 7'b0010111;
			instr_jal <= mem_rdata_latched[6:0] == 7'b1101111;
			instr_jalr <= (mem_rdata_latched[6:0] == 7'b1100111) && (mem_rdata_latched[14:12] == 3'b000);
			instr_retirq <= ((mem_rdata_latched[6:0] == 7'b0001011) && (mem_rdata_latched[31:25] == 7'b0000010)) && ENABLE_IRQ;
			instr_waitirq <= ((mem_rdata_latched[6:0] == 7'b0001011) && (mem_rdata_latched[31:25] == 7'b0000100)) && ENABLE_IRQ;
			is_beq_bne_blt_bge_bltu_bgeu <= mem_rdata_latched[6:0] == 7'b1100011;
			is_lb_lh_lw_lbu_lhu <= mem_rdata_latched[6:0] == 7'b0000011;
			is_sb_sh_sw <= mem_rdata_latched[6:0] == 7'b0100011;
			is_alu_reg_imm <= mem_rdata_latched[6:0] == 7'b0010011;
			is_alu_reg_reg <= mem_rdata_latched[6:0] == 7'b0110011;
			{decoded_imm_j[31:20], decoded_imm_j[10:1], decoded_imm_j[11], decoded_imm_j[19:12], decoded_imm_j[0]} <= $signed({mem_rdata_latched[31:12], 1'b0});
			decoded_rd <= mem_rdata_latched[11:7];
			decoded_rs1 <= mem_rdata_latched[19:15];
			decoded_rs2 <= mem_rdata_latched[24:20];
			if ((((mem_rdata_latched[6:0] == 7'b0001011) && (mem_rdata_latched[31:25] == 7'b0000000)) && ENABLE_IRQ) && ENABLE_IRQ_QREGS)
				decoded_rs1[regindex_bits - 1] <= 1;
			if (((mem_rdata_latched[6:0] == 7'b0001011) && (mem_rdata_latched[31:25] == 7'b0000010)) && ENABLE_IRQ)
				decoded_rs1 <= (ENABLE_IRQ_QREGS ? irqregs_offset : 3);
			compressed_instr <= 0;
			if (COMPRESSED_ISA && (mem_rdata_latched[1:0] != 2'b11)) begin
				compressed_instr <= 1;
				decoded_rd <= 0;
				decoded_rs1 <= 0;
				decoded_rs2 <= 0;
				{decoded_imm_j[31:11], decoded_imm_j[4], decoded_imm_j[9:8], decoded_imm_j[10], decoded_imm_j[6], decoded_imm_j[7], decoded_imm_j[3:1], decoded_imm_j[5], decoded_imm_j[0]} <= $signed({mem_rdata_latched[12:2], 1'b0});
				case (mem_rdata_latched[1:0])
					2'b00:
						case (mem_rdata_latched[15:13])
							3'b000: begin
								is_alu_reg_imm <= |mem_rdata_latched[12:5];
								decoded_rs1 <= 2;
								decoded_rd <= 8 + mem_rdata_latched[4:2];
							end
							3'b010: begin
								is_lb_lh_lw_lbu_lhu <= 1;
								decoded_rs1 <= 8 + mem_rdata_latched[9:7];
								decoded_rd <= 8 + mem_rdata_latched[4:2];
							end
							3'b110: begin
								is_sb_sh_sw <= 1;
								decoded_rs1 <= 8 + mem_rdata_latched[9:7];
								decoded_rs2 <= 8 + mem_rdata_latched[4:2];
							end
						endcase
					2'b01:
						case (mem_rdata_latched[15:13])
							3'b000: begin
								is_alu_reg_imm <= 1;
								decoded_rd <= mem_rdata_latched[11:7];
								decoded_rs1 <= mem_rdata_latched[11:7];
							end
							3'b001: begin
								instr_jal <= 1;
								decoded_rd <= 1;
							end
							3'b010: begin
								is_alu_reg_imm <= 1;
								decoded_rd <= mem_rdata_latched[11:7];
								decoded_rs1 <= 0;
							end
							3'b011:
								if (mem_rdata_latched[12] || mem_rdata_latched[6:2]) begin
									if (mem_rdata_latched[11:7] == 2) begin
										is_alu_reg_imm <= 1;
										decoded_rd <= mem_rdata_latched[11:7];
										decoded_rs1 <= mem_rdata_latched[11:7];
									end
									else begin
										instr_lui <= 1;
										decoded_rd <= mem_rdata_latched[11:7];
										decoded_rs1 <= 0;
									end
								end
							3'b100: begin
								if (!mem_rdata_latched[11] && !mem_rdata_latched[12]) begin
									is_alu_reg_imm <= 1;
									decoded_rd <= 8 + mem_rdata_latched[9:7];
									decoded_rs1 <= 8 + mem_rdata_latched[9:7];
									decoded_rs2 <= {mem_rdata_latched[12], mem_rdata_latched[6:2]};
								end
								if (mem_rdata_latched[11:10] == 2'b10) begin
									is_alu_reg_imm <= 1;
									decoded_rd <= 8 + mem_rdata_latched[9:7];
									decoded_rs1 <= 8 + mem_rdata_latched[9:7];
								end
								if (mem_rdata_latched[12:10] == 3'b011) begin
									is_alu_reg_reg <= 1;
									decoded_rd <= 8 + mem_rdata_latched[9:7];
									decoded_rs1 <= 8 + mem_rdata_latched[9:7];
									decoded_rs2 <= 8 + mem_rdata_latched[4:2];
								end
							end
							3'b101: instr_jal <= 1;
							3'b110: begin
								is_beq_bne_blt_bge_bltu_bgeu <= 1;
								decoded_rs1 <= 8 + mem_rdata_latched[9:7];
								decoded_rs2 <= 0;
							end
							3'b111: begin
								is_beq_bne_blt_bge_bltu_bgeu <= 1;
								decoded_rs1 <= 8 + mem_rdata_latched[9:7];
								decoded_rs2 <= 0;
							end
						endcase
					2'b10:
						case (mem_rdata_latched[15:13])
							3'b000:
								if (!mem_rdata_latched[12]) begin
									is_alu_reg_imm <= 1;
									decoded_rd <= mem_rdata_latched[11:7];
									decoded_rs1 <= mem_rdata_latched[11:7];
									decoded_rs2 <= {mem_rdata_latched[12], mem_rdata_latched[6:2]};
								end
							3'b010:
								if (mem_rdata_latched[11:7]) begin
									is_lb_lh_lw_lbu_lhu <= 1;
									decoded_rd <= mem_rdata_latched[11:7];
									decoded_rs1 <= 2;
								end
							3'b100: begin
								if (((mem_rdata_latched[12] == 0) && (mem_rdata_latched[11:7] != 0)) && (mem_rdata_latched[6:2] == 0)) begin
									instr_jalr <= 1;
									decoded_rd <= 0;
									decoded_rs1 <= mem_rdata_latched[11:7];
								end
								if ((mem_rdata_latched[12] == 0) && (mem_rdata_latched[6:2] != 0)) begin
									is_alu_reg_reg <= 1;
									decoded_rd <= mem_rdata_latched[11:7];
									decoded_rs1 <= 0;
									decoded_rs2 <= mem_rdata_latched[6:2];
								end
								if (((mem_rdata_latched[12] != 0) && (mem_rdata_latched[11:7] != 0)) && (mem_rdata_latched[6:2] == 0)) begin
									instr_jalr <= 1;
									decoded_rd <= 1;
									decoded_rs1 <= mem_rdata_latched[11:7];
								end
								if ((mem_rdata_latched[12] != 0) && (mem_rdata_latched[6:2] != 0)) begin
									is_alu_reg_reg <= 1;
									decoded_rd <= mem_rdata_latched[11:7];
									decoded_rs1 <= mem_rdata_latched[11:7];
									decoded_rs2 <= mem_rdata_latched[6:2];
								end
							end
							3'b110: begin
								is_sb_sh_sw <= 1;
								decoded_rs1 <= 2;
								decoded_rs2 <= mem_rdata_latched[6:2];
							end
						endcase
				endcase
			end
		end
		if (decoder_trigger && !decoder_pseudo_trigger) begin
			pcpi_insn <= (WITH_PCPI ? mem_rdata_q : 'bx);
			instr_beq <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b000);
			instr_bne <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b001);
			instr_blt <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b100);
			instr_bge <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b101);
			instr_bltu <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b110);
			instr_bgeu <= is_beq_bne_blt_bge_bltu_bgeu && (mem_rdata_q[14:12] == 3'b111);
			instr_lb <= is_lb_lh_lw_lbu_lhu && (mem_rdata_q[14:12] == 3'b000);
			instr_lh <= is_lb_lh_lw_lbu_lhu && (mem_rdata_q[14:12] == 3'b001);
			instr_lw <= is_lb_lh_lw_lbu_lhu && (mem_rdata_q[14:12] == 3'b010);
			instr_lbu <= is_lb_lh_lw_lbu_lhu && (mem_rdata_q[14:12] == 3'b100);
			instr_lhu <= is_lb_lh_lw_lbu_lhu && (mem_rdata_q[14:12] == 3'b101);
			instr_sb <= is_sb_sh_sw && (mem_rdata_q[14:12] == 3'b000);
			instr_sh <= is_sb_sh_sw && (mem_rdata_q[14:12] == 3'b001);
			instr_sw <= is_sb_sh_sw && (mem_rdata_q[14:12] == 3'b010);
			instr_addi <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b000);
			instr_slti <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b010);
			instr_sltiu <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b011);
			instr_xori <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b100);
			instr_ori <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b110);
			instr_andi <= is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b111);
			instr_slli <= (is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b001)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_srli <= (is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b101)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_srai <= (is_alu_reg_imm && (mem_rdata_q[14:12] == 3'b101)) && (mem_rdata_q[31:25] == 7'b0100000);
			instr_add <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b000)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_sub <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b000)) && (mem_rdata_q[31:25] == 7'b0100000);
			instr_sll <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b001)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_slt <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b010)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_sltu <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b011)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_xor <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b100)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_srl <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b101)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_sra <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b101)) && (mem_rdata_q[31:25] == 7'b0100000);
			instr_or <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b110)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_and <= (is_alu_reg_reg && (mem_rdata_q[14:12] == 3'b111)) && (mem_rdata_q[31:25] == 7'b0000000);
			instr_rdcycle <= (((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11000000000000000010)) || ((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11000000000100000010))) && ENABLE_COUNTERS;
			instr_rdcycleh <= ((((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11001000000000000010)) || ((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11001000000100000010))) && ENABLE_COUNTERS) && ENABLE_COUNTERS64;
			instr_rdinstr <= ((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11000000001000000010)) && ENABLE_COUNTERS;
			instr_rdinstrh <= (((mem_rdata_q[6:0] == 7'b1110011) && (mem_rdata_q[31:12] == 'b11001000001000000010)) && ENABLE_COUNTERS) && ENABLE_COUNTERS64;
			instr_ecall_ebreak <= (((mem_rdata_q[6:0] == 7'b1110011) && !mem_rdata_q[31:21]) && !mem_rdata_q[19:7]) || (COMPRESSED_ISA && (mem_rdata_q[15:0] == 16'h9002));
			instr_fence <= (mem_rdata_q[6:0] == 7'b0001111) && !mem_rdata_q[14:12];
			instr_getq <= (((mem_rdata_q[6:0] == 7'b0001011) && (mem_rdata_q[31:25] == 7'b0000000)) && ENABLE_IRQ) && ENABLE_IRQ_QREGS;
			instr_setq <= (((mem_rdata_q[6:0] == 7'b0001011) && (mem_rdata_q[31:25] == 7'b0000001)) && ENABLE_IRQ) && ENABLE_IRQ_QREGS;
			instr_maskirq <= ((mem_rdata_q[6:0] == 7'b0001011) && (mem_rdata_q[31:25] == 7'b0000011)) && ENABLE_IRQ;
			instr_timer <= (((mem_rdata_q[6:0] == 7'b0001011) && (mem_rdata_q[31:25] == 7'b0000101)) && ENABLE_IRQ) && ENABLE_IRQ_TIMER;
			is_slli_srli_srai <= is_alu_reg_imm && |{(mem_rdata_q[14:12] == 3'b001) && (mem_rdata_q[31:25] == 7'b0000000), (mem_rdata_q[14:12] == 3'b101) && (mem_rdata_q[31:25] == 7'b0000000), (mem_rdata_q[14:12] == 3'b101) && (mem_rdata_q[31:25] == 7'b0100000)};
			is_jalr_addi_slti_sltiu_xori_ori_andi <= instr_jalr || (is_alu_reg_imm && |{mem_rdata_q[14:12] == 3'b000, mem_rdata_q[14:12] == 3'b010, mem_rdata_q[14:12] == 3'b011, mem_rdata_q[14:12] == 3'b100, mem_rdata_q[14:12] == 3'b110, mem_rdata_q[14:12] == 3'b111});
			is_sll_srl_sra <= is_alu_reg_reg && |{(mem_rdata_q[14:12] == 3'b001) && (mem_rdata_q[31:25] == 7'b0000000), (mem_rdata_q[14:12] == 3'b101) && (mem_rdata_q[31:25] == 7'b0000000), (mem_rdata_q[14:12] == 3'b101) && (mem_rdata_q[31:25] == 7'b0100000)};
			is_lui_auipc_jal_jalr_addi_add_sub <= 0;
			is_compare <= 0;
			(* parallel_case *)
			case (1'b1)
				instr_jal: decoded_imm <= decoded_imm_j;
				|{instr_lui, instr_auipc}: decoded_imm <= mem_rdata_q[31:12] << 12;
				|{instr_jalr, is_lb_lh_lw_lbu_lhu, is_alu_reg_imm}: decoded_imm <= $signed(mem_rdata_q[31:20]);
				is_beq_bne_blt_bge_bltu_bgeu: decoded_imm <= $signed({mem_rdata_q[31], mem_rdata_q[7], mem_rdata_q[30:25], mem_rdata_q[11:8], 1'b0});
				is_sb_sh_sw: decoded_imm <= $signed({mem_rdata_q[31:25], mem_rdata_q[11:7]});
				default: decoded_imm <= 1'bx;
			endcase
		end
		if (!resetn) begin
			is_beq_bne_blt_bge_bltu_bgeu <= 0;
			is_compare <= 0;
			instr_beq <= 0;
			instr_bne <= 0;
			instr_blt <= 0;
			instr_bge <= 0;
			instr_bltu <= 0;
			instr_bgeu <= 0;
			instr_addi <= 0;
			instr_slti <= 0;
			instr_sltiu <= 0;
			instr_xori <= 0;
			instr_ori <= 0;
			instr_andi <= 0;
			instr_add <= 0;
			instr_sub <= 0;
			instr_sll <= 0;
			instr_slt <= 0;
			instr_sltu <= 0;
			instr_xor <= 0;
			instr_srl <= 0;
			instr_sra <= 0;
			instr_or <= 0;
			instr_and <= 0;
			instr_fence <= 0;
		end
	end
	localparam cpu_state_trap = 8'b10000000;
	localparam cpu_state_fetch = 8'b01000000;
	localparam cpu_state_ld_rs1 = 8'b00100000;
	localparam cpu_state_ld_rs2 = 8'b00010000;
	localparam cpu_state_exec = 8'b00001000;
	localparam cpu_state_shift = 8'b00000100;
	localparam cpu_state_stmem = 8'b00000010;
	localparam cpu_state_ldmem = 8'b00000001;
	reg [7:0] cpu_state;
	reg [1:0] irq_state;
	reg [127:0] dbg_ascii_state;
	always @(*) begin
		dbg_ascii_state = "";
		if (cpu_state == cpu_state_trap)
			dbg_ascii_state = "trap";
		if (cpu_state == cpu_state_fetch)
			dbg_ascii_state = "fetch";
		if (cpu_state == cpu_state_ld_rs1)
			dbg_ascii_state = "ld_rs1";
		if (cpu_state == cpu_state_ld_rs2)
			dbg_ascii_state = "ld_rs2";
		if (cpu_state == cpu_state_exec)
			dbg_ascii_state = "exec";
		if (cpu_state == cpu_state_shift)
			dbg_ascii_state = "shift";
		if (cpu_state == cpu_state_stmem)
			dbg_ascii_state = "stmem";
		if (cpu_state == cpu_state_ldmem)
			dbg_ascii_state = "ldmem";
	end
	reg set_mem_do_rinst;
	reg set_mem_do_rdata;
	reg set_mem_do_wdata;
	reg latched_store;
	reg latched_stalu;
	reg latched_branch;
	reg latched_compr;
	reg latched_trace;
	reg latched_is_lu;
	reg latched_is_lh;
	reg latched_is_lb;
	reg [regindex_bits - 1:0] latched_rd;
	reg [31:0] current_pc;
	assign next_pc = (latched_store && latched_branch ? reg_out & ~1 : reg_next_pc);
	reg [3:0] pcpi_timeout_counter;
	reg pcpi_timeout;
	reg [31:0] next_irq_pending;
	reg do_waitirq;
	reg [31:0] alu_out;
	reg [31:0] alu_out_q;
	reg alu_out_0;
	reg alu_out_0_q;
	reg alu_wait;
	reg alu_wait_2;
	reg [31:0] alu_add_sub;
	reg [31:0] alu_shl;
	reg [31:0] alu_shr;
	reg alu_eq;
	reg alu_ltu;
	reg alu_lts;
	generate
		if (TWO_CYCLE_ALU) begin : genblk3
			always @(posedge clk) begin
				alu_add_sub <= (instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2);
				alu_eq <= reg_op1 == reg_op2;
				alu_lts <= $signed(reg_op1) < $signed(reg_op2);
				alu_ltu <= reg_op1 < reg_op2;
				alu_shl <= reg_op1 << reg_op2[4:0];
				alu_shr <= $signed({(instr_sra || instr_srai ? reg_op1[31] : 1'b0), reg_op1}) >>> reg_op2[4:0];
			end
		end
		else begin : genblk3
			always @(*) begin
				alu_add_sub = (instr_sub ? reg_op1 - reg_op2 : reg_op1 + reg_op2);
				alu_eq = reg_op1 == reg_op2;
				alu_lts = $signed(reg_op1) < $signed(reg_op2);
				alu_ltu = reg_op1 < reg_op2;
				alu_shl = reg_op1 << reg_op2[4:0];
				alu_shr = $signed({(instr_sra || instr_srai ? reg_op1[31] : 1'b0), reg_op1}) >>> reg_op2[4:0];
			end
		end
	endgenerate
	always @(*) begin
		alu_out_0 = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			instr_beq: alu_out_0 = alu_eq;
			instr_bne: alu_out_0 = !alu_eq;
			instr_bge: alu_out_0 = !alu_lts;
			instr_bgeu: alu_out_0 = !alu_ltu;
			is_slti_blt_slt && (!TWO_CYCLE_COMPARE || !{instr_beq, instr_bne, instr_bge, instr_bgeu}): alu_out_0 = alu_lts;
			is_sltiu_bltu_sltu && (!TWO_CYCLE_COMPARE || !{instr_beq, instr_bne, instr_bge, instr_bgeu}): alu_out_0 = alu_ltu;
		endcase
		alu_out = 'bx;
		(* parallel_case, full_case *)
		case (1'b1)
			is_lui_auipc_jal_jalr_addi_add_sub: alu_out = alu_add_sub;
			is_compare: alu_out = alu_out_0;
			instr_xori || instr_xor: alu_out = reg_op1 ^ reg_op2;
			instr_ori || instr_or: alu_out = reg_op1 | reg_op2;
			instr_andi || instr_and: alu_out = reg_op1 & reg_op2;
			BARREL_SHIFTER && (instr_sll || instr_slli): alu_out = alu_shl;
			BARREL_SHIFTER && (((instr_srl || instr_srli) || instr_sra) || instr_srai): alu_out = alu_shr;
		endcase
	end
	reg clear_prefetched_high_word_q;
	always @(posedge clk) clear_prefetched_high_word_q <= clear_prefetched_high_word;
	always @(*) begin
		clear_prefetched_high_word = clear_prefetched_high_word_q;
		if (!prefetched_high_word)
			clear_prefetched_high_word = 0;
		if ((latched_branch || irq_state) || !resetn)
			clear_prefetched_high_word = COMPRESSED_ISA;
	end
	reg cpuregs_write;
	reg [31:0] cpuregs_wrdata;
	reg [31:0] cpuregs_rs1;
	reg [31:0] cpuregs_rs2;
	reg [regindex_bits - 1:0] decoded_rs;
	always @(*) begin
		cpuregs_write = 0;
		cpuregs_wrdata = 'bx;
		if (cpu_state == cpu_state_fetch)
			(* parallel_case *)
			case (1'b1)
				latched_branch: begin
					cpuregs_wrdata = reg_pc + (latched_compr ? 2 : 4);
					cpuregs_write = 1;
				end
				latched_store && !latched_branch: begin
					cpuregs_wrdata = (latched_stalu ? alu_out_q : reg_out);
					cpuregs_write = 1;
				end
				ENABLE_IRQ && irq_state[0]: begin
					cpuregs_wrdata = reg_next_pc | latched_compr;
					cpuregs_write = 1;
				end
				ENABLE_IRQ && irq_state[1]: begin
					cpuregs_wrdata = irq_pending & ~irq_mask;
					cpuregs_write = 1;
				end
			endcase
	end
	always @(posedge clk)
		if ((resetn && cpuregs_write) && latched_rd)
			cpuregs[latched_rd] <= cpuregs_wrdata;
	always @(*) begin
		decoded_rs = 'bx;
		if (ENABLE_REGS_DUALPORT) begin
			cpuregs_rs1 = (decoded_rs1 ? cpuregs[decoded_rs1] : 0);
			cpuregs_rs2 = (decoded_rs2 ? cpuregs[decoded_rs2] : 0);
		end
		else begin
			decoded_rs = (cpu_state == cpu_state_ld_rs2 ? decoded_rs2 : decoded_rs1);
			cpuregs_rs1 = (decoded_rs ? cpuregs[decoded_rs] : 0);
			cpuregs_rs2 = cpuregs_rs1;
		end
	end
	assign launch_next_insn = ((cpu_state == cpu_state_fetch) && decoder_trigger) && (((!ENABLE_IRQ || irq_delay) || irq_active) || !(irq_pending & ~irq_mask));
	always @(posedge clk) begin
		trap <= 0;
		reg_sh <= 'bx;
		reg_out <= 'bx;
		set_mem_do_rinst = 0;
		set_mem_do_rdata = 0;
		set_mem_do_wdata = 0;
		alu_out_0_q <= alu_out_0;
		alu_out_q <= alu_out;
		alu_wait <= 0;
		alu_wait_2 <= 0;
		if (launch_next_insn) begin
			dbg_rs1val <= 'bx;
			dbg_rs2val <= 'bx;
			dbg_rs1val_valid <= 0;
			dbg_rs2val_valid <= 0;
		end
		if (WITH_PCPI && CATCH_ILLINSN) begin
			if ((resetn && pcpi_valid) && !pcpi_int_wait) begin
				if (pcpi_timeout_counter)
					pcpi_timeout_counter <= pcpi_timeout_counter - 1;
			end
			else
				pcpi_timeout_counter <= ~0;
			pcpi_timeout <= !pcpi_timeout_counter;
		end
		if (ENABLE_COUNTERS) begin
			count_cycle <= (resetn ? count_cycle + 1 : 0);
			if (!ENABLE_COUNTERS64)
				count_cycle[63:32] <= 0;
		end
		else begin
			count_cycle <= 'bx;
			count_instr <= 'bx;
		end
		next_irq_pending = (ENABLE_IRQ ? irq_pending & LATCHED_IRQ : 'bx);
		if ((ENABLE_IRQ && ENABLE_IRQ_TIMER) && timer)
			timer <= timer - 1;
		decoder_trigger <= mem_do_rinst && mem_done;
		decoder_trigger_q <= decoder_trigger;
		decoder_pseudo_trigger <= 0;
		decoder_pseudo_trigger_q <= decoder_pseudo_trigger;
		do_waitirq <= 0;
		trace_valid <= 0;
		if (!ENABLE_TRACE)
			trace_data <= 'bx;
		if (!resetn) begin
			reg_pc <= PROGADDR_RESET;
			reg_next_pc <= PROGADDR_RESET;
			if (ENABLE_COUNTERS)
				count_instr <= 0;
			latched_store <= 0;
			latched_stalu <= 0;
			latched_branch <= 0;
			latched_trace <= 0;
			latched_is_lu <= 0;
			latched_is_lh <= 0;
			latched_is_lb <= 0;
			pcpi_valid <= 0;
			pcpi_timeout <= 0;
			irq_active <= 0;
			irq_delay <= 0;
			irq_mask <= ~0;
			next_irq_pending = 0;
			irq_state <= 0;
			eoi <= 0;
			timer <= 0;
			if (~STACKADDR) begin
				latched_store <= 1;
				latched_rd <= 2;
				reg_out <= STACKADDR;
			end
			cpu_state <= cpu_state_fetch;
		end
		else
			(* parallel_case, full_case *)
			case (cpu_state)
				cpu_state_trap: trap <= 1;
				cpu_state_fetch: begin
					mem_do_rinst <= !decoder_trigger && !do_waitirq;
					mem_wordsize <= 0;
					current_pc = reg_next_pc;
					(* parallel_case *)
					case (1'b1)
						latched_branch: current_pc = (latched_store ? (latched_stalu ? alu_out_q : reg_out) & ~1 : reg_next_pc);
						latched_store && !latched_branch:
							;
						ENABLE_IRQ && irq_state[0]: begin
							current_pc = PROGADDR_IRQ;
							irq_active <= 1;
							mem_do_rinst <= 1;
						end
						ENABLE_IRQ && irq_state[1]: begin
							eoi <= irq_pending & ~irq_mask;
							next_irq_pending = next_irq_pending & irq_mask;
						end
					endcase
					if (ENABLE_TRACE && latched_trace) begin
						latched_trace <= 0;
						trace_valid <= 1;
						if (latched_branch)
							trace_data <= ((irq_active ? TRACE_IRQ : 0) | TRACE_BRANCH) | (current_pc & 32'hfffffffe);
						else
							trace_data <= (irq_active ? TRACE_IRQ : 0) | (latched_stalu ? alu_out_q : reg_out);
					end
					reg_pc <= current_pc;
					reg_next_pc <= current_pc;
					latched_store <= 0;
					latched_stalu <= 0;
					latched_branch <= 0;
					latched_is_lu <= 0;
					latched_is_lh <= 0;
					latched_is_lb <= 0;
					latched_rd <= decoded_rd;
					latched_compr <= compressed_instr;
					if (ENABLE_IRQ && ((((decoder_trigger && !irq_active) && !irq_delay) && |(irq_pending & ~irq_mask)) || irq_state)) begin
						irq_state <= (irq_state == 2'b00 ? 2'b01 : (irq_state == 2'b01 ? 2'b10 : 2'b00));
						latched_compr <= latched_compr;
						if (ENABLE_IRQ_QREGS)
							latched_rd <= irqregs_offset | irq_state[0];
						else
							latched_rd <= (irq_state[0] ? 4 : 3);
					end
					else if ((ENABLE_IRQ && (decoder_trigger || do_waitirq)) && instr_waitirq) begin
						if (irq_pending) begin
							latched_store <= 1;
							reg_out <= irq_pending;
							reg_next_pc <= current_pc + (compressed_instr ? 2 : 4);
							mem_do_rinst <= 1;
						end
						else
							do_waitirq <= 1;
					end
					else if (decoder_trigger) begin
						irq_delay <= irq_active;
						reg_next_pc <= current_pc + (compressed_instr ? 2 : 4);
						if (ENABLE_TRACE)
							latched_trace <= 1;
						if (ENABLE_COUNTERS) begin
							count_instr <= count_instr + 1;
							if (!ENABLE_COUNTERS64)
								count_instr[63:32] <= 0;
						end
						if (instr_jal) begin
							mem_do_rinst <= 1;
							reg_next_pc <= current_pc + decoded_imm_j;
							latched_branch <= 1;
						end
						else begin
							mem_do_rinst <= 0;
							mem_do_prefetch <= !instr_jalr && !instr_retirq;
							cpu_state <= cpu_state_ld_rs1;
						end
					end
				end
				cpu_state_ld_rs1: begin
					reg_op1 <= 'bx;
					reg_op2 <= 'bx;
					(* parallel_case *)
					case (1'b1)
						(CATCH_ILLINSN || WITH_PCPI) && instr_trap:
							if (WITH_PCPI) begin
								reg_op1 <= cpuregs_rs1;
								dbg_rs1val <= cpuregs_rs1;
								dbg_rs1val_valid <= 1;
								if (ENABLE_REGS_DUALPORT) begin
									pcpi_valid <= 1;
									reg_sh <= cpuregs_rs2;
									reg_op2 <= cpuregs_rs2;
									dbg_rs2val <= cpuregs_rs2;
									dbg_rs2val_valid <= 1;
									if (pcpi_int_ready) begin
										mem_do_rinst <= 1;
										pcpi_valid <= 0;
										reg_out <= pcpi_int_rd;
										latched_store <= pcpi_int_wr;
										cpu_state <= cpu_state_fetch;
									end
									else if (CATCH_ILLINSN && (pcpi_timeout || instr_ecall_ebreak)) begin
										pcpi_valid <= 0;
										if ((ENABLE_IRQ && !irq_mask[irq_ebreak]) && !irq_active) begin
											next_irq_pending[irq_ebreak] = 1;
											cpu_state <= cpu_state_fetch;
										end
										else
											cpu_state <= cpu_state_trap;
									end
								end
								else
									cpu_state <= cpu_state_ld_rs2;
							end
							else if ((ENABLE_IRQ && !irq_mask[irq_ebreak]) && !irq_active) begin
								next_irq_pending[irq_ebreak] = 1;
								cpu_state <= cpu_state_fetch;
							end
							else
								cpu_state <= cpu_state_trap;
						ENABLE_COUNTERS && is_rdcycle_rdcycleh_rdinstr_rdinstrh: begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_rdcycle: reg_out <= count_cycle[31:0];
								instr_rdcycleh && ENABLE_COUNTERS64: reg_out <= count_cycle[63:32];
								instr_rdinstr: reg_out <= count_instr[31:0];
								instr_rdinstrh && ENABLE_COUNTERS64: reg_out <= count_instr[63:32];
							endcase
							latched_store <= 1;
							cpu_state <= cpu_state_fetch;
						end
						is_lui_auipc_jal: begin
							reg_op1 <= (instr_lui ? 0 : reg_pc);
							reg_op2 <= decoded_imm;
							if (TWO_CYCLE_ALU)
								alu_wait <= 1;
							else
								mem_do_rinst <= mem_do_prefetch;
							cpu_state <= cpu_state_exec;
						end
						(ENABLE_IRQ && ENABLE_IRQ_QREGS) && instr_getq: begin
							reg_out <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							latched_store <= 1;
							cpu_state <= cpu_state_fetch;
						end
						(ENABLE_IRQ && ENABLE_IRQ_QREGS) && instr_setq: begin
							reg_out <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							latched_rd <= latched_rd | irqregs_offset;
							latched_store <= 1;
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && instr_retirq: begin
							eoi <= 0;
							irq_active <= 0;
							latched_branch <= 1;
							latched_store <= 1;
							reg_out <= (CATCH_MISALIGN ? cpuregs_rs1 & 32'hfffffffe : cpuregs_rs1);
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							cpu_state <= cpu_state_fetch;
						end
						ENABLE_IRQ && instr_maskirq: begin
							latched_store <= 1;
							reg_out <= irq_mask;
							irq_mask <= cpuregs_rs1 | MASKED_IRQ;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							cpu_state <= cpu_state_fetch;
						end
						(ENABLE_IRQ && ENABLE_IRQ_TIMER) && instr_timer: begin
							latched_store <= 1;
							reg_out <= timer;
							timer <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							cpu_state <= cpu_state_fetch;
						end
						is_lb_lh_lw_lbu_lhu && !instr_trap: begin
							reg_op1 <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							cpu_state <= cpu_state_ldmem;
							mem_do_rinst <= 1;
						end
						is_slli_srli_srai && !BARREL_SHIFTER: begin
							reg_op1 <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							reg_sh <= decoded_rs2;
							cpu_state <= cpu_state_shift;
						end
						is_jalr_addi_slti_sltiu_xori_ori_andi, is_slli_srli_srai && BARREL_SHIFTER: begin
							reg_op1 <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							reg_op2 <= (is_slli_srli_srai && BARREL_SHIFTER ? decoded_rs2 : decoded_imm);
							if (TWO_CYCLE_ALU)
								alu_wait <= 1;
							else
								mem_do_rinst <= mem_do_prefetch;
							cpu_state <= cpu_state_exec;
						end
						default: begin
							reg_op1 <= cpuregs_rs1;
							dbg_rs1val <= cpuregs_rs1;
							dbg_rs1val_valid <= 1;
							if (ENABLE_REGS_DUALPORT) begin
								reg_sh <= cpuregs_rs2;
								reg_op2 <= cpuregs_rs2;
								dbg_rs2val <= cpuregs_rs2;
								dbg_rs2val_valid <= 1;
								(* parallel_case *)
								case (1'b1)
									is_sb_sh_sw: begin
										cpu_state <= cpu_state_stmem;
										mem_do_rinst <= 1;
									end
									is_sll_srl_sra && !BARREL_SHIFTER: cpu_state <= cpu_state_shift;
									default: begin
										if (TWO_CYCLE_ALU || (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu)) begin
											alu_wait_2 <= TWO_CYCLE_ALU && (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu);
											alu_wait <= 1;
										end
										else
											mem_do_rinst <= mem_do_prefetch;
										cpu_state <= cpu_state_exec;
									end
								endcase
							end
							else
								cpu_state <= cpu_state_ld_rs2;
						end
					endcase
				end
				cpu_state_ld_rs2: begin
					reg_sh <= cpuregs_rs2;
					reg_op2 <= cpuregs_rs2;
					dbg_rs2val <= cpuregs_rs2;
					dbg_rs2val_valid <= 1;
					(* parallel_case *)
					case (1'b1)
						WITH_PCPI && instr_trap: begin
							pcpi_valid <= 1;
							if (pcpi_int_ready) begin
								mem_do_rinst <= 1;
								pcpi_valid <= 0;
								reg_out <= pcpi_int_rd;
								latched_store <= pcpi_int_wr;
								cpu_state <= cpu_state_fetch;
							end
							else if (CATCH_ILLINSN && (pcpi_timeout || instr_ecall_ebreak)) begin
								pcpi_valid <= 0;
								if ((ENABLE_IRQ && !irq_mask[irq_ebreak]) && !irq_active) begin
									next_irq_pending[irq_ebreak] = 1;
									cpu_state <= cpu_state_fetch;
								end
								else
									cpu_state <= cpu_state_trap;
							end
						end
						is_sb_sh_sw: begin
							cpu_state <= cpu_state_stmem;
							mem_do_rinst <= 1;
						end
						is_sll_srl_sra && !BARREL_SHIFTER: cpu_state <= cpu_state_shift;
						default: begin
							if (TWO_CYCLE_ALU || (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu)) begin
								alu_wait_2 <= TWO_CYCLE_ALU && (TWO_CYCLE_COMPARE && is_beq_bne_blt_bge_bltu_bgeu);
								alu_wait <= 1;
							end
							else
								mem_do_rinst <= mem_do_prefetch;
							cpu_state <= cpu_state_exec;
						end
					endcase
				end
				cpu_state_exec: begin
					reg_out <= reg_pc + decoded_imm;
					if ((TWO_CYCLE_ALU || TWO_CYCLE_COMPARE) && (alu_wait || alu_wait_2)) begin
						mem_do_rinst <= mem_do_prefetch && !alu_wait_2;
						alu_wait <= alu_wait_2;
					end
					else if (is_beq_bne_blt_bge_bltu_bgeu) begin
						latched_rd <= 0;
						latched_store <= (TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0);
						latched_branch <= (TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0);
						if (mem_done)
							cpu_state <= cpu_state_fetch;
						if ((TWO_CYCLE_COMPARE ? alu_out_0_q : alu_out_0)) begin
							decoder_trigger <= 0;
							set_mem_do_rinst = 1;
						end
					end
					else begin
						latched_branch <= instr_jalr;
						latched_store <= 1;
						latched_stalu <= 1;
						cpu_state <= cpu_state_fetch;
					end
				end
				cpu_state_shift: begin
					latched_store <= 1;
					if (reg_sh == 0) begin
						reg_out <= reg_op1;
						mem_do_rinst <= mem_do_prefetch;
						cpu_state <= cpu_state_fetch;
					end
					else if (TWO_STAGE_SHIFT && (reg_sh >= 4)) begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_slli || instr_sll: reg_op1 <= reg_op1 << 4;
							instr_srli || instr_srl: reg_op1 <= reg_op1 >> 4;
							instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 4;
						endcase
						reg_sh <= reg_sh - 4;
					end
					else begin
						(* parallel_case, full_case *)
						case (1'b1)
							instr_slli || instr_sll: reg_op1 <= reg_op1 << 1;
							instr_srli || instr_srl: reg_op1 <= reg_op1 >> 1;
							instr_srai || instr_sra: reg_op1 <= $signed(reg_op1) >>> 1;
						endcase
						reg_sh <= reg_sh - 1;
					end
				end
				cpu_state_stmem: begin
					if (ENABLE_TRACE)
						reg_out <= reg_op2;
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_wdata) begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_sb: mem_wordsize <= 2;
								instr_sh: mem_wordsize <= 1;
								instr_sw: mem_wordsize <= 0;
							endcase
							if (ENABLE_TRACE) begin
								trace_valid <= 1;
								trace_data <= ((irq_active ? TRACE_IRQ : 0) | TRACE_ADDR) | ((reg_op1 + decoded_imm) & 32'hffffffff);
							end
							reg_op1 <= reg_op1 + decoded_imm;
							set_mem_do_wdata = 1;
						end
						if (!mem_do_prefetch && mem_done) begin
							cpu_state <= cpu_state_fetch;
							decoder_trigger <= 1;
							decoder_pseudo_trigger <= 1;
						end
					end
				end
				cpu_state_ldmem: begin
					latched_store <= 1;
					if (!mem_do_prefetch || mem_done) begin
						if (!mem_do_rdata) begin
							(* parallel_case, full_case *)
							case (1'b1)
								instr_lb || instr_lbu: mem_wordsize <= 2;
								instr_lh || instr_lhu: mem_wordsize <= 1;
								instr_lw: mem_wordsize <= 0;
							endcase
							latched_is_lu <= is_lbu_lhu_lw;
							latched_is_lh <= instr_lh;
							latched_is_lb <= instr_lb;
							if (ENABLE_TRACE) begin
								trace_valid <= 1;
								trace_data <= ((irq_active ? TRACE_IRQ : 0) | TRACE_ADDR) | ((reg_op1 + decoded_imm) & 32'hffffffff);
							end
							reg_op1 <= reg_op1 + decoded_imm;
							set_mem_do_rdata = 1;
						end
						if (!mem_do_prefetch && mem_done) begin
							(* parallel_case, full_case *)
							case (1'b1)
								latched_is_lu: reg_out <= mem_rdata_word;
								latched_is_lh: reg_out <= $signed(mem_rdata_word[15:0]);
								latched_is_lb: reg_out <= $signed(mem_rdata_word[7:0]);
							endcase
							decoder_trigger <= 1;
							decoder_pseudo_trigger <= 1;
							cpu_state <= cpu_state_fetch;
						end
					end
				end
			endcase
		if (ENABLE_IRQ) begin
			next_irq_pending = next_irq_pending | irq;
			if (ENABLE_IRQ_TIMER && timer) begin
				if ((timer - 1) == 0)
					next_irq_pending[irq_timer] = 1;
			end
		end
		if ((CATCH_MISALIGN && resetn) && (mem_do_rdata || mem_do_wdata)) begin
			if ((mem_wordsize == 0) && (reg_op1[1:0] != 0)) begin
				if ((ENABLE_IRQ && !irq_mask[irq_buserror]) && !irq_active)
					next_irq_pending[irq_buserror] = 1;
				else
					cpu_state <= cpu_state_trap;
			end
			if ((mem_wordsize == 1) && (reg_op1[0] != 0)) begin
				if ((ENABLE_IRQ && !irq_mask[irq_buserror]) && !irq_active)
					next_irq_pending[irq_buserror] = 1;
				else
					cpu_state <= cpu_state_trap;
			end
		end
		if (((CATCH_MISALIGN && resetn) && mem_do_rinst) && (COMPRESSED_ISA ? reg_pc[0] : |reg_pc[1:0])) begin
			if ((ENABLE_IRQ && !irq_mask[irq_buserror]) && !irq_active)
				next_irq_pending[irq_buserror] = 1;
			else
				cpu_state <= cpu_state_trap;
		end
		if (((!CATCH_ILLINSN && decoder_trigger_q) && !decoder_pseudo_trigger_q) && instr_ecall_ebreak)
			cpu_state <= cpu_state_trap;
		if (!resetn || mem_done) begin
			mem_do_prefetch <= 0;
			mem_do_rinst <= 0;
			mem_do_rdata <= 0;
			mem_do_wdata <= 0;
		end
		if (set_mem_do_rinst)
			mem_do_rinst <= 1;
		if (set_mem_do_rdata)
			mem_do_rdata <= 1;
		if (set_mem_do_wdata)
			mem_do_wdata <= 1;
		irq_pending <= next_irq_pending & ~MASKED_IRQ;
		if (!CATCH_MISALIGN) begin
			if (COMPRESSED_ISA) begin
				reg_pc[0] <= 0;
				reg_next_pc[0] <= 0;
			end
			else begin
				reg_pc[1:0] <= 0;
				reg_next_pc[1:0] <= 0;
			end
		end
		current_pc = 'bx;
	end
endmodule
module picorv32_regs (
	clk,
	wen,
	waddr,
	raddr1,
	raddr2,
	wdata,
	rdata1,
	rdata2
);
	input clk;
	input wen;
	input [5:0] waddr;
	input [5:0] raddr1;
	input [5:0] raddr2;
	input [31:0] wdata;
	output wire [31:0] rdata1;
	output wire [31:0] rdata2;
	reg [31:0] regs [0:30];
	always @(posedge clk)
		if (wen)
			regs[~waddr[4:0]] <= wdata;
	assign rdata1 = regs[~raddr1[4:0]];
	assign rdata2 = regs[~raddr2[4:0]];
endmodule
module picorv32_pcpi_mul (
	clk,
	resetn,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready
);
	parameter STEPS_AT_ONCE = 1;
	parameter CARRY_CHAIN = 4;
	input clk;
	input resetn;
	input pcpi_valid;
	input [31:0] pcpi_insn;
	input [31:0] pcpi_rs1;
	input [31:0] pcpi_rs2;
	output reg pcpi_wr;
	output reg [31:0] pcpi_rd;
	output reg pcpi_wait;
	output reg pcpi_ready;
	reg instr_mul;
	reg instr_mulh;
	reg instr_mulhsu;
	reg instr_mulhu;
	wire instr_any_mul = |{instr_mul, instr_mulh, instr_mulhsu, instr_mulhu};
	wire instr_any_mulh = |{instr_mulh, instr_mulhsu, instr_mulhu};
	wire instr_rs1_signed = |{instr_mulh, instr_mulhsu};
	wire instr_rs2_signed = |{instr_mulh};
	reg pcpi_wait_q;
	wire mul_start = pcpi_wait && !pcpi_wait_q;
	always @(posedge clk) begin
		instr_mul <= 0;
		instr_mulh <= 0;
		instr_mulhsu <= 0;
		instr_mulhu <= 0;
		if (((resetn && pcpi_valid) && (pcpi_insn[6:0] == 7'b0110011)) && (pcpi_insn[31:25] == 7'b0000001))
			case (pcpi_insn[14:12])
				3'b000: instr_mul <= 1;
				3'b001: instr_mulh <= 1;
				3'b010: instr_mulhsu <= 1;
				3'b011: instr_mulhu <= 1;
			endcase
		pcpi_wait <= instr_any_mul;
		pcpi_wait_q <= pcpi_wait;
	end
	reg [63:0] rs1;
	reg [63:0] rs2;
	reg [63:0] rd;
	reg [63:0] rdx;
	reg [63:0] next_rs1;
	reg [63:0] next_rs2;
	reg [63:0] this_rs2;
	reg [63:0] next_rd;
	reg [63:0] next_rdx;
	reg [63:0] next_rdt;
	reg [6:0] mul_counter;
	reg mul_waiting;
	reg mul_finish;
	integer i;
	integer j;
	always @(*) begin
		next_rd = rd;
		next_rdx = rdx;
		next_rs1 = rs1;
		next_rs2 = rs2;
		for (i = 0; i < STEPS_AT_ONCE; i = i + 1)
			begin
				this_rs2 = (next_rs1[0] ? next_rs2 : 0);
				if (CARRY_CHAIN == 0) begin
					next_rdt = (next_rd ^ next_rdx) ^ this_rs2;
					next_rdx = (((next_rd & next_rdx) | (next_rd & this_rs2)) | (next_rdx & this_rs2)) << 1;
					next_rd = next_rdt;
				end
				else begin
					next_rdt = 0;
					for (j = 0; j < 64; j = j + CARRY_CHAIN)
						{next_rdt[(j + CARRY_CHAIN) - 1], next_rd[j+:CARRY_CHAIN]} = (next_rd[j+:CARRY_CHAIN] + next_rdx[j+:CARRY_CHAIN]) + this_rs2[j+:CARRY_CHAIN];
					next_rdx = next_rdt << 1;
				end
				next_rs1 = next_rs1 >> 1;
				next_rs2 = next_rs2 << 1;
			end
	end
	always @(posedge clk) begin
		mul_finish <= 0;
		if (!resetn)
			mul_waiting <= 1;
		else if (mul_waiting) begin
			if (instr_rs1_signed)
				rs1 <= $signed(pcpi_rs1);
			else
				rs1 <= $unsigned(pcpi_rs1);
			if (instr_rs2_signed)
				rs2 <= $signed(pcpi_rs2);
			else
				rs2 <= $unsigned(pcpi_rs2);
			rd <= 0;
			rdx <= 0;
			mul_counter <= (instr_any_mulh ? 63 - STEPS_AT_ONCE : 31 - STEPS_AT_ONCE);
			mul_waiting <= !mul_start;
		end
		else begin
			rd <= next_rd;
			rdx <= next_rdx;
			rs1 <= next_rs1;
			rs2 <= next_rs2;
			mul_counter <= mul_counter - STEPS_AT_ONCE;
			if (mul_counter[6]) begin
				mul_finish <= 1;
				mul_waiting <= 1;
			end
		end
	end
	always @(posedge clk) begin
		pcpi_wr <= 0;
		pcpi_ready <= 0;
		if (mul_finish && resetn) begin
			pcpi_wr <= 1;
			pcpi_ready <= 1;
			pcpi_rd <= (instr_any_mulh ? rd >> 32 : rd);
		end
	end
endmodule
module picorv32_pcpi_fast_mul (
	clk,
	resetn,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready
);
	parameter EXTRA_MUL_FFS = 0;
	parameter EXTRA_INSN_FFS = 0;
	parameter MUL_CLKGATE = 0;
	input clk;
	input resetn;
	input pcpi_valid;
	input [31:0] pcpi_insn;
	input [31:0] pcpi_rs1;
	input [31:0] pcpi_rs2;
	output wire pcpi_wr;
	output wire [31:0] pcpi_rd;
	output wire pcpi_wait;
	output wire pcpi_ready;
	reg instr_mul;
	reg instr_mulh;
	reg instr_mulhsu;
	reg instr_mulhu;
	wire instr_any_mul = |{instr_mul, instr_mulh, instr_mulhsu, instr_mulhu};
	wire instr_any_mulh = |{instr_mulh, instr_mulhsu, instr_mulhu};
	wire instr_rs1_signed = |{instr_mulh, instr_mulhsu};
	wire instr_rs2_signed = |{instr_mulh};
	reg shift_out;
	reg [3:0] active;
	reg [32:0] rs1;
	reg [32:0] rs2;
	reg [32:0] rs1_q;
	reg [32:0] rs2_q;
	reg [63:0] rd;
	reg [63:0] rd_q;
	wire pcpi_insn_valid = (pcpi_valid && (pcpi_insn[6:0] == 7'b0110011)) && (pcpi_insn[31:25] == 7'b0000001);
	reg pcpi_insn_valid_q;
	always @(*) begin
		instr_mul = 0;
		instr_mulh = 0;
		instr_mulhsu = 0;
		instr_mulhu = 0;
		if (resetn && (EXTRA_INSN_FFS ? pcpi_insn_valid_q : pcpi_insn_valid))
			case (pcpi_insn[14:12])
				3'b000: instr_mul = 1;
				3'b001: instr_mulh = 1;
				3'b010: instr_mulhsu = 1;
				3'b011: instr_mulhu = 1;
			endcase
	end
	always @(posedge clk) begin
		pcpi_insn_valid_q <= pcpi_insn_valid;
		if (!MUL_CLKGATE || active[0]) begin
			rs1_q <= rs1;
			rs2_q <= rs2;
		end
		if (!MUL_CLKGATE || active[1])
			rd <= $signed((EXTRA_MUL_FFS ? rs1_q : rs1)) * $signed((EXTRA_MUL_FFS ? rs2_q : rs2));
		if (!MUL_CLKGATE || active[2])
			rd_q <= rd;
	end
	always @(posedge clk) begin
		if (instr_any_mul && !(EXTRA_MUL_FFS ? active[3:0] : active[1:0])) begin
			if (instr_rs1_signed)
				rs1 <= $signed(pcpi_rs1);
			else
				rs1 <= $unsigned(pcpi_rs1);
			if (instr_rs2_signed)
				rs2 <= $signed(pcpi_rs2);
			else
				rs2 <= $unsigned(pcpi_rs2);
			active[0] <= 1;
		end
		else
			active[0] <= 0;
		active[3:1] <= active;
		shift_out <= instr_any_mulh;
		if (!resetn)
			active <= 0;
	end
	assign pcpi_wr = active[(EXTRA_MUL_FFS ? 3 : 1)];
	assign pcpi_wait = 0;
	assign pcpi_ready = active[(EXTRA_MUL_FFS ? 3 : 1)];
	assign pcpi_rd = (shift_out ? (EXTRA_MUL_FFS ? rd_q : rd) >> 32 : (EXTRA_MUL_FFS ? rd_q : rd));
endmodule
module picorv32_pcpi_div (
	clk,
	resetn,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready
);
	input clk;
	input resetn;
	input pcpi_valid;
	input [31:0] pcpi_insn;
	input [31:0] pcpi_rs1;
	input [31:0] pcpi_rs2;
	output reg pcpi_wr;
	output reg [31:0] pcpi_rd;
	output reg pcpi_wait;
	output reg pcpi_ready;
	reg instr_div;
	reg instr_divu;
	reg instr_rem;
	reg instr_remu;
	wire instr_any_div_rem = |{instr_div, instr_divu, instr_rem, instr_remu};
	reg pcpi_wait_q;
	wire start = pcpi_wait && !pcpi_wait_q;
	always @(posedge clk) begin
		instr_div <= 0;
		instr_divu <= 0;
		instr_rem <= 0;
		instr_remu <= 0;
		if ((((resetn && pcpi_valid) && !pcpi_ready) && (pcpi_insn[6:0] == 7'b0110011)) && (pcpi_insn[31:25] == 7'b0000001))
			case (pcpi_insn[14:12])
				3'b100: instr_div <= 1;
				3'b101: instr_divu <= 1;
				3'b110: instr_rem <= 1;
				3'b111: instr_remu <= 1;
			endcase
		pcpi_wait <= instr_any_div_rem && resetn;
		pcpi_wait_q <= pcpi_wait && resetn;
	end
	reg [31:0] dividend;
	reg [62:0] divisor;
	reg [31:0] quotient;
	reg [31:0] quotient_msk;
	reg running;
	reg outsign;
	always @(posedge clk) begin
		pcpi_ready <= 0;
		pcpi_wr <= 0;
		pcpi_rd <= 'bx;
		if (!resetn)
			running <= 0;
		else if (start) begin
			running <= 1;
			dividend <= ((instr_div || instr_rem) && pcpi_rs1[31] ? -pcpi_rs1 : pcpi_rs1);
			divisor <= ((instr_div || instr_rem) && pcpi_rs2[31] ? -pcpi_rs2 : pcpi_rs2) << 31;
			outsign <= ((instr_div && (pcpi_rs1[31] != pcpi_rs2[31])) && |pcpi_rs2) || (instr_rem && pcpi_rs1[31]);
			quotient <= 0;
			quotient_msk <= 33'sd2147483648;
		end
		else if (!quotient_msk && running) begin
			running <= 0;
			pcpi_ready <= 1;
			pcpi_wr <= 1;
			if (instr_div || instr_divu)
				pcpi_rd <= (outsign ? -quotient : quotient);
			else
				pcpi_rd <= (outsign ? -dividend : dividend);
		end
		else begin
			if (divisor <= dividend) begin
				dividend <= dividend - divisor;
				quotient <= quotient | quotient_msk;
			end
			divisor <= divisor >> 1;
			quotient_msk <= quotient_msk >> 1;
		end
	end
endmodule
module picorv32_axi (
	clk,
	resetn,
	trap,
	mem_axi_awvalid,
	mem_axi_awready,
	mem_axi_awaddr,
	mem_axi_awprot,
	mem_axi_wvalid,
	mem_axi_wready,
	mem_axi_wdata,
	mem_axi_wstrb,
	mem_axi_bvalid,
	mem_axi_bready,
	mem_axi_arvalid,
	mem_axi_arready,
	mem_axi_araddr,
	mem_axi_arprot,
	mem_axi_rvalid,
	mem_axi_rready,
	mem_axi_rdata,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready,
	irq,
	eoi,
	trace_valid,
	trace_data
);
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_COUNTERS64 = 1;
	parameter [0:0] ENABLE_REGS_16_31 = 1;
	parameter [0:0] ENABLE_REGS_DUALPORT = 1;
	parameter [0:0] TWO_STAGE_SHIFT = 1;
	parameter [0:0] BARREL_SHIFTER = 0;
	parameter [0:0] TWO_CYCLE_COMPARE = 0;
	parameter [0:0] TWO_CYCLE_ALU = 0;
	parameter [0:0] COMPRESSED_ISA = 0;
	parameter [0:0] CATCH_MISALIGN = 1;
	parameter [0:0] CATCH_ILLINSN = 1;
	parameter [0:0] ENABLE_PCPI = 0;
	parameter [0:0] ENABLE_MUL = 0;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_DIV = 0;
	parameter [0:0] ENABLE_IRQ = 0;
	parameter [0:0] ENABLE_IRQ_QREGS = 1;
	parameter [0:0] ENABLE_IRQ_TIMER = 1;
	parameter [0:0] ENABLE_TRACE = 0;
	parameter [0:0] REGS_INIT_ZERO = 0;
	parameter [31:0] MASKED_IRQ = 32'h00000000;
	parameter [31:0] LATCHED_IRQ = 32'hffffffff;
	parameter [31:0] PROGADDR_RESET = 32'h00000000;
	parameter [31:0] PROGADDR_IRQ = 32'h00000010;
	parameter [31:0] STACKADDR = 32'hffffffff;
	input clk;
	input resetn;
	output wire trap;
	output wire mem_axi_awvalid;
	input mem_axi_awready;
	output wire [31:0] mem_axi_awaddr;
	output wire [2:0] mem_axi_awprot;
	output wire mem_axi_wvalid;
	input mem_axi_wready;
	output wire [31:0] mem_axi_wdata;
	output wire [3:0] mem_axi_wstrb;
	input mem_axi_bvalid;
	output wire mem_axi_bready;
	output wire mem_axi_arvalid;
	input mem_axi_arready;
	output wire [31:0] mem_axi_araddr;
	output wire [2:0] mem_axi_arprot;
	input mem_axi_rvalid;
	output wire mem_axi_rready;
	input [31:0] mem_axi_rdata;
	output wire pcpi_valid;
	output wire [31:0] pcpi_insn;
	output wire [31:0] pcpi_rs1;
	output wire [31:0] pcpi_rs2;
	input pcpi_wr;
	input [31:0] pcpi_rd;
	input pcpi_wait;
	input pcpi_ready;
	input [31:0] irq;
	output wire [31:0] eoi;
	output wire trace_valid;
	output wire [35:0] trace_data;
	wire mem_valid;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire mem_instr;
	wire mem_ready;
	wire [31:0] mem_rdata;
	picorv32_axi_adapter axi_adapter(
		.clk(clk),
		.resetn(resetn),
		.mem_axi_awvalid(mem_axi_awvalid),
		.mem_axi_awready(mem_axi_awready),
		.mem_axi_awaddr(mem_axi_awaddr),
		.mem_axi_awprot(mem_axi_awprot),
		.mem_axi_wvalid(mem_axi_wvalid),
		.mem_axi_wready(mem_axi_wready),
		.mem_axi_wdata(mem_axi_wdata),
		.mem_axi_wstrb(mem_axi_wstrb),
		.mem_axi_bvalid(mem_axi_bvalid),
		.mem_axi_bready(mem_axi_bready),
		.mem_axi_arvalid(mem_axi_arvalid),
		.mem_axi_arready(mem_axi_arready),
		.mem_axi_araddr(mem_axi_araddr),
		.mem_axi_arprot(mem_axi_arprot),
		.mem_axi_rvalid(mem_axi_rvalid),
		.mem_axi_rready(mem_axi_rready),
		.mem_axi_rdata(mem_axi_rdata),
		.mem_valid(mem_valid),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_rdata(mem_rdata)
	);
	picorv32 #(
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_COUNTERS64(ENABLE_COUNTERS64),
		.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
		.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
		.COMPRESSED_ISA(COMPRESSED_ISA),
		.CATCH_MISALIGN(CATCH_MISALIGN),
		.CATCH_ILLINSN(CATCH_ILLINSN),
		.ENABLE_PCPI(ENABLE_PCPI),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_IRQ(ENABLE_IRQ),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
		.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
		.ENABLE_TRACE(ENABLE_TRACE),
		.REGS_INIT_ZERO(REGS_INIT_ZERO),
		.MASKED_IRQ(MASKED_IRQ),
		.LATCHED_IRQ(LATCHED_IRQ),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.STACKADDR(STACKADDR)
	) picorv32_core(
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.mem_valid(mem_valid),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_rdata(mem_rdata),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready),
		.irq(irq),
		.eoi(eoi),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);
endmodule
module picorv32_axi_adapter (
	clk,
	resetn,
	mem_axi_awvalid,
	mem_axi_awready,
	mem_axi_awaddr,
	mem_axi_awprot,
	mem_axi_wvalid,
	mem_axi_wready,
	mem_axi_wdata,
	mem_axi_wstrb,
	mem_axi_bvalid,
	mem_axi_bready,
	mem_axi_arvalid,
	mem_axi_arready,
	mem_axi_araddr,
	mem_axi_arprot,
	mem_axi_rvalid,
	mem_axi_rready,
	mem_axi_rdata,
	mem_valid,
	mem_instr,
	mem_ready,
	mem_addr,
	mem_wdata,
	mem_wstrb,
	mem_rdata
);
	input clk;
	input resetn;
	output wire mem_axi_awvalid;
	input mem_axi_awready;
	output wire [31:0] mem_axi_awaddr;
	output wire [2:0] mem_axi_awprot;
	output wire mem_axi_wvalid;
	input mem_axi_wready;
	output wire [31:0] mem_axi_wdata;
	output wire [3:0] mem_axi_wstrb;
	input mem_axi_bvalid;
	output wire mem_axi_bready;
	output wire mem_axi_arvalid;
	input mem_axi_arready;
	output wire [31:0] mem_axi_araddr;
	output wire [2:0] mem_axi_arprot;
	input mem_axi_rvalid;
	output wire mem_axi_rready;
	input [31:0] mem_axi_rdata;
	input mem_valid;
	input mem_instr;
	output wire mem_ready;
	input [31:0] mem_addr;
	input [31:0] mem_wdata;
	input [3:0] mem_wstrb;
	output wire [31:0] mem_rdata;
	reg ack_awvalid;
	reg ack_arvalid;
	reg ack_wvalid;
	reg xfer_done;
	assign mem_axi_awvalid = (mem_valid && |mem_wstrb) && !ack_awvalid;
	assign mem_axi_awaddr = mem_addr;
	assign mem_axi_awprot = 0;
	assign mem_axi_arvalid = (mem_valid && !mem_wstrb) && !ack_arvalid;
	assign mem_axi_araddr = mem_addr;
	assign mem_axi_arprot = (mem_instr ? 3'b100 : 3'b000);
	assign mem_axi_wvalid = (mem_valid && |mem_wstrb) && !ack_wvalid;
	assign mem_axi_wdata = mem_wdata;
	assign mem_axi_wstrb = mem_wstrb;
	assign mem_ready = mem_axi_bvalid || mem_axi_rvalid;
	assign mem_axi_bready = mem_valid && |mem_wstrb;
	assign mem_axi_rready = mem_valid && !mem_wstrb;
	assign mem_rdata = mem_axi_rdata;
	always @(posedge clk)
		if (!resetn)
			ack_awvalid <= 0;
		else begin
			xfer_done <= mem_valid && mem_ready;
			if (mem_axi_awready && mem_axi_awvalid)
				ack_awvalid <= 1;
			if (mem_axi_arready && mem_axi_arvalid)
				ack_arvalid <= 1;
			if (mem_axi_wready && mem_axi_wvalid)
				ack_wvalid <= 1;
			if (xfer_done || !mem_valid) begin
				ack_awvalid <= 0;
				ack_arvalid <= 0;
				ack_wvalid <= 0;
			end
		end
endmodule
module picorv32_wb (
	trap,
	wb_rst_i,
	wb_clk_i,
	wbm_adr_o,
	wbm_dat_o,
	wbm_dat_i,
	wbm_we_o,
	wbm_sel_o,
	wbm_stb_o,
	wbm_ack_i,
	wbm_cyc_o,
	pcpi_valid,
	pcpi_insn,
	pcpi_rs1,
	pcpi_rs2,
	pcpi_wr,
	pcpi_rd,
	pcpi_wait,
	pcpi_ready,
	irq,
	eoi,
	trace_valid,
	trace_data,
	mem_instr
);
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_COUNTERS64 = 1;
	parameter [0:0] ENABLE_REGS_16_31 = 1;
	parameter [0:0] ENABLE_REGS_DUALPORT = 1;
	parameter [0:0] TWO_STAGE_SHIFT = 1;
	parameter [0:0] BARREL_SHIFTER = 0;
	parameter [0:0] TWO_CYCLE_COMPARE = 0;
	parameter [0:0] TWO_CYCLE_ALU = 0;
	parameter [0:0] COMPRESSED_ISA = 0;
	parameter [0:0] CATCH_MISALIGN = 1;
	parameter [0:0] CATCH_ILLINSN = 1;
	parameter [0:0] ENABLE_PCPI = 0;
	parameter [0:0] ENABLE_MUL = 0;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_DIV = 0;
	parameter [0:0] ENABLE_IRQ = 0;
	parameter [0:0] ENABLE_IRQ_QREGS = 1;
	parameter [0:0] ENABLE_IRQ_TIMER = 1;
	parameter [0:0] ENABLE_TRACE = 0;
	parameter [0:0] REGS_INIT_ZERO = 0;
	parameter [31:0] MASKED_IRQ = 32'h00000000;
	parameter [31:0] LATCHED_IRQ = 32'hffffffff;
	parameter [31:0] PROGADDR_RESET = 32'h00000000;
	parameter [31:0] PROGADDR_IRQ = 32'h00000010;
	parameter [31:0] STACKADDR = 32'hffffffff;
	output wire trap;
	input wb_rst_i;
	input wb_clk_i;
	output reg [31:0] wbm_adr_o;
	output reg [31:0] wbm_dat_o;
	input [31:0] wbm_dat_i;
	output reg wbm_we_o;
	output reg [3:0] wbm_sel_o;
	output reg wbm_stb_o;
	input wbm_ack_i;
	output reg wbm_cyc_o;
	output wire pcpi_valid;
	output wire [31:0] pcpi_insn;
	output wire [31:0] pcpi_rs1;
	output wire [31:0] pcpi_rs2;
	input pcpi_wr;
	input [31:0] pcpi_rd;
	input pcpi_wait;
	input pcpi_ready;
	input [31:0] irq;
	output wire [31:0] eoi;
	output wire trace_valid;
	output wire [35:0] trace_data;
	output wire mem_instr;
	wire mem_valid;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg mem_ready;
	reg [31:0] mem_rdata;
	wire clk;
	wire resetn;
	assign clk = wb_clk_i;
	assign resetn = ~wb_rst_i;
	picorv32 #(
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_COUNTERS64(ENABLE_COUNTERS64),
		.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
		.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
		.COMPRESSED_ISA(COMPRESSED_ISA),
		.CATCH_MISALIGN(CATCH_MISALIGN),
		.CATCH_ILLINSN(CATCH_ILLINSN),
		.ENABLE_PCPI(ENABLE_PCPI),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_IRQ(ENABLE_IRQ),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
		.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
		.ENABLE_TRACE(ENABLE_TRACE),
		.REGS_INIT_ZERO(REGS_INIT_ZERO),
		.MASKED_IRQ(MASKED_IRQ),
		.LATCHED_IRQ(LATCHED_IRQ),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.STACKADDR(STACKADDR)
	) picorv32_core(
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.mem_valid(mem_valid),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_rdata(mem_rdata),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready),
		.irq(irq),
		.eoi(eoi),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);
	localparam IDLE = 2'b00;
	localparam WBSTART = 2'b01;
	localparam WBEND = 2'b10;
	reg [1:0] state;
	wire we;
	assign we = ((mem_wstrb[0] | mem_wstrb[1]) | mem_wstrb[2]) | mem_wstrb[3];
	always @(posedge wb_clk_i)
		if (wb_rst_i) begin
			wbm_adr_o <= 0;
			wbm_dat_o <= 0;
			wbm_we_o <= 0;
			wbm_sel_o <= 0;
			wbm_stb_o <= 0;
			wbm_cyc_o <= 0;
			state <= IDLE;
		end
		else
			case (state)
				IDLE:
					if (mem_valid) begin
						wbm_adr_o <= mem_addr;
						wbm_dat_o <= mem_wdata;
						wbm_we_o <= we;
						wbm_sel_o <= mem_wstrb;
						wbm_stb_o <= 1'b1;
						wbm_cyc_o <= 1'b1;
						state <= WBSTART;
					end
					else begin
						mem_ready <= 1'b0;
						wbm_stb_o <= 1'b0;
						wbm_cyc_o <= 1'b0;
						wbm_we_o <= 1'b0;
					end
				WBSTART:
					if (wbm_ack_i) begin
						mem_rdata <= wbm_dat_i;
						mem_ready <= 1'b1;
						state <= WBEND;
						wbm_stb_o <= 1'b0;
						wbm_cyc_o <= 1'b0;
						wbm_we_o <= 1'b0;
					end
				WBEND: begin
					mem_ready <= 1'b0;
					state <= IDLE;
				end
				default: state <= IDLE;
			endcase
endmodule
