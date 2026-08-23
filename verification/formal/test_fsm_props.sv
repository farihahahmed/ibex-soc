// Formal props for test_fsm – modes IDLE/RUN/COUNTDOWN
module test_fsm_props (
    input logic       clk,
    input logic       rst_n,
    input logic       cfg_load,
    input logic [1:0] cfg_mode_in,
    input logic [15:0] cfg_count_in,
    input logic       cpu_clk,
    input logic       scan_owns_mem,
    input logic [1:0] mode_o
);
    // After reset, mode is IDLE
    assert property (@(posedge clk) disable iff (!rst_n)
        $rose(rst_n) |-> ##1 (mode_o == 2'd0));

    // scan_owns_mem only in IDLE
    assert property (@(posedge clk) disable iff (!rst_n)
        (mode_o == 2'd0) |-> scan_owns_mem);
    assert property (@(posedge clk) disable iff (!rst_n)
        (mode_o != 2'd0) |-> !scan_owns_mem);

    // mode only legal values
    assert property (@(posedge clk) disable iff (!rst_n)
        mode_o inside {2'd0, 2'd1, 2'd2});
endmodule

bind test_fsm test_fsm_props u_props (.*);
