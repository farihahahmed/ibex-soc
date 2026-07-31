`timescale 1ns/1ps
module tb_test_fsm;
    logic clk, rst_n, cfg_load;
    logic [1:0]  cfg_mode_in;
    logic [15:0] cfg_count_in;
    logic cpu_clk, scan_owns_mem;
    logic [1:0]  mode_o;

    test_fsm dut(.clk(clk), .rst_n(rst_n), .cfg_load(cfg_load),
        .cfg_mode_in(cfg_mode_in), .cfg_count_in(cfg_count_in),
        .cpu_clk(cpu_clk), .scan_owns_mem(scan_owns_mem), .mode_o(mode_o));

    initial clk=0; always #5 clk=~clk;

    integer cpu_edges;
    always @(posedge cpu_clk) cpu_edges = cpu_edges + 1;

    integer errors;
    task set_mode(input [1:0] m, input [15:0] n);
        begin
            @(negedge clk); cfg_mode_in=m; cfg_count_in=n; cfg_load=1;
            @(negedge clk); cfg_load=0;
        end
    endtask

    initial begin
        errors=0; cpu_edges=0; cfg_load=0; cfg_mode_in=0; cfg_count_in=0;
        rst_n=0; repeat(4) @(negedge clk); rst_n=1; @(negedge clk);

        set_mode(2'd0, 16'd0);
        cpu_edges=0; repeat(20) @(negedge clk);
        if (cpu_edges!==0) begin $display("BAD idle: %0d edges (exp 0)", cpu_edges); errors=errors+1; end
        else $display("OK idle: clock suppressed");
        if (scan_owns_mem!==1'b1) begin $display("BAD idle: scan_owns_mem=%0b", scan_owns_mem); errors=errors+1; end

        set_mode(2'd1, 16'd0);
        cpu_edges=0; repeat(20) @(negedge clk);
        if (cpu_edges<18) begin $display("BAD run: %0d edges (exp ~20)", cpu_edges); errors=errors+1; end
        else $display("OK run: clock passing (%0d edges)", cpu_edges);
        if (scan_owns_mem!==1'b0) begin $display("BAD run: scan_owns_mem=%0b", scan_owns_mem); errors=errors+1; end

        set_mode(2'd2, 16'd5);
        cpu_edges=0; repeat(20) @(negedge clk);
        if (cpu_edges!==5) begin $display("BAD countdown: %0d edges (exp 5)", cpu_edges); errors=errors+1; end
        else $display("OK countdown: exactly 5 cycles then froze");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - 3-mode clock-gating FSM works!");
        else           $display("FAILED (%0d errors)", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
