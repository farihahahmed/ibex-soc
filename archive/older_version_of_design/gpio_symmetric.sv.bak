// ============================================================================
// gpio.sv - my general-purpose I/O peripheral
//
// This is how my chip talks to the physical world:
//   OUTPUT pins - drive things like LEDs. The CPU writes a value, the pins follow.
//   INPUT pins  - read things like buttons. The CPU reads them.
//
// To the CPU this is just a memory-mapped register: writing my address sets the
// output pins, reading my address returns the current input pin values.
//
// The one careful bit: input pins come from OUTSIDE the chip, so they're async -
// a button can change right at a clock edge and make a flop go metastable (same
// problem as my reset). So I run every input through a 2-flop synchronizer before
// the CPU ever sees it. Same trick as rst_sync.
//
// I'm building 8 output pins and 8 input pins (I'll only wire some to real pads
// at hardening, but the logic supports 8 of each).
// ============================================================================

module gpio #(
    parameter int NUM_IO = 8            // how many pins each way. "parameter" = a
                                        // knob I can change when I instantiate this.
)(
    input  logic              clk,
    input  logic              rst_n,    // clean synchronized reset (from my rst_sync).

    // ---- simple bus interface (the bus will drive these) ----
    input  logic              sel,      // 1 = this access is for me (the bus decoded my address).
    input  logic              we,       // 1 = write (CPU -> my output register), 0 = read.
    input  logic [31:0]       wdata,    // data the CPU wants to write.
    output logic [31:0]       rdata,    // data I hand back on a read.

    // ---- the actual physical pins ----
    output logic [NUM_IO-1:0] gpio_out, // my output pins -> go to pads -> drive LEDs etc.
    input  logic [NUM_IO-1:0] gpio_in   // my input pins  <- come from pads <- buttons etc.
);

    // --------------------------------------------------------------------
    // 1) OUTPUT REGISTER.
    //    Holds the value the CPU last wrote. Its bits drive the output pins.
    //    Updates only when the CPU writes to me (sel=1 AND we=1).
    // --------------------------------------------------------------------
    logic [NUM_IO-1:0] out_reg;          // the register behind the output pins.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_reg <= '0;               // on reset, all output pins low. "'0" = all zeros.
        end else if (sel && we) begin
            out_reg <= wdata[NUM_IO-1:0]; // CPU wrote me -> latch the low NUM_IO bits.
        end
        // if not selected/writing, hold the current value (that's what a flop does).
    end

    assign gpio_out = out_reg;           // the register drives the physical output pins.

    // --------------------------------------------------------------------
    // 2) INPUT SYNCHRONIZER.
    //    Input pins are async (from the outside world), so I pass them through
    //    TWO flops before the CPU reads them. sync1 catches the raw pin (may go
    //    metastable), sync2 samples sync1 a cycle later (settled and clean).
    //    Same 2-flop idea as rst_sync, just on the data pins instead of reset.
    // --------------------------------------------------------------------
    logic [NUM_IO-1:0] sync1;            // first stage - may be metastable.
    logic [NUM_IO-1:0] sync2;            // second stage - clean, safe for the CPU to read.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= '0;
            sync2 <= '0;
        end else begin
            sync1 <= gpio_in;            // grab the raw async pins.
            sync2 <= sync1;              // one cycle later -> settled clean value.
        end
    end

    // --------------------------------------------------------------------
    // 3) READ DATA.
    //    When the CPU reads me, I return the synchronized input pins in the low
    //    bits and zeros in the upper bits (I only have NUM_IO real inputs).
    //    This is combinational - the bus reads it the same cycle it selects me.
    // --------------------------------------------------------------------
    assign rdata = {{(32-NUM_IO){1'b0}}, sync2};
                                         // "{{(32-NUM_IO){1'b0}}, sync2}" = pad sync2 up
                                         // to 32 bits with leading zeros.

endmodule
