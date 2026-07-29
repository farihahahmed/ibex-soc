// ============================================================================
// tb_scan_chain.sv - verify the program-loading scan chain against a tiny memory.
//
// I shift in a frame { addr[15:0], data[31:0] } MSB-first, pulse load, and check
// the word landed in my little memory model at the right address. Then I do a
// second word to be sure, and finally test read-back (capture a mem word and
// shift it out on scan_out).
// ============================================================================
`timescale 1ns/1ps
module tb_scan_chain;
    logic clk, rst_n;
    logic scan_in, scan_shift, scan_load, scan_capture, scan_out;
    logic        mem_we;
    logic [15:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;

    scan_chain dut (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_capture(scan_capture), .scan_out(scan_out),
        .mem_we(mem_we), .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_rdata(mem_rdata)
    );

    // tiny memory model: 256 words, written on mem_we, read combinationally
    logic [31:0] mem [0:255];
    always_ff @(posedge clk) begin
        if (mem_we) mem[mem_addr[7:0]] <= mem_wdata;
    end
    assign mem_rdata = mem[mem_addr[7:0]];

    initial clk=0; always #5 clk=~clk;

    integer errors;
    integer k;

    // shift a 48-bit frame in, LSB first (last bit sent lands at the top)
    task shift_frame(input [15:0] a, input [31:0] d);
        logic [47:0] frame;
        begin
            frame = {a, d};
            for (k=0; k<48; k=k+1) begin
                @(negedge clk);
                scan_in   = frame[k];   // LSB first
                scan_shift = 1'b1;
            end
            @(negedge clk); scan_shift = 1'b0; scan_in = 1'b0;
        end
    endtask

    task do_load;
        begin
            @(negedge clk); scan_load = 1'b1;
            @(negedge clk); scan_load = 1'b0;
        end
    endtask

    initial begin
        scan_in=0; scan_shift=0; scan_load=0; scan_capture=0;
        errors=0;
        rst_n=0; repeat(3) @(posedge clk); @(negedge clk); rst_n=1; repeat(2) @(posedge clk);

        // ---- Word 1: write 0xDEADBEEF to address 0x10 ----
        $display("TEST 1: scan in (addr=0x0010, data=0xDEADBEEF), load");
        shift_frame(16'h0010, 32'hDEAD_BEEF);
        do_load;
        #1;
        if (mem[16'h10] !== 32'hDEAD_BEEF) begin
            errors=errors+1; $display("  FAIL: mem[0x10]=0x%08h expected 0xDEADBEEF", mem[16'h10]);
        end else $display("  OK: mem[0x10] = 0xDEADBEEF");

        // ---- Word 2: write 0x12345678 to address 0x20 ----
        $display("TEST 2: scan in (addr=0x0020, data=0x12345678), load");
        shift_frame(16'h0020, 32'h1234_5678);
        do_load;
        #1;
        if (mem[16'h20] !== 32'h1234_5678) begin
            errors=errors+1; $display("  FAIL: mem[0x20]=0x%08h expected 0x12345678", mem[16'h20]);
        end else $display("  OK: mem[0x20] = 0x12345678");

        // confirm word 1 wasn't disturbed
        if (mem[16'h10] !== 32'hDEAD_BEEF) begin
            errors=errors+1; $display("  FAIL: mem[0x10] disturbed = 0x%08h", mem[16'h10]);
        end else $display("  OK: mem[0x10] still 0xDEADBEEF");

        // ---- Read-back: point the frame's address at 0x20, capture, shift out ----
        $display("TEST 3: read-back mem[0x20] via capture + shift out");
        shift_frame(16'h0020, 32'h0000_0000);
        @(negedge clk); scan_capture = 1'b1;
        @(negedge clk); scan_capture = 1'b0;
        begin : readback
            logic [31:0] got; got = 32'h0;
            for (k=0; k<32; k=k+1) begin
                #1; got[k] = scan_out;        // sample the current bottom bit
                @(negedge clk); scan_shift = 1'b1;   // then shift to advance
                @(negedge clk); scan_shift = 1'b0;
            end
            if (got !== 32'h1234_5678) begin
                errors=errors+1; $display("  FAIL: read-back got 0x%08h expected 0x12345678", got);
            end else $display("  OK: read-back = 0x12345678");
        end

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL TESTS PASSED  (0 errors)");
        else           $display("TESTS FAILED  (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
