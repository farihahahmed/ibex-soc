//      // verilator_coverage annotation
        // ============================================================================
        // rst_sync.sv - my reset synchronizer
        //
        // The problem this solves: my reset comes from outside the chip (a pin, a button,
        // a power-on circuit). That signal has no idea when my clock ticks, so it can be
        // released (0->1) at the exact worst moment - right on a clock edge. When that
        // happens, a flip-flop can't decide between "still reset" and "not reset" and goes
        // METASTABLE: its output floats at some undefined voltage and settles randomly.
        // If that garbage fans out, different parts of my chip leave reset in different
        // states. Nasty, non-reproducible, silicon-only bugs.
        //
        // The fix: run the reset through TWO flip-flops on my clock. Flop 1 might go
        // metastable, but it gets a whole cycle to settle before flop 2 samples it, so
        // flop 2's output is clean and lined up with my clock.
        //
        // Style note to self: this is "async assert, sync de-assert". Reset going ACTIVE
        // happens instantly (I want everything to stop NOW). Reset RELEASING comes out
        // cleanly on a clock edge (that's the part that needs synchronizing).
        // ============================================================================
        
        module rst_sync (
 029117     input  logic clk,          // my system clock. Both flops run on this.
%000005     input  logic rst_n_in,     // the raw reset coming in from outside (active-low, async).
%000005     output logic rst_n_out     // the clean, synchronized reset going out to the rest of the chip.
        );
        
%000005     logic sync_ff1;            // first flip-flop. This one catches the async reset and may go metastable.
%000005     logic sync_ff2;            // second flip-flop. Samples flop1 a cycle later, once it's settled. This is my clean output.
        
            // The synchronizer itself. This block wakes up on EITHER a rising clock edge
            // OR reset going low ("negedge rst_n_in") - that "or negedge" is what makes the
            // ASSERT asynchronous (instant), no waiting for a clock.
 029121     always_ff @(posedge clk or negedge rst_n_in) begin
 029017         if (!rst_n_in) begin
                    // reset is asserted (rst_n_in went low): slam both flops to 0 immediately.
                    // This is the async-assert part - happens the instant reset drops.
 000104             sync_ff1 <= 1'b0;
 000104             sync_ff2 <= 1'b0;
 029017         end else begin
                    // reset is released: shift a 1 through the two flops, one cycle each.
                    // flop1 goes high this cycle...
 029017             sync_ff1 <= 1'b1;
                    // ...and flop2 copies flop1 next cycle. That extra cycle is what lets any
                    // metastability on flop1 settle out before it reaches my clean output.
 029017             sync_ff2 <= sync_ff1;
                end
            end
        
            assign rst_n_out = sync_ff2;   // my clean, glitch-free, clock-synchronized reset.
        
        endmodule
        
        
