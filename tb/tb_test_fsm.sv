// ============================================================================
// tb_test_fsm.sv - verify the load/run sequencing FSM.
// Checks: power-up = RESET_HOLD (CPU held); start -> LOAD (scan owns mem, CPU held);
// load_done -> RUN (CPU released, CPU owns mem); stays in RUN.
// ============================================================================
`timescale 1ns/1ps
module tb_test_fsm;
    logic clk, rst_n;
    logic start, load_done;
    logic cpu_rst_n, scan_owns_mem;
    logic [1:0] state_o;

    localparam [1:0] RESET_HOLD=2'd0, LOAD=2'd1, RUN=2'd2;

    test_fsm dut (
        .clk(clk), .rst_n(rst_n),
        .start(start), .load_done(load_done),
        .cpu_rst_n(cpu_rst_n), .scan_owns_mem(scan_owns_mem), .state_o(state_o)
    );

    initial clk=0; always #5 clk=~clk;
    integer errors;

    task check(input [1:0] exp_state, input exp_cpu_rst_n, input exp_scan, input [127:0] label);
        begin
            #1;
            if (state_o !== exp_state || cpu_rst_n !== exp_cpu_rst_n || scan_owns_mem !== exp_scan) begin
                errors=errors+1;
                $display("  FAIL @%0s: state=%0d cpu_rst_n=%b scan_owns=%b (exp state=%0d rst_n=%b scan=%b)",
                    label, state_o, cpu_rst_n, scan_owns_mem, exp_state, exp_cpu_rst_n, exp_scan);
            end else
                $display("  OK @%0s: state=%0d cpu_rst_n=%b scan_owns=%b", label, state_o, cpu_rst_n, scan_owns_mem);
        end
    endtask

    initial begin
        errors=0; start=0; load_done=0;
        rst_n=0; repeat(3) @(posedge clk);
        check(RESET_HOLD, 1'b0, 1'b0, "reset");

        @(negedge clk); rst_n=1; @(posedge clk);
        check(RESET_HOLD, 1'b0, 1'b0, "post-reset (idle)");

        @(negedge clk); start=1;
        @(posedge clk); @(negedge clk); start=0;
        check(LOAD, 1'b0, 1'b1, "LOAD (scan owns mem, CPU held)");

        repeat(3) @(posedge clk);
        check(LOAD, 1'b0, 1'b1, "still LOADing");

        @(negedge clk); load_done=1;
        @(posedge clk); @(negedge clk); load_done=0;
        check(RUN, 1'b1, 1'b0, "RUN (CPU released, CPU owns mem)");

        repeat(4) @(posedge clk);
        check(RUN, 1'b1, 1'b0, "still RUNning");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED  (0 errors)");
        else           $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #10000; $display("TIMEOUT"); $finish; end
endmodule
