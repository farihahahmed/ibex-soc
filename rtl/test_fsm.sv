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

    assign cpu_clk       = clk & run_gate;
    assign scan_owns_mem = (mode == IDLE);
    assign mode_o        = mode;
endmodule
