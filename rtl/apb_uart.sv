// ============================================================================
// apb_uart.sv - my APB slave wrapper around the uart module
//
// Puts the UART on the APB bus (behind the ahb_to_apb bridge), at 0x0002_0000.
// Same pattern as apb_gpio: the ACCESS phase (PSEL & PENABLE) is when a real
// read/write happens, so I turn that into the uart's sel/we.
//
// UART is fast to respond (its registers are simple), so PREADY is always 1.
// The tx/rx serial pins pass straight through to the chip's outside world.
//
// Reads return the uart status/data word:
//   bit 0 = tx_busy, bit 1 = rx_valid, bits[15:8] = rx_data.
// Writes load a byte into the transmitter.
// ============================================================================

module apb_uart #(
    parameter int CLK_FREQ  = 10_000_000,
    parameter int BAUD_RATE = 115200
)(
    input  logic        PCLK,
    input  logic        PRESETn,

    // ---- APB slave interface ----
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic        PREADY,

    // ---- serial pins (to the outside world) ----
    output logic        tx,
    input  logic        rx
);

    assign PREADY = 1'b1;              // zero-wait: always ready.

    // ACCESS phase = both PSEL and PENABLE high = do the real read/write.
    logic access_phase;
    assign access_phase = PSEL & PENABLE;

    // Map the APB access onto the uart's simple interface.
    logic        uart_sel;
    logic        uart_we;
    logic [31:0] uart_rdata;

    assign uart_sel = access_phase;                 // selected during access phase.
    assign uart_we  = access_phase & PWRITE;        // write only on a write access.

    uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart (
        .clk   (PCLK),
        .rst_n (PRESETn),
        .sel   (uart_sel),
        .we    (uart_we),
        .wdata (PWDATA),              // APB write data -> uart (byte in [7:0]).
        .rdata (uart_rdata),         // uart status/data comes back here.
        .tx    (tx),                 // serial out pin.
        .rx    (rx)                  // serial in pin.
    );

    assign PRDATA = uart_rdata;      // uart read data -> APB read data.

endmodule
