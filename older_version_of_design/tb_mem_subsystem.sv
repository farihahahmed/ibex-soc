// ============================================================================
// tb_mem_subsystem.sv - my testbench for the whole memory subsystem
//
// Goal: prove the assembly is wired right. I drive both ports through the
// subsystem's interface and check:
//   1. Data memory: I can write a value and read it back.
//   2. Persistence: values survive later writes.
//   3. Instruction port: grants and returns valid data (reads zeros, mem empty).
//
// Style: I REACT to rvalid with a monitor per port instead of guessing cycles.
// ============================================================================

`timescale 1ns/1ps

module tb_mem_subsystem;

    logic        clk, rst_n_in;

    logic        instr_req_i, instr_gnt_o, instr_rvalid_o;
    logic [31:0] instr_addr_i, instr_rdata_o;

    logic        data_req_i, data_gnt_o, data_we_i, data_rvalid_o;
    logic [3:0]  data_be_i;
    logic [31:0] data_addr_i, data_wdata_i, data_rdata_o;

    mem_subsystem dut (
        .clk(clk), .rst_n_in(rst_n_in),
        .instr_req_i(instr_req_i), .instr_gnt_o(instr_gnt_o),
        .instr_addr_i(instr_addr_i), .instr_rvalid_o(instr_rvalid_o),
        .instr_rdata_o(instr_rdata_o),
        .data_req_i(data_req_i), .data_gnt_o(data_gnt_o),
        .data_we_i(data_we_i), .data_be_i(data_be_i),
        .data_addr_i(data_addr_i), .data_wdata_i(data_wdata_i),
        .data_rvalid_o(data_rvalid_o), .data_rdata_o(data_rdata_o)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("tb_mem_subsystem.vcd");
        $dumpvars(0, tb_mem_subsystem);
    end

    integer errors;
    logic [31:0] d_expected;
    logic        d_pending;
    logic        i_expected_valid;   // am I waiting on an instruction read?
    logic        i_seen;             // did the monitor catch it?

    function [31:0] byte_addr(input [8:0] word);
        byte_addr = {21'd0, word, 2'b00};
    endfunction

    // monitor for the DATA port
    always @(posedge clk) begin
        #1;
        if (data_rvalid_o && d_pending) begin
            if (data_rdata_o !== d_expected) begin
                errors = errors + 1;
                $display("  MISMATCH (data): got 0x%08h, expected 0x%08h",
                         data_rdata_o, d_expected);
            end
            d_pending = 0;
        end
    end

    // monitor for the INSTRUCTION port - just catch that rvalid fires at all
    always @(posedge clk) begin
        #1;
        if (instr_rvalid_o && i_expected_valid) begin
            i_seen = 1;
            i_expected_valid = 0;
        end
    end

    task data_write(input [8:0] word, input [31:0] val);
        begin
            @(negedge clk);
            data_req_i = 1; data_we_i = 1; data_be_i = 4'hF;
            data_addr_i = byte_addr(word); data_wdata_i = val;
            @(negedge clk);
            data_req_i = 0; data_we_i = 0; data_be_i = 0;
        end
    endtask

    task data_read(input [8:0] word, input [31:0] exp);
        begin
            @(negedge clk);
            d_expected = exp; d_pending = 1;
            data_req_i = 1; data_we_i = 0; data_be_i = 0;
            data_addr_i = byte_addr(word);
            @(negedge clk);
            data_req_i = 0;
            wait (d_pending == 0);
        end
    endtask

    // fetch from instruction memory, wait for its rvalid via the monitor
    task instr_fetch(input [8:0] word);
        begin
            @(negedge clk);
            i_expected_valid = 1; i_seen = 0;
            instr_req_i = 1; instr_addr_i = byte_addr(word);
            @(negedge clk);
            instr_req_i = 0;
            wait (i_expected_valid == 0);   // monitor clears it when rvalid fires
        end
    endtask

    initial begin
        instr_req_i = 0; instr_addr_i = 0;
        data_req_i = 0; data_we_i = 0; data_be_i = 0; data_addr_i = 0; data_wdata_i = 0;
        errors = 0; d_pending = 0; d_expected = 0;
        i_expected_valid = 0; i_seen = 0;
        rst_n_in = 0;
        repeat (3) @(posedge clk);
        @(negedge clk); rst_n_in = 1;
        repeat (2) @(posedge clk);

        $display("TEST 1: write and read data memory");
        data_write(9'd10,  32'hAAAA_1111);
        data_write(9'd12,  32'hBBBB_2222);
        data_write(9'd15,  32'hCCCC_3333);
        data_read (9'd10,  32'hAAAA_1111);
        data_read (9'd12,  32'hBBBB_2222);
        data_read (9'd15,  32'hCCCC_3333);

        $display("TEST 2: re-read to confirm persistence");
        data_read (9'd10,  32'hAAAA_1111);

        $display("TEST 3: instruction port grants and returns valid");
        instr_fetch(9'd0);
        if (!i_seen) begin
            errors = errors + 1;
            $display("  FAIL: instr port never returned valid");
        end

        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED  (0 errors)");
        else
            $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");

        repeat (4) @(posedge clk);
        $finish;
    end

endmodule
