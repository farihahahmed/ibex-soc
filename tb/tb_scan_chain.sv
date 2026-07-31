`timescale 1ns/1ps
module tb_scan_chain;
    logic clk, rst_n, scan_in, scan_shift, scan_load, scan_i0o1, scan_out;
    logic mem_we; logic [15:0] mem_addr; logic [31:0] mem_wdata, mem_rdata;
    logic fsm_cfg_load; logic [1:0] fsm_mode; logic [15:0] fsm_count;
    logic clk_cfg_load, clk_int; logic [7:0] clk_div;

    scan_chain dut(.clk(clk), .rst_n(rst_n), .scan_in(scan_in),
        .scan_shift(scan_shift), .scan_load(scan_load), .scan_i0o1(scan_i0o1),
        .scan_out(scan_out), .mem_we(mem_we), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_rdata(mem_rdata),
        .fsm_cfg_load(fsm_cfg_load), .fsm_mode(fsm_mode), .fsm_count(fsm_count),
        .clk_cfg_load(clk_cfg_load), .clk_int(clk_int), .clk_div(clk_div));

    initial clk=0; always #5 clk=~clk;
    integer k, errors;

    task shift_frame(input [47:0] frame);
        begin
            for (k=0;k<48;k=k+1) begin
                @(negedge clk); scan_in=frame[k]; scan_shift=1;
            end
            @(negedge clk); scan_shift=0; scan_in=0;
        end
    endtask
    task pulse_load; begin @(negedge clk); scan_load=1; @(negedge clk); scan_load=0; end endtask

    initial begin
        errors=0; scan_in=0; scan_shift=0; scan_load=0; scan_i0o1=0; mem_rdata=0;
        rst_n=0; repeat(4) @(negedge clk); rst_n=1; @(negedge clk);

        shift_frame({2'd0, 14'h0020, 32'hDEADBEEF});
        #1;
        if (mem_addr!==16'h0020 || mem_wdata!==32'hDEADBEEF) begin
            $display("BAD mem fields addr=%h data=%h", mem_addr, mem_wdata); errors=errors+1;
        end else $display("OK mem frame decoded");
        pulse_load;

        shift_frame({2'd1, 14'h0000, 14'h0000, 2'd2, 16'd100});
        #1;
        if (fsm_mode!==2'd2 || fsm_count!==16'd100) begin
            $display("BAD fsm mode=%0d count=%0d", fsm_mode, fsm_count); errors=errors+1;
        end else $display("OK fsm cfg decoded (mode=2 count=100)");
        @(negedge clk); scan_load=1; #1;
        if (fsm_cfg_load!==1 || mem_we!==0 || clk_cfg_load!==0) begin
            $display("BAD fsm load routing"); errors=errors+1;
        end else $display("OK fsm_cfg_load routed");
        @(negedge clk); scan_load=0;

        shift_frame({2'd2, 14'h0000, 23'h000000, 1'b1, 8'd5});
        #1;
        if (clk_int!==1'b1 || clk_div!==8'd5) begin
            $display("BAD clk cfg int=%b div=%0d", clk_int, clk_div); errors=errors+1;
        end else $display("OK clk cfg decoded (int=1 div=5)");
        @(negedge clk); scan_load=1; #1;
        if (clk_cfg_load!==1 || mem_we!==0 || fsm_cfg_load!==0) begin
            $display("BAD clk load routing"); errors=errors+1;
        end else $display("OK clk_cfg_load routed");
        @(negedge clk); scan_load=0;

        mem_rdata=32'h12345678; @(negedge clk); scan_i0o1=1; @(negedge clk); scan_i0o1=0; #1;
        if (mem_wdata!==32'h12345678) begin $display("BAD capture %h", mem_wdata); errors=errors+1; end
        else $display("OK read-back capture");

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - extended scan chain works!");
        else           $display("FAILED (%0d errors)", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
