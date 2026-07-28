// ============================================================================
// apb_decoder.sv - my APB decoder / fan-out for multiple APB peripherals
//
// The bridge gives me ONE APB stream (PSEL/PENABLE/PADDR/PWDATA...). I fan it
// out to several APB peripherals and assert only the addressed one's PSEL, then
// mux that peripheral's PRDATA/PREADY back to the bridge.
//
// This is like my AHB interconnect but SIMPLER - APB has no pipelining, so the
// selection is purely combinational (no registered-selection trick needed).
//
// I decode PADDR[17:16] to match my memory map:
//   01 = GPIO (0x0001_xxxx)
//   10 = UART (0x0002_xxxx)
//   11 = SPI  (0x0003_xxxx)
// (00 would be memory, but memory is on AHB, not here - so 00 selects nobody.)
//
// PENABLE/PWRITE/PADDR/PWDATA are broadcast to all peripherals; only the one
// with its PSEL high acts.
// ============================================================================

module apb_decoder (
    // ---- from the bridge (single APB master stream) ----
    input  logic        PSEL,          // bridge says "an APB access is happening".
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    output logic [31:0] PRDATA,         // muxed read data back to the bridge.
    output logic        PREADY,         // muxed ready back to the bridge.

    // ---- to/from peripheral 1: GPIO ----
    output logic        gpio_PSEL,
    input  logic [31:0] gpio_PRDATA,
    input  logic        gpio_PREADY,

    // ---- to/from peripheral 2: UART ----
    output logic        uart_PSEL,
    input  logic [31:0] uart_PRDATA,
    input  logic        uart_PREADY,

    // ---- to/from peripheral 3: SPI ----
    output logic        spi_PSEL,
    input  logic [31:0] spi_PRDATA,
    input  logic        spi_PREADY,

    // ---- shared signals broadcast to all peripherals ----
    output logic        p_PENABLE,
    output logic        p_PWRITE,
    output logic [31:0] p_PADDR,
    output logic [31:0] p_PWDATA
);

    // broadcast the common signals to every peripheral.
    assign p_PENABLE = PENABLE;
    assign p_PWRITE  = PWRITE;
    assign p_PADDR   = PADDR;
    assign p_PWDATA  = PWDATA;

    // which peripheral does this address pick?
    logic [1:0] region;
    assign region = PADDR[17:16];       // 01=GPIO, 10=UART, 11=SPI.

    // DECODE: assert exactly one peripheral's PSEL, only when the bridge has
    // PSEL high (a real APB access). Otherwise nobody is selected.
    always_comb begin
        gpio_PSEL = 1'b0;
        uart_PSEL = 1'b0;
        spi_PSEL  = 1'b0;
        if (PSEL) begin
            case (region)
                2'b01: gpio_PSEL = 1'b1;
                2'b10: uart_PSEL = 1'b1;
                2'b11: spi_PSEL  = 1'b1;
                default: ;              // 00 or unmapped -> nobody.
            endcase
        end
    end

    // MUX the response back to the bridge based on the same region.
    always_comb begin
        case (region)
            2'b01:   begin PRDATA = gpio_PRDATA; PREADY = gpio_PREADY; end
            2'b10:   begin PRDATA = uart_PRDATA; PREADY = uart_PREADY; end
            2'b11:   begin PRDATA = spi_PRDATA;  PREADY = spi_PREADY;  end
            default: begin PRDATA = 32'h0;       PREADY = 1'b1;        end
        endcase
    end

endmodule
