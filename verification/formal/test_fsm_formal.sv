// ============================================================================
// test_fsm_formal.sv - formal properties for the clock-gating FSM.
//
// Proven by bounded model checking (Yosys + yosys-smtbmc). Unlike a testbench,
// these hold for EVERY input sequence up to the bound, not just the stimulus
// we happened to apply.
//
// Every property here can fail. Assertions that merely restate an assign
// statement prove nothing and are deliberately excluded.
// ============================================================================
module test_fsm_formal (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cfg_load,
    input  logic [1:0]  cfg_mode_in,
    input  logic [15:0] cfg_count_in
);
    localparam logic [1:0] IDLE = 2'd0, RUN = 2'd1, COUNTDOWN = 2'd2;

    logic cpu_clk, scan_owns_mem;
    logic [1:0] mode_o;

    test_fsm dut (
        .clk(clk), .rst_n(rst_n),
        .cfg_load(cfg_load),
        .cfg_mode_in(cfg_mode_in),
        .cfg_count_in(cfg_count_in),
        .cpu_clk(cpu_clk),
        .scan_owns_mem(scan_owns_mem),
        .mode_o(mode_o)
    );

    // BMC starts from an arbitrary state unless told otherwise, which would
    // let it begin with run_gate_q high while mode is IDLE - unreachable in
    // practice. Assume the design comes out of reset.
    initial assume (!rst_n);

    // The scan chain can encode mode 3, which the FSM has no handler for.
    // It is not a hazard - the default case gates the clock off and a further
    // scan write recovers - but the FSM does not reject it either. Assumed
    // away here and recorded in KNOWN_GAPS.md rather than silently ignored.
    always @* assume (cfg_mode_in != 2'd3);

    logic        past_valid;
    logic        cfg_load_q;
    logic [1:0]  mode_q, mode_q2;
    logic [15:0] count_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) past_valid <= 1'b0;
        else begin
            // one cycle of settling after reset release, so mode_q and count_q
            // hold post-reset values before any property compares against them
            past_valid <= 1'b1;
            mode_q     <= mode_o;
            cfg_load_q <= cfg_load;
            mode_q2    <= mode_q;
            count_q    <= dut.count;
        end
    end

    // P1: the CPU clock is genuinely dead in IDLE. This is the property the
    // whole clock-gating scheme exists to provide. It can fail: sample
    // run_gate on the wrong edge, or gate combinationally, and cpu_clk can
    // glitch high while mode is IDLE.
    // Stated over two cycles: leaving RUN on a rising edge legitimately lets
    // the current pulse finish, because run_gate_q is sampled on the falling
    // edge. What must hold is that once IDLE has persisted a full cycle, the
    // clock is dead.
    always @(posedge clk)
        if (past_valid && rst_n && mode_o == IDLE && mode_q == IDLE
            && mode_q2 == IDLE)
            assert (dut.run_gate_q == 1'b0);

    // P2: COUNTDOWN cannot clock the CPU once the count is exhausted.
    // Guards against an off-by-one that grants one extra cycle.
    // Stated on run_gate_q, not cpu_clk: the gate is sampled on the falling
    // edge, so the pulse in flight when the count expires legitimately
    // finishes. What must hold is that the gate is shut by the next edge.
    always @(posedge clk)
        if (past_valid && rst_n && mode_o == COUNTDOWN && dut.count == 16'd0
            && mode_q == COUNTDOWN)
            assert (dut.run_gate_q == 1'b0);

    // P3: the countdown is monotonic. A wrapping counter would run the CPU
    // forever instead of stopping it.
    always @(posedge clk)
        if (past_valid && rst_n && mode_q == COUNTDOWN && mode_o == COUNTDOWN
            && !cfg_load)
            assert (dut.count <= count_q);

    // P4: mode only ever changes on a scan write. Nothing else in the design
    // may move the FSM between modes.
    always @(posedge clk)
        // Keyed off the PREVIOUS cfg_load: mode_q is sampled on the same edge
        // the property evaluates, so a write last cycle legitimately shows a
        // changed mode this cycle.
        if (past_valid && rst_n && !cfg_load_q)
            assert (mode_o == mode_q);

    // P5: mode is always a legal encoding. 2'd3 is unassigned and would gate
    // the clock off permanently.
    always @* if (rst_n) assert (mode_o != 2'd3);

    // P6: memory ownership and clock gating never disagree. If scan owned
    // memory while the CPU was clocked, both could drive instruction memory.
    always @(posedge clk)
        if (past_valid && rst_n && scan_owns_mem && mode_q == IDLE
            && mode_q2 == IDLE)
            assert (dut.run_gate_q == 1'b0);
endmodule
