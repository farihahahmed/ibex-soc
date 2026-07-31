// ============================================================================
// ahb_gpio.sv - my AHB-Lite slave wrapper around the plain gpio module
//
// My gpio module speaks a simple sel/we/wdata/rdata interface. But the bus speaks
// AHB. This wrapper is the translator on the SLAVE side: AHB signals come in from
// the interconnect, I turn them into gpio's simple signals, and hand AHB responses
// back out.
//
// The AHB timing thing again: HSEL/HADDR/HWRITE arrive in the ADDRESS phase, but
// the write DATA (HWDATA) and the read happen in the DATA phase, one cycle later.
// So I register the address-phase control, then act on it in the data phase.
//
// This is a "zero-wait-state" slave: I'm always ready, so HREADY is always 1.
// ============================================================================

module ahb_gpio #(
    parameter int NUM_OUT = 5,
    parameter int NUM_IN  = 2
)(
    input  logic        HCLK,
    input  logic        HRESETn,

    // ---- AHB-Lite slave interface (from the interconnect) ----
    input  logic        HSEL,          // 1 = the decoder picked me this cycle (address phase).
    input  logic [31:0] HADDR,         // address (I only have a few registers, so I mostly ignore it).
    input  logic [1:0]  HTRANS,        // transfer type - bit[1]=1 means real.
    input  logic        HWRITE,        // 1 = write, 0 = read.
    input  logic [31:0] HWDATA,        // write data (arrives in the data phase).
    output logic [31:0] HRDATA,        // read data (I drive this in the data phase).
    output logic        HREADY,        // 1 = I'm done. I'm always ready -> always 1.
    output logic        HRESP,         // 0 = OKAY. I never error.

    // ---- the actual pins ----
    output logic [NUM_OUT-1:0] gpio_out,
    input  logic [NUM_IN-1:0]  gpio_in
);

    // I'm always ready and never error.
    assign HREADY = 1'b1;
    assign HRESP  = 1'b0;

    // --------------------------------------------------------------------
    // Register the address-phase control so I can use it in the data phase.
    // "Was I selected for a real WRITE this cycle?" -> remember it for next cycle,
    // because that's when HWDATA shows up.
    // --------------------------------------------------------------------
    logic write_phase;                 // next cycle, is it a write to me?
    logic read_phase;                  // next cycle, is it a read from me?

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            write_phase <= 1'b0;
            read_phase  <= 1'b0;
        end else begin
            // capture the address-phase decision for use in the data phase.
            write_phase <= HSEL & HTRANS[1] &  HWRITE;   // selected, real, write.
            read_phase  <= HSEL & HTRANS[1] & ~HWRITE;   // selected, real, read.
        end
    end

    // --------------------------------------------------------------------
    // Drive the plain gpio module's simple interface.
    //   - On a write, in the DATA phase, I pulse sel+we with HWDATA.
    //   - On a read, gpio's rdata is combinational, so I can grab it any time;
    //     I select it in the data phase and register nothing extra.
    // --------------------------------------------------------------------
    logic        gpio_sel;
    logic        gpio_we;
    logic [31:0] gpio_rdata;

    assign gpio_we  = write_phase;                 // write into gpio during the data phase.
    assign gpio_sel = write_phase | read_phase;    // selected for either.

    gpio #(.NUM_OUT(NUM_OUT), .NUM_IN(NUM_IN)) u_gpio (
        .clk   (HCLK),
        .rst_n (HRESETn),
        .sel   (gpio_sel),
        .we    (gpio_we),
        .wdata (HWDATA),               // AHB write data feeds gpio's wdata.
        .rdata (gpio_rdata),           // gpio's read data comes back here.
        .gpio_out(gpio_out),
        .gpio_in (gpio_in)
    );

    // Read data back to the bus. gpio_rdata is valid combinationally when selected.
    assign HRDATA = gpio_rdata;

endmodule
