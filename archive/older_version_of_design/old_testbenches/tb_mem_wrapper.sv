// ============================================================================
// tb_mem_wrapper.sv - my robust self-checking test for the memory wrapper
//
// The idea I landed on: instead of me trying to PREDICT which exact cycle rvalid
// fires (I got burned doing that - kept being off by one), I just REACT to it.
// I run a little background monitor that watches for rvalid going high, and when
// it sees it, it checks rdata against whatever value I expect for the read that's
// currently in flight. This is exactly how Ibex itself behaves: it waits for
// rvalid, then grabs rdata.
//
// I also change the address on every single read (like a real CPU would) so I
// don't get the "stale address" trap that fooled me earlier - where the address
// never changed and the data looked like it appeared instantly.
// ============================================================================

`timescale 1ns/1ps                   // time unit = 1ns, so "#5" below means 5ns.

module tb_mem_wrapper;                // testbench top - no ports, this is the top of the sim.

    // signals I use to drive and observe the wrapper.
    logic        clk, rst_n, req, gnt, we, rvalid;
    logic [3:0]  be;
    logic [31:0] addr, wdata, rdata;

    // the thing I'm testing (Device Under Test). Wire my signals to its pins.
    mem_wrapper dut (
        .clk(clk), .rst_n(rst_n),
        .req(req), .gnt(gnt), .we(we), .be(be),
        .addr(addr), .wdata(wdata),
        .rvalid(rvalid), .rdata(rdata)
    );

    initial clk = 0;                  // start the clock low at time 0.
    always #5 clk = ~clk;             // flip it every 5ns -> 10ns period -> 100 MHz.

    initial begin
        $dumpfile("tb_mem_wrapper.vcd");   // name the waveform file I can open in GTKWave.
        $dumpvars(0, tb_mem_wrapper);       // record every signal in this testbench.
    end

    integer errors, reads_expected, reads_seen;   // my tally counters for the summary at the end.
    logic [31:0] expected_data;   // what the read that's in flight SHOULD hand back.
    logic        read_pending;    // flag: is there a read waiting for its rvalid right now?

    // little helper: turn a word number into a byte address (word * 4).
    // I need this because Ibex speaks byte addresses, and my wrapper divides by 4 internally.
    function [31:0] byte_addr(input [8:0] word);
        byte_addr = {21'd0, word, 2'b00};   // glue 21 zeros + the 9-bit word + two zeros = word shifted left 2 = word*4.
    endfunction

    // ---- THE MONITOR: react to rvalid and check the data ----
    // This runs on every rising edge in the background. Whenever rvalid is high and
    // I actually have a read waiting, I know the read just completed, so I compare.
    always @(posedge clk) begin
        #1;                               // wait 1ns past the edge so signals have settled before I look.
        if (rvalid && read_pending) begin // a read finished this cycle.
            reads_seen = reads_seen + 1;  // count it.
            if (rdata !== expected_data) begin   // did I get the value I expected?
                errors = errors + 1;             // no -> that's a bug, tally it.
                $display("  MISMATCH: got 0x%08h, expected 0x%08h", rdata, expected_data);
            end
            read_pending = 0;             // clear the flag - this read is done, monitor can rest.
        end
    end

    // ---- WRITE through the handshake: just one request cycle ----
    task ibex_write(input [8:0] word, input [31:0] data);
        begin
            @(negedge clk);               // set up my inputs on the falling edge so they're stable at the rising edge.
            req = 1; we = 1; be = 4'hF;   // request a write, all 4 bytes enabled.
            addr = byte_addr(word);       // the byte address for this word.
            wdata = data;                 // the value to store.
            @(negedge clk);               // one cycle later...
            req = 0; we = 0; be = 0;       // ...drop everything back to idle.
        end
    endtask

    // ---- READ through the handshake: fire the request, arm the monitor, wait for it ----
    task ibex_read(input [8:0] word, input [31:0] exp);
        begin
            @(negedge clk);
            expected_data = exp;          // tell the monitor what this read should return.
            read_pending  = 1;            // arm the monitor - a read is now in flight.
            reads_expected = reads_expected + 1;   // count that I issued a read.
            req = 1; we = 0; be = 0;       // request a read.
            addr = byte_addr(word);       // at this address.
            @(negedge clk);
            req = 0;                       // request only lasts one cycle.
            wait (read_pending == 0);      // pause here until the monitor sees rvalid and clears the flag.
        end
    endtask

    initial begin
        // reset everything and zero my counters.
        rst_n = 0; req = 0; we = 0; be = 0; addr = 0; wdata = 0;
        errors = 0; reads_expected = 0; reads_seen = 0;
        read_pending = 0; expected_data = 0;
        repeat (2) @(posedge clk);         // hold reset for a couple cycles.
        @(negedge clk); rst_n = 1;         // release reset.
        @(posedge clk);

        $display("TEST: write several words, then read them back (changing addr)");
        ibex_write(9'd0,   32'hCAFE_0000); // write a few distinct values to a few boxes.
        ibex_write(9'd5,   32'hDEAD_BEEF);
        ibex_write(9'd42,  32'h1234_5678);
        ibex_write(9'd511, 32'hABCD_EF01);

        // now read them all back, each at a DIFFERENT address (like a real CPU does).
        ibex_read(9'd0,   32'hCAFE_0000);
        ibex_read(9'd5,   32'hDEAD_BEEF);
        ibex_read(9'd42,  32'h1234_5678);
        ibex_read(9'd511, 32'hABCD_EF01);
        ibex_read(9'd5,   32'hDEAD_BEEF);   // re-read box 5 to prove the data stuck around.

        // ---- summary ----
        $display("--------------------------------------------------");
        if (errors == 0 && reads_seen == reads_expected)   // no mismatches AND I saw every read complete.
            $display("ALL TESTS PASSED  (%0d reads, 0 errors)", reads_seen);
        else
            $display("TESTS FAILED  (expected %0d reads, saw %0d, %0d errors)",
                     reads_expected, reads_seen, errors);
        $display("--------------------------------------------------");

        repeat (4) @(posedge clk);         // let a few more cycles run so the waveform has a tail.
        $finish;                           // end the sim.
    end

endmodule
