// ============================================================================
// spi.sv - my SPI master (Mode 0). Talks to an LED/LCD/sensor over 4 wires.
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
// ============================================================================

module spi #(
    parameter int CLK_DIV = 4        // SCLK = system clock / (2*CLK_DIV). Slower than my clock.
)(
    input  logic        clk,
    input  logic        rst_n,

    // ---- register interface ----
    input  logic        sel,
    input  logic        we,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,

    // ---- SPI pins ----
    output logic        sclk,        // clock I drive to the slave.
    output logic        mosi,        // data out to the slave.
    input  logic        miso,        // data in from the slave.
    output logic        cs_n         // chip select, active low.
);

    // --------------------------------------------------------------------
    // Clock divider: SCLK toggles every CLK_DIV system-clock cycles (while busy).
    // That makes SCLK slow enough for the slave to follow.
    // --------------------------------------------------------------------
    logic [$clog2(CLK_DIV)-1:0] div_cnt;   // counts up to CLK_DIV.
    logic                        tick;      // pulses when it's time to toggle SCLK.
    logic                        busy;      // am I in a transfer?

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_cnt <= '0;
            tick    <= 1'b0;
        end else if (busy) begin
            if (div_cnt == CLK_DIV-1) begin
                div_cnt <= '0;
                tick    <= 1'b1;           // time to toggle the SPI clock.
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
    //   TRANSFER : pulse SCLK 8 times. On each falling edge drive next MOSI bit;
    //              on each rising edge sample MISO. Count 8 bits, then done.
    // --------------------------------------------------------------------
    typedef enum logic {IDLE, TRANSFER} state_t;
    state_t state;

    logic [7:0] tx_shift;            // byte going out (shifts left, MSB first).
    logic [7:0] rx_shift;            // byte coming in (shifts in from MISO).
    logic [3:0] bit_count;           // how many SCLK edges so far (0..16 = 8 bits x2 edges).
    logic       sclk_int;            // my internal SCLK level.
    logic [7:0] rx_data;             // the finished received byte.

    assign sclk = sclk_int;
    assign mosi = tx_shift[7];       // MSB first: always drive the top bit.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            busy      <= 1'b0;
            cs_n      <= 1'b1;        // deselected.
            sclk_int  <= 1'b0;        // Mode 0: idle low.
            tx_shift  <= 8'h0;
            rx_shift  <= 8'h0;
            rx_data   <= 8'h0;
            bit_count <= 4'h0;
        end else begin
            case (state)
                IDLE: begin
                    sclk_int <= 1'b0;
                    cs_n     <= 1'b1;
                    if (sel && we) begin        // CPU wrote a byte -> start a transfer.
                        tx_shift  <= wdata[7:0];
                        busy      <= 1'b1;
                        cs_n      <= 1'b0;       // select the slave.
                        bit_count <= 4'h0;
                        state     <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (tick) begin
                        sclk_int <= ~sclk_int;  // toggle the SPI clock.

                        if (~sclk_int) begin
                            // this tick drives SCLK LOW->HIGH = rising edge: SAMPLE MISO.
                            rx_shift <= {rx_shift[6:0], miso};
                        end else begin
                            // this tick drives SCLK HIGH->LOW = falling edge: SHIFT MOSI.
                            tx_shift <= {tx_shift[6:0], 1'b0};
                            bit_count <= bit_count + 1'b1;
                        end

                        // after 8 full bits (8 falling edges), finish.
                        if (bit_count == 4'd8) begin
                            state    <= IDLE;
                            busy     <= 1'b0;
                            cs_n     <= 1'b1;       // deselect.
                            sclk_int <= 1'b0;
                            rx_data  <= rx_shift;   // latch the received byte.
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
