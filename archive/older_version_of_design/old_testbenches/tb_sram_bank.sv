// ============================================================================
// tb_sram_bank.sv - my strengthened self-checking test for the 2KB memory bank
//
// This is the "bulletproof" version. The earlier simple test only checked one
// address once - not good enough. This one hammers the bank properly:
//   - writes lots of different addresses (including the edges, box 0 and box 511)
//   - proves earlier boxes don't get clobbered by later writes
//   - tests byte-enables (partial writes that only touch some bytes)
//
// Key timing lesson I learned the hard way: I set up my inputs on the FALLING
// edge so they're rock-stable by the time the rising edge captures them, and I
// return to idle between each transaction so they don't bleed into each other.
// (My first attempt raced the rising edge and gave me a fake failure.)
// ============================================================================

`timescale 1ns/1ps                   // time unit = 1ns, so "#5" means 5ns.

module tb_sram_bank;                  // testbench top - no ports.

    // signals wired to my bank's pins.
    logic        clk;
    logic        cs;
    logic        we;
    logic [3:0]  be;
    logic [8:0]  addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    // the bank I'm testing (Device Under Test).
    sram_bank_2k dut (
        .clk(clk), .cs(cs), .we(we), .be(be),
        .addr(addr), .wdata(wdata), .rdata(rdata)
    );

    initial clk = 0;                  // clock starts low.
    always #5 clk = ~clk;             // flip every 5ns -> 10ns period.

    initial begin
        $dumpfile("tb_sram_bank.vcd");     // waveform file for GTKWave.
        $dumpvars(0, tb_sram_bank);         // dump everything.
    end

    // my SCOREBOARD: a private copy of what I THINK is in memory. I update it on
    // every write, then compare reads against it. This is how the test knows the
    // right answer independently of the bank - if they disagree, that's a real bug.
    logic [31:0] expected [0:511];    // 512 entries, one per box, matching the bank.

    integer errors, checks, a;        // my tally counters.

    // WRITE task: drive the inputs, let one rising edge do the write, go back to idle.
    task do_write(input [8:0] address, input [31:0] data, input [3:0] byteen);
        begin
            @(negedge clk);           // set up inputs on the falling edge (safe, well before the rising edge).
            cs    = 1;                // select the bank.
            we    = 1;                // writing.
            be    = byteen;           // which bytes to write.
            addr  = address;          // which box.
            wdata = data;             // the value.
            @(posedge clk);           // rising edge -> the write actually happens here.
            @(negedge clk);           // come back to idle cleanly.
            cs = 0; we = 0; be = 0;

            // update my scoreboard to match - but ONLY the bytes I actually enabled.
            // this mirrors exactly what the byte-enables did in hardware.
            if (byteen[0]) expected[address][7:0]   = data[7:0];
            if (byteen[1]) expected[address][15:8]  = data[15:8];
            if (byteen[2]) expected[address][23:16] = data[23:16];
            if (byteen[3]) expected[address][31:24] = data[31:24];
        end
    endtask

    // READ + CHECK task: present the address, wait the 1-cycle latency, sample, compare to scoreboard.
    task do_read_check(input [8:0] address);
        begin
            @(negedge clk);
            cs   = 1;                 // select.
            we   = 0;                 // reading.
            be   = 4'b0000;           // byte-enables don't matter on a read.
            addr = address;           // which box.
            @(posedge clk);           // this edge presents the read...
            @(posedge clk);           // ...and the data is valid on THIS edge (my 1-cycle latency).
            #1;                       // wait 1ns so everything settles before I sample.
            checks = checks + 1;      // count this check.
            if (rdata !== expected[address]) begin   // does the bank match my scoreboard?
                errors = errors + 1;                 // no -> real bug, tally and report it.
                $display("  MISMATCH: box %0d  expected 0x%08h  got 0x%08h",
                         address, expected[address], rdata);
            end
            @(negedge clk);
            cs = 0;                   // back to idle.
        end
    endtask

    initial begin
        cs = 0; we = 0; be = 0; addr = 0; wdata = 0;   // start idle (asleep). First write gives the wake-up edge.
        errors = 0; checks = 0;
        @(posedge clk);

        // ---- TEST 1: write a spread of addresses (incl. boundaries 0 and 511), read them all back ----
        $display("TEST 1: write many addresses, read them all back");
        do_write(9'd0,   32'hA0A0_0000, 4'hF);   // box 0 - the first box (boundary).
        do_write(9'd5,   32'hDEAD_BEEF, 4'hF);
        do_write(9'd42,  32'h1234_5678, 4'hF);
        do_write(9'd200, 32'hCAFE_F00D, 4'hF);
        do_write(9'd511, 32'hFFFF_FFFF, 4'hF);   // box 511 - the last box (boundary).

        do_read_check(9'd0);          // read them all back - if addressing is wrong, these mismatch.
        do_read_check(9'd5);
        do_read_check(9'd42);
        do_read_check(9'd200);
        do_read_check(9'd511);

        // ---- TEST 2: prove the later writes above didn't clobber the earlier boxes ----
        $display("TEST 2: earlier boxes untouched by later writes");
        do_read_check(9'd5);          // box 5 should STILL be DEADBEEF.
        do_read_check(9'd0);          // box 0 should STILL be A0A00000.

        // ---- TEST 3: the byte-enable test - the tricky one nothing else checked ----
        $display("TEST 3: byte-enable partial write");
        do_write(9'd100, 32'h1111_2222, 4'hF);       // put a full word in box 100 first.
        do_read_check(9'd100);                        // sanity check: it should read 0x11112222.
        do_write(9'd100, 32'h9999_8888, 4'b0011);    // now overwrite ONLY the low 2 bytes.
        do_read_check(9'd100);                        // top half must survive -> expect 0x11118888.
        do_write(9'd100, 32'h7700_0000, 4'b1000);    // overwrite ONLY the top byte.
        do_read_check(9'd100);                        // expect 0x77118888.

        // ---- summary ----
        $display("--------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED  (%0d checks, 0 errors)", checks);
        else
            $display("TESTS FAILED  (%0d checks, %0d errors)", checks, errors);
        $display("--------------------------------------------------");

        repeat (4) @(posedge clk);    // let a few cycles run so the waveform has a tail.
        $finish;                      // done.
    end

endmodule
