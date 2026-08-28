// test_fsm.sv - Columbia-style 3-mode clock-gating FSM.
// Modes (from scan-written cfg_mode): 0=IDLE (clk suppressed), 1=RUN (clk passes),
// 2=COUNTDOWN (clk passes for cfg_count cycles then gates).
module test_fsm (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        cfg_load,
    input  logic [1:0]  cfg_mode_in,
    input  logic [15:0] cfg_count_in,
    output logic        cpu_clk,
    output logic        scan_owns_mem,
    output logic [1:0]  mode_o
);
    localparam logic [1:0] IDLE=2'd0, RUN=2'd1, COUNTDOWN=2'd2;

    logic [1:0]  mode;
    logic [15:0] count;
    logic        run_gate;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mode  <= IDLE;
            count <= 16'd0;
        end else if (cfg_load) begin
            mode  <= cfg_mode_in;
            count <= cfg_count_in;
        end else if (mode == COUNTDOWN && count != 16'd0) begin
            count <= count - 16'd1;
        end
    end

    always_comb begin
        case (mode)
            RUN:       run_gate = 1'b1;
            COUNTDOWN: run_gate = (count != 16'd0);
            default:   run_gate = 1'b0;
        endcase
    end

    // Clock gate: use the PDK integrated clock-gating cell (icgtp_1), matching
    // clk_gen.sv. Register the enable on posedge clk so E is stable and settled
    // before the ICG's internal latch samples it on the low phase of clk; the
    // latch then holds E steady through the high phase, so Q = clk & E can never
    // emit a runt pulse. This replaces the old hand-rolled `clk & run_gate_q`
    // AND, which the tools did not recognise as a clock gate: it produced a
    // 2250-fanout net off a weak 1x cell (antenna + slew + router congestion).
    logic run_gate_q;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) run_gate_q <= 1'b0;
        else        run_gate_q <= run_gate;
    end

    gf180mcu_fd_sc_mcu7t5v0__icgtp_1 u_cpu_icg (
        .CLK (clk),
        .E   (run_gate_q),
        .TE  (1'b0),
        .Q   (cpu_clk)
    );

    assign scan_owns_mem = (mode == IDLE);
    assign mode_o        = mode;
endmodule
