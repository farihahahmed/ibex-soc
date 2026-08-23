`timescale 1ns/1ps
module tb_mem_sub;
    logic clk, rst_n_in;
    logic        instr_req, instr_gnt, instr_rvalid;
    logic [31:0] instr_addr, instr_rdata;
    logic        data_req, data_gnt, data_we, data_rvalid;
    logic [3:0]  data_be;
    logic [31:0] data_addr, data_wdata, data_rdata;
    logic        scan_owns_mem, scan_we, scan_sel_dmem;
    logic [15:0] scan_addr;
    logic [31:0] scan_wdata;

    mem_subsystem dut (
        .clk(clk), .rst_n_in(rst_n_in),
        .instr_req_i(instr_req), .instr_gnt_o(instr_gnt), .instr_addr_i(instr_addr),
        .instr_rvalid_o(instr_rvalid), .instr_rdata_o(instr_rdata),
        .data_req_i(data_req), .data_gnt_o(data_gnt), .data_we_i(data_we),
        .data_be_i(data_be), .data_addr_i(data_addr), .data_wdata_i(data_wdata),
        .data_rvalid_o(data_rvalid), .data_rdata_o(data_rdata),
        .scan_owns_mem(scan_owns_mem), .scan_we(scan_we),
        .scan_addr(scan_addr), .scan_wdata(scan_wdata), .scan_sel_dmem(scan_sel_dmem)
    );

    initial clk=0; always #5 clk=~clk;
    integer errors;

    task scan_imem(input [15:0] waddr, input [31:0] wdata);
        begin
            @(negedge clk);
            scan_owns_mem=1; scan_sel_dmem=0; scan_we=1;
            scan_addr=waddr; scan_wdata=wdata;
            @(negedge clk);
            scan_we=0;
            repeat(6) @(negedge clk);
        end
    endtask

    task fetch_chk(input [31:0] a, input [31:0] exp);
        begin
            @(negedge clk); instr_addr=a; instr_req=1;
            wait(instr_gnt); @(negedge clk); instr_req=0;
            wait(instr_rvalid); #1;
            if (instr_rdata===exp) $display("OK  fetch @0x%03h = 0x%08h", a, instr_rdata);
            else begin $display("BAD fetch @0x%03h = 0x%08h (exp 0x%08h)", a, instr_rdata, exp); errors=errors+1; end
            @(negedge clk);
        end
    endtask

    initial begin
        errors=0;
        instr_req=0; instr_addr=0;
        data_req=0; data_we=0; data_be=0; data_addr=0; data_wdata=0;
        scan_owns_mem=0; scan_we=0; scan_sel_dmem=0; scan_addr=0; scan_wdata=0;
        rst_n_in=0; repeat(5) @(posedge clk); rst_n_in=1;
        repeat(8) @(negedge clk);   // let rst_sync + macro wake before scanning

        scan_imem(16'd0, 32'h00500093);
        scan_imem(16'd1, 32'h00A00113);
        scan_imem(16'd2, 32'h002081B3);
        scan_imem(16'd3, 32'hFFDFF06F);

        @(negedge clk); scan_owns_mem=0;

        fetch_chk(32'h000, 32'h00500093);
        fetch_chk(32'h004, 32'h00A00113);
        fetch_chk(32'h008, 32'h002081B3);
        fetch_chk(32'h00C, 32'hFFDFF06F);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - mem_subsystem narrow imem scan-load + fetch works!");
        else           $display("FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #80000; $display("TIMEOUT"); $finish; end
endmodule
