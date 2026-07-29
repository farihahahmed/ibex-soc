// ============================================================================
// test_fsm.sv - my debug/test gating FSM. Sequences load -> run on the chip.
//
// On the real chip, after power-up I can't just let the CPU start - memory is
// empty. So I need a defined sequence:
//   1. hold the CPU in reset,
//   2. let the SCAN CHAIN own the memory write path and shift the program in,
//   3. once loaded, hand memory back to the CPU and release it to run.
//
// This little FSM produces the control signals for that sequence. It's the
// "conductor" that ties my scan chain and CPU together.
//
// States:
//   RESET_HOLD : CPU in reset, waiting to start. (power-up state)
//   LOAD       : CPU still in reset; scan chain owns memory; program shifting in.
//   RUN        : CPU released; CPU owns memory; program executing.
//
// Inputs:
//   start      : go from RESET_HOLD -> LOAD (begin loading).
//   load_done  : go from LOAD -> RUN (loading finished).
// Outputs:
//   cpu_rst_n     : 0 while holding/loading, 1 in RUN (release the CPU).
//   scan_owns_mem : 1 in LOAD (scan chain drives memory), 0 otherwise (CPU drives it).
// ============================================================================

module test_fsm (
    input  logic clk,
    input  logic rst_n,          // chip-level reset (async).

    input  logic start,          // pulse/level: begin the load sequence.
    input  logic load_done,      // pulse/level: scan load finished, go run.

    output logic cpu_rst_n,      // gated reset for the CPU (0 = held, 1 = running).
    output logic scan_owns_mem,  // 1 = scan chain owns the memory write path.
    output logic [1:0] state_o   // expose the state (handy for debug / a pin).
);

    typedef enum logic [1:0] {
        RESET_HOLD = 2'd0,
        LOAD       = 2'd1,
        RUN        = 2'd2
    } state_t;

    state_t state, next_state;

    // ---- state register ----
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= RESET_HOLD;   // power-up: hold everything.
        else        state <= next_state;
    end

    // ---- next-state logic ----
    always_comb begin
        next_state = state;
        case (state)
            RESET_HOLD: if (start)     next_state = LOAD;   // begin loading.
            LOAD:       if (load_done) next_state = RUN;    // done -> run.
            RUN:        next_state = RUN;                   // stay running.
            default:    next_state = RESET_HOLD;
        endcase
    end

    // ---- outputs (Moore: depend only on the state) ----
    always_comb begin
        // defaults: CPU held, CPU owns memory.
        cpu_rst_n     = 1'b0;
        scan_owns_mem = 1'b0;
        case (state)
            RESET_HOLD: begin
                cpu_rst_n     = 1'b0;   // CPU held in reset.
                scan_owns_mem = 1'b0;
            end
            LOAD: begin
                cpu_rst_n     = 1'b0;   // still holding the CPU.
                scan_owns_mem = 1'b1;   // scan chain drives memory during load.
            end
            RUN: begin
                cpu_rst_n     = 1'b1;   // release the CPU.
                scan_owns_mem = 1'b0;   // CPU owns memory now.
            end
            default: begin
                cpu_rst_n     = 1'b0;
                scan_owns_mem = 1'b0;
            end
        endcase
    end

    assign state_o = state;

endmodule
