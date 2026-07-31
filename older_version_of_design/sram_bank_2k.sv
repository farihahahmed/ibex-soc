// ============================================================================
// sram_bank_2k.sv
// This is my 2 KB memory. It holds 512 words, each word 32 bits wide.
// I built it out of 4 copies of the GF180 "sram512x8" macro, sitting side by side.
// Each macro is 512 boxes x 8 bits, so 4 of them stacked = 512 boxes x 32 bits.
// The whole reason this file exists: the raw macro has annoying active-low pins,
// so I wrap 4 of them here and expose nice active-high signals. I deal with the
// weirdness once, right here, so nothing else in my chip ever has to.
// ============================================================================

// "module" starts a hardware block, and I'm naming this one sram_bank_2k.
// Everything from here down to "endmodule" is what's inside this block.
module sram_bank_2k (
    input  logic        clk,      // clock in. Everything I do happens on its rising edge.
    input  logic        cs,       // chip select. I set this to 1 when I actually want to use the memory this cycle.
    input  logic        we,       // write enable. 1 = I'm writing, 0 = I'm reading.
    input  logic [3:0]  be,       // byte enables. be[i]=1 means "write byte i". A word is 4 bytes, so I get 4 of these.
    input  logic [8:0]  addr,     // address. Picks which of the 512 boxes I'm pointing at. It's 9 bits because 2^9 = 512.
    input  logic [31:0] wdata,    // write data. The 32-bit value I want to store.
    output logic [31:0] rdata     // read data. The 32-bit value I get back. Reminder to self: it shows up NEXT cycle, not instantly.
);
    // Quick reminder on the syntax above, in case I forget:
    // "logic" is just the signal type (it holds 0s and 1s).
    // "[31:0]" means the signal is 32 wires wide. A name with no brackets = 1 wire.
    // "input"/"output" is which way the signal flows through this block's boundary.

    // --------------------------------------------------------------------
    // Step 1: flip my nice active-HIGH controls into the macro's active-LOW ones.
    // The macro is backwards - it does its job when a control is 0, not 1.
    // I invert them right here so I never have to think about it anywhere else.
    // --------------------------------------------------------------------

    logic cen;                    // internal wire I'm making: this is the chip-enable I'll feed the macro.
    assign cen = ~cs;             // The macro's CEN is active-low, so CEN=0 means "on".
                                  // When I want it on (cs=1), I need cen=0, so I flip cs with "~".
                                  // When I'm idle (cs=0), cen=1 and the macro sleeps. Bonus: going from
                                  // sleep (1) to active (0) gives the macro the 1->0 wake-up edge it demands.

    logic gwen;                   // internal wire: the write-direction signal I'll feed the macro.
    assign gwen = ~we;            // The macro's GWEN is active-low too: 0 = write, 1 = read.
                                  // So when I want to write (we=1), I flip it to gwen=0. Reading (we=0) -> gwen=1.

    // --------------------------------------------------------------------
    // Step 2: build the full 32-bit memory out of 4 byte-wide macros.
    // The "generate for" loop below isn't a normal loop that runs over time -
    // it's a copy-paste machine that stamps out 4 real macro instances when I build.
    // --------------------------------------------------------------------

    genvar i;                     // "genvar" is the counter for the generate loop. It only exists to build hardware.
    generate                      // start of the hardware-building block.
        for (i = 0; i < 4; i = i + 1) begin : lane   // make 4 copies (i = 0,1,2,3). I'm labelling each copy "lane".
                                                     // Each i is one byte lane of my 32-bit word.

            // The macro has a per-BIT write mask, WEN[7:0], and it's active-low (0 = write that bit).
            // I only ever write whole bytes, so for each lane it's all-write or all-skip.
            logic        lane_write;                 // does THIS byte lane actually get written this cycle?
            logic [7:0]  wen;                        // the 8-bit mask I'll hand this macro.

            assign lane_write = we & be[i];          // I write this byte only if I'm writing (we=1) AND this
                                                     // byte's enable is on (be[i]=1). "&" is AND.

            assign wen = lane_write ? 8'h00          // if I'm writing this byte: mask = 00000000 = "write all 8 bits".
                                    : 8'hFF;         // if not: mask = 11111111 = "write nothing" (remember, 1 = skip).
                                                     // "? :" is a mux: take the left value if true, right if false.
                                                     // 8'h00 means "8 bits, hex value 00"; 8'hFF is "8 bits, hex FF".

            // Now I drop in one real GF180 SRAM macro for this byte lane.
            // "gf180mcu_fd_ip_sram__sram512x8m8wm1" is the macro's exact name from the PDK.
            // "u_macro" is my name for this particular copy. ".PIN(signal)" wires each of the
            // macro's pins to one of my signals.
            gf180mcu_fd_ip_sram__sram512x8m8wm1 u_macro (
                .CLK (clk),                          // macro's clock <- my clk.
                .CEN (cen),                          // macro's chip-enable <- my inverted cs. All 4 lanes share this.
                .GWEN(gwen),                         // macro's write-direction <- my inverted we. All 4 lanes share this too.
                .WEN (wen),                          // macro's per-bit mask <- this lane's own mask (this one is per-lane).
                .A   (addr),                         // macro's address <- my addr. All 4 lanes look at the SAME box number.
                .D   (wdata[i*8 +: 8]),              // data going IN <- byte i of my 32-bit wdata.
                                                     //   "[i*8 +: 8]" means "8 bits starting at bit i*8".
                                                     //   So lane 0 = bits [7:0], lane 1 = [15:8], lane 2 = [23:16], lane 3 = [31:24].
                .Q   (rdata[i*8 +: 8])               // data coming OUT -> byte i of my rdata, sliced the same way.
                // I leave VDD/VSS (power and ground) unconnected here. That's fine for simulation -
                // the hardening tools hook up power physically later.
            );

        end : lane                // end of the loop body for this lane.
    endgenerate                   // end of the generate block.

endmodule                         // end of my module. That's the whole file.
