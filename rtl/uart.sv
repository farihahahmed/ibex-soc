// ============================================================================
// uart.sv - my UART (serial port). TX first; RX added later.
//
// UART sends a byte one bit at a time down a single wire. No shared clock with
// the other end - both sides just agree on a BAUD RATE (bits per second) and a
// FRAME format:
//   idle = line HIGH
//   start bit = line LOW for 1 bit-time  (tells the receiver a byte is coming)
//   8 data bits, LSB first, 1 bit-time each
//   stop bit = line HIGH for 1 bit-time  (marks the end)
// So one byte = a 10-bit frame (1 start + 8 data + 1 stop).
//
// Two pieces in here:
//   1. Baud generator - divides my fast clock down to "one tick per bit-time".
//   2. TX state machine - IDLE -> START -> DATA(x8) -> STOP -> IDLE, shifting the
//      byte out one bit per baud tick.
//
// Simple register interface (the bus wrapper will drive it):
//   write with we=1 -> load a byte into TX and start sending.
//   read  -> status: bit 0 = tx_busy (1 = still sending, don't write yet).
// ============================================================================

module uart #(
    parameter int CLK_FREQ  = 10_000_000,   // my system clock in Hz.
    parameter int BAUD_RATE = 115200        // bits per second.
)(
    input  logic        clk,
    input  logic        rst_n,

    // ---- simple register interface ----
    input  logic        sel,        // this access is for me.
    input  logic        we,         // 1 = write (load a byte to send), 0 = read (status).
    input  logic [31:0] wdata,      // byte to send is in wdata[7:0].
    output logic [31:0] rdata,      // status read.

    // ---- serial pin ----
    output logic        tx          // the TX wire. Idles high.
);

    // How many clock cycles is one bit-time? e.g. 10MHz / 115200 = 87 cycles.
    localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // --------------------------------------------------------------------
    // 1) BAUD GENERATOR. Count clock cycles; every BAUD_DIV cycles, pulse
    //    "baud_tick" high for one cycle. That tick paces the TX bits.
    //    I only run it while transmitting (saves it free-running when idle).
    // --------------------------------------------------------------------
    logic [$clog2(BAUD_DIV)-1:0] baud_cnt;   // counter wide enough to hold BAUD_DIV.
    logic                        baud_tick;  // 1 for one cycle each bit-time.
    logic                        tx_busy;    // am I currently sending?

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end else if (tx_busy) begin
            if (baud_cnt == BAUD_DIV-1) begin
                baud_cnt  <= '0;
                baud_tick <= 1'b1;           // one bit-time elapsed -> tick.
            end else begin
                baud_cnt  <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            baud_cnt  <= '0;                 // reset counter when idle.
            baud_tick <= 1'b0;
        end
    end

    // --------------------------------------------------------------------
    // 2) TX STATE MACHINE.
    //    IDLE  : line high, waiting. When the CPU writes a byte, latch it and go.
    //    START : drive line low for one bit-time (the start bit).
    //    DATA  : shift out 8 bits, LSB first, one per baud tick.
    //    STOP  : drive line high for one bit-time (the stop bit), then IDLE.
    // --------------------------------------------------------------------
    typedef enum logic [1:0] {IDLE, START, DATA, STOP} tx_state_t;
    tx_state_t state;

    logic [7:0] shift_reg;          // holds the byte while I shift it out.
    logic [2:0] bit_index;          // which data bit I'm on (0..7).

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            tx        <= 1'b1;       // idle high.
            tx_busy   <= 1'b0;
            shift_reg <= 8'h0;
            bit_index <= 3'h0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;                      // keep line high while idle.
                    if (sel && we) begin             // CPU wrote a byte -> start sending.
                        shift_reg <= wdata[7:0];     // latch the byte.
                        tx_busy   <= 1'b1;           // now busy (also kicks the baud gen).
                        bit_index <= 3'h0;
                        state     <= START;
                    end
                end

                START: begin
                    tx <= 1'b0;                      // start bit = low.
                    if (baud_tick) state <= DATA;    // after one bit-time, send data.
                end

                DATA: begin
                    tx <= shift_reg[0];              // drive the current LSB.
                    if (baud_tick) begin
                        shift_reg <= {1'b0, shift_reg[7:1]};  // shift right -> next bit to LSB.
                        if (bit_index == 3'd7)
                            state <= STOP;           // sent all 8 bits.
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                end

                STOP: begin
                    tx <= 1'b1;                      // stop bit = high.
                    if (baud_tick) begin
                        tx_busy <= 1'b0;             // done sending.
                        state   <= IDLE;
                    end
                end
            endcase
        end
    end

    // --------------------------------------------------------------------
    // 3) STATUS READ. bit 0 = tx_busy (1 = still sending). CPU polls this before
    //    writing the next byte.
    // --------------------------------------------------------------------
    assign rdata = {31'b0, tx_busy};

endmodule
