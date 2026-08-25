// ============================================================================
// chip_top_full.sv - Columbia-style: scan-configured clock-gating FSM +
// on-chip clock generator. 22-pin target (20 signal + 2 power).
// ============================================================================
module chip_top_full #(
    parameter int NUM_OUT     = 5,
    parameter int NUM_IN      = 2,
    parameter int CLK_FREQ    = 31_250_000,  // silicon: 32 ns clock = 31.25 MHz
    parameter int BAUD_RATE   = 115_200,     // BAUD_DIV = 271 -> 115,313 baud (+0.1%)
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

    logic [31:0] status_word;
    logic        scan_mem_we, scan_mem_re;
    logic [15:0] scan_mem_addr;
    logic [31:0] scan_mem_wdata, scan_mem_rdata;
    logic        fsm_cfg_load; logic [1:0] fsm_mode; logic [15:0] fsm_count;
    scan_chain u_scan (
        .clk(sys_clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_i0o1(scan_i0o1), .scan_out(scan_out),
        .mem_we(scan_mem_we), .mem_re(scan_mem_re), .mem_addr(scan_mem_addr),
        .mem_wdata(scan_mem_wdata), .mem_rdata(scan_mem_rdata),
        .status_in(status_word),
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
    // ---- PicoRV32 core + shim (replaces Ibex) ----
    // Pico needs clocked reset edges. cpu_clk is gated off until the FSM enters
    // RUN, so rst_n alone releases Pico before it ever sees a clock. Synchronize
    // a reset into the cpu_clk domain so Pico is held in reset until cpu_clk runs.
    logic pico_resetn;
    logic [1:0] pico_rst_sync;
    always_ff @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) pico_rst_sync <= 2'b00;
        else        pico_rst_sync <= {pico_rst_sync[0], 1'b1};
    end
    assign pico_resetn = pico_rst_sync[1];

    logic        p_mem_valid, p_mem_instr, p_mem_ready;
    logic [31:0] p_mem_addr, p_mem_wdata, p_mem_rdata;
    logic [3:0]  p_mem_wstrb;
    logic        p_trap;

    // ---- trap capture -------------------------------------------------------
    // PicoRV32 raises trap on an illegal instruction or misaligned access and
    // then halts. Software cannot report this (it is no longer running) and
    // there is no spare pin, so the trap is synchronised into the sys_clk
    // domain and latched. It is readable over the scan chain as bit 0 of the
    // status word (tgt=3, addr[13]=1). Sticky until reset.
    //
    // cpu_clk is a gated version of sys_clk, so p_trap can freeze mid-flight
    // when the FSM leaves RUN; the two-flop synchroniser makes sampling it from
    // sys_clk safe, and the sticky bit preserves the event after the clock stops.
    logic trap_sync1, trap_sync2, trap_sticky;
    always_ff @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            trap_sync1 <= 1'b0; trap_sync2 <= 1'b0; trap_sticky <= 1'b0;
        end else begin
            trap_sync1 <= p_trap;
            trap_sync2 <= trap_sync1;
            if (trap_sync2) trap_sticky <= 1'b1;
        end
    end

    // Status word, readable via scan (tgt=3, addr[13]=1):
    //   [0]    CPU trap (sticky since reset)
    //   [2:1]  FSM mode (0=IDLE, 1=RUN, 2=COUNTDOWN)
    //   [3]    scan owns memory
    //   [31:4] reserved, reads 0
    assign status_word = {28'b0, scan_owns_mem, fsm_mode_o, trap_sticky};

    picorv32 #(
        .ENABLE_MUL(1), .ENABLE_DIV(1), .COMPRESSED_ISA(1),
        .ENABLE_IRQ(0), .PROGADDR_RESET(32'h0), .STACKADDR(32'h200),
        .BARREL_SHIFTER(0), .ENABLE_FAST_MUL(0),
        .ENABLE_COUNTERS(0), .ENABLE_COUNTERS64(0)
    ) u_cpu (
        .clk(cpu_clk), .resetn(pico_resetn), .trap(p_trap),
        .mem_valid(p_mem_valid), .mem_instr(p_mem_instr), .mem_ready(p_mem_ready),
        .mem_addr(p_mem_addr), .mem_wdata(p_mem_wdata), .mem_wstrb(p_mem_wstrb),
        .mem_rdata(p_mem_rdata),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(),
        .mem_la_wdata(), .mem_la_wstrb(),
        .pcpi_valid(), .pcpi_insn(), .pcpi_rs1(), .pcpi_rs2(),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'b0), .eoi(), .trace_valid(), .trace_data()
    );

    pico_shim u_shim (
        .clk(cpu_clk), .rst_n(rst_n),
        .mem_valid(p_mem_valid), .mem_instr(p_mem_instr), .mem_ready(p_mem_ready),
        .mem_addr(p_mem_addr), .mem_wdata(p_mem_wdata), .mem_wstrb(p_mem_wstrb),
        .mem_rdata(p_mem_rdata),
        .instr_req(instr_req), .instr_gnt(instr_gnt), .instr_addr(instr_addr),
        .instr_rvalid(instr_rvalid), .instr_rdata(instr_rdata),
        .data_req(data_req), .data_gnt(data_gnt), .data_we(data_we), .data_be(data_be),
        .data_addr(data_addr), .data_wdata(data_wdata),
        .data_rvalid(data_rvalid), .data_rdata(data_rdata)
    );

    mem_subsystem u_mem (
        .clk(sys_clk), .rst_n_in(rst_n),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .scan_owns_mem(scan_owns_mem),
        .scan_we(scan_mem_we), .scan_addr(scan_mem_addr), .scan_wdata(scan_mem_wdata),
        .scan_re(scan_mem_re), .scan_rdata(scan_mem_rdata)
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
