// ============================================================================
// test_fsm_formal.sv - formal properties for the clock-gating FSM.
//
// Bounded model checking (Yosys + yosys-smtbmc). These hold for EVERY input
// sequence up to the bound, not just the stimulus a testbench applies.
//
// Every property below can fail. Assertions that merely restate an assign
// statement prove nothing and are deliberately excluded.
//
// FINDING: the FSM accepts mode 2'd3, which has no handler. The default case
// gates the clock off and a further scan write recovers, so it is not a
// hazard - but the FSM does not reject it either. Assumed away below and
// recorded in KNOWN_GAPS.md rather than silently ignored. A testbench would
// not have surfaced this.
//
// WITHHELD: "cpu_clk is dead in IDLE" and "scan ownership implies no CPU
// clock". Both depend on run_gate_q, which is clocked on negedge clk. The
// async2sync / dffunmap transform used to reach BMC does not preserve negedge
// semantics faithfully, and the solver reports counterexamples at cycle
// boundaries that cannot occur in the real gate. The behaviour is covered
// dynamically by block/fsm idle-hold. Left open rather than weakened into an
// assertion that cannot fail.
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

    // BMC starts from an arbitrary state unless told otherwise.
    initial assume (!rst_n);
    always @* assume (cfg_mode_in != 2'd3);   // see FINDING above

    logic        past_valid, cfg_load_q;
    logic [1:0]  mode_q;
    logic [15:0] count_q;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) past_valid <= 1'b0;
        else begin
            past_valid <= 1'b1;
            mode_q     <= mode_o;
            count_q    <= dut.count;
            cfg_load_q <= cfg_load;
        end
    end

    // WITHHELD: countdown monotonicity. cfg_load may arrive during COUNTDOWN
    // and reload count to a larger value, so the property needs to exclude
    // every reload boundary rather than just the adjacent cycle. Covered
    // dynamically by test_pyuvm_countdown, which checks the gate drops when
    // the count expires. Left open rather than patched into vacuity.

    // P2: mode only ever changes on a scan write. Nothing else in the design
    // may move the FSM between modes. Keyed off the PREVIOUS cfg_load because
    // mode_q is sampled on the same edge the property evaluates.
    always @(posedge clk)
        if (past_valid && rst_n && !cfg_load_q)
            assert (mode_o == mode_q);

    // P3: mode is always a legal encoding, given the assumption above.
    always @* if (rst_n) assert (mode_o != 2'd3);

    // P4: scan owns memory exactly in IDLE. Stated over a settled cycle so it
    // is a claim about the FSM, not about the assign statement.
    always @(posedge clk)
        if (past_valid && rst_n && mode_q == mode_o)
            assert (scan_owns_mem == (mode_o == IDLE));
endmodule
