// ============================================================================
// apb_gpio.sv - my APB slave wrapper around the plain gpio module
//
// This replaces ahb_gpio in the two-tier design. Now GPIO sits on the APB bus
// (behind the ahb_to_apb bridge) instead of directly on AHB. APB is simpler than
// AHB, so this wrapper is simpler than the AHB one was.
//
// APB transfer, from the slave's point of view:
//   SETUP  : PSEL=1, PENABLE=0  -> master is presenting address/control.
//   ACCESS : PSEL=1, PENABLE=1  -> the actual read/write happens THIS cycle.
// I do the real work in the ACCESS phase (PSEL & PENABLE both high).
//
// GPIO is fast, so I never need to stall -> PREADY is always 1.
// ============================================================================

module apb_gpio #(
    parameter int NUM_OUT = 5,
    parameter int NUM_IN  = 2
)(
    input  logic        PCLK,          // APB clock (same system clock).
    input  logic        PRESETn,       // APB reset, active-low.

    // ---- APB slave interface (the bridge drives these) ----
    input  logic        PSEL,          // selected.
    input  logic        PENABLE,       // 0 = setup, 1 = access.
    input  logic        PWRITE,        // write vs read.
    input  logic [31:0] PADDR,         // address (I have few registers, mostly ignore it).
    input  logic [31:0] PWDATA,        // write data.
    output logic [31:0] PRDATA,        // read data.
    output logic        PREADY,        // I'm done. Always 1 (GPIO is fast).

    // ---- the pins ----
    output logic [NUM_OUT-1:0] gpio_out,
    input  logic [NUM_IN-1:0]  gpio_in
);

    assign PREADY = 1'b1;              // zero-wait: I'm always ready.

    // The ACCESS phase is when PSEL and PENABLE are both high. That's when a real
    // read or write actually takes effect.
    logic access_phase;
    assign access_phase = PSEL & PENABLE;

    // Turn the APB access into my plain gpio module's simple sel/we.
    logic        gpio_sel;
    logic        gpio_we;
    logic [31:0] gpio_rdata;

    assign gpio_sel = access_phase;               // select gpio during the access phase.
    assign gpio_we  = access_phase & PWRITE;      // write only if it's a write access.

    gpio #(.NUM_OUT(NUM_OUT), .NUM_IN(NUM_IN)) u_gpio (
        .clk   (PCLK),
        .rst_n (PRESETn),
        .sel   (gpio_sel),
        .we    (gpio_we),
        .wdata (PWDATA),               // APB write data -> gpio.
        .rdata (gpio_rdata),           // gpio read data comes back here.
        .gpio_out(gpio_out),
        .gpio_in (gpio_in)
    );

    assign PRDATA = gpio_rdata;        // gpio read data -> APB read data.

endmodule
