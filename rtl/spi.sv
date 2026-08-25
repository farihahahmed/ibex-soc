// ============================================================================
// spi.sv - SPI master (Mode 0). Talks to an LED/LCD/sensor over 4 wires.
//
// SPI is SYNCHRONOUS: I generate the clock (SCLK), and both sides shift on it.
// No baud-rate guessing like UART - the clock line itself marks each bit.
//
// 4 wires:
//   SCLK - clock I drive.
//   MOSI - Master Out Slave In: my data going out.
//   MISO - Master In Slave Out: data coming back.
//   CS   - chip select, active LOW: "slave, I'm talking to you".
//
// Every transfer is a SIMULTANEOUS exchange: each SCLK pulse I shift one bit OUT
// on MOSI and sample one bit IN on MISO. 8 pulses = one byte each way.
//
// Mode 0 (the common one): SCLK idles LOW. I change MOSI on the falling edge and
// sample MISO on the rising edge. So data is stable when the slave reads it.
//
// Register interface:
//   write we=1 -> load wdata[7:0] into TX and start a transfer.
//   read       -> bit0 = busy (1 = transfer in progress), bits[15:8] = last RX byte.
//
// FIX: bit counting / termination was off-by-one (NBA on bit_count). Now we
// count on the rising edge (sample) and finish cleanly after the 8th sample.
// ============================================================================

module spi #(
    parameter int CLK_DIV = 4        // SCLK = system clock / (2*CLK_DIV)
)(
    input  logic        clk,
    input  logic        rst_n,

    // ---- register interface ----
    input  logic        sel,
    input  logic        we,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,

    // ---- SPI pins ----
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        cs_n
);

    // --------------------------------------------------------------------
    // Clock divider: SCLK toggles every CLK_DIV system-clock cycles (while busy).
    // --------------------------------------------------------------------
    logic [$clog2(CLK_DIV)-1:0] div_cnt;
    logic                        tick;
    logic                        busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end else if (busy) begin
            if (div_cnt == CLK_DIV-1) begin
                div_cnt <= '0;
                tick    <= 1'b1;
            end else begin
                div_cnt <= div_cnt + 1'b1;
                tick    <= 1'b0;
            end
        end else begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end
    end

    // --------------------------------------------------------------------
    // Transfer state machine + shift registers.
    //   IDLE     : CS high, SCLK low, waiting. On a write, load TX and start.
    //   TRANSFER : 8 rising edges sample MISO, 8 falling edges shift MOSI.
    //              Finish immediately after the 8th sample.
    // --------------------------------------------------------------------
    typedef enum logic {IDLE, TRANSFER} state_t;
    state_t state;

    logic [7:0] tx_shift;
    logic [7:0] rx_shift;
    logic [3:0] bit_count;
    logic       sclk_int;
    logic [7:0] rx_data;

    assign sclk = sclk_int;
    assign mosi = tx_shift[7];       // MSB first

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            busy      <= 1'b0;
            cs_n      <= 1'b1;
            sclk_int  <= 1'b0;
            tx_shift  <= 8'h0;
            rx_shift  <= 8'h0;
            rx_data   <= 8'h0;
            bit_count <= 4'h0;
        end else begin
            case (state)
                IDLE: begin
                    sclk_int <= 1'b0;
                    cs_n     <= 1'b1;
                    if (sel && we) begin
                        tx_shift  <= wdata[7:0];
                        busy      <= 1'b1;
                        cs_n      <= 1'b0;
                        bit_count <= 4'h0;
                        state     <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (tick) begin
                        sclk_int <= ~sclk_int;

                        if (~sclk_int) begin
                            // Rising edge → sample MISO
                            rx_shift <= {rx_shift[6:0], miso};

                            if (bit_count == 4'd7) begin
                                // 8th sample just captured → done
                                state    <= IDLE;
                                busy     <= 1'b0;
                                cs_n     <= 1'b1;
                                sclk_int <= 1'b0;
                                rx_data  <= {rx_shift[6:0], miso};
                            end else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end else begin
                            // Falling edge → shift next MOSI bit
                            tx_shift <= {tx_shift[6:0], 1'b0};
                        end
                    end
                end
            endcase
        end
    end

    // --------------------------------------------------------------------
    // Read: bit 0 = busy, bits[15:8] = last received byte.
    // --------------------------------------------------------------------
    assign rdata = {16'b0, rx_data, 7'b0, busy};

endmodule
