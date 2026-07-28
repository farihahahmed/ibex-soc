// ============================================================================
// uart.sv - my UART (serial port). Now with BOTH TX and RX.
//
// TX: send a byte one bit at a time. IDLE->START->DATA->STOP.
// RX: receive a byte someone else sends. The hard part: I don't control their
//     timing, so I detect the start bit, then sample each bit in the MIDDLE of
//     its bit-time (safest point, away from edges).
//
// The rx line comes from outside the chip (async), so I run it through a 2-flop
// synchronizer first - same metastability fix as my reset and gpio inputs.
//
// Register interface (bus wrapper drives it):
//   write we=1        -> load wdata[7:0] into TX, start sending.
//   read              -> status/data:
//        bit 0        = tx_busy   (1 = TX still sending)
//        bit 1        = rx_valid  (1 = a received byte is waiting)
//        bits [15:8]  = rx_data   (the received byte)
//   (reading clears rx_valid - the CPU has taken the byte.)
// ============================================================================

module uart #(
    parameter int CLK_FREQ  = 10_000_000,
    parameter int BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        sel,
    input  logic        we,
    input  logic [31:0] wdata,
    output logic [31:0] rdata,

    output logic        tx,         // serial out. Idles high.
    input  logic        rx          // serial in. Idles high.
);

    localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // ====================================================================
    // TX SIDE (unchanged from before)
    // ====================================================================
    logic [$clog2(BAUD_DIV)-1:0] baud_cnt;
    logic                        baud_tick;
    logic                        tx_busy;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end else if (tx_busy) begin
            if (baud_cnt == BAUD_DIV-1) begin
                baud_cnt  <= '0;
                baud_tick <= 1'b1;
            end else begin
                baud_cnt  <= baud_cnt + 1'b1;
                baud_tick <= 1'b0;
            end
        end else begin
            baud_cnt  <= '0;
            baud_tick <= 1'b0;
        end
    end

    typedef enum logic [1:0] {T_IDLE, T_START, T_DATA, T_STOP} tx_state_t;
    tx_state_t tstate;
    logic [7:0] tx_shift;
    logic [2:0] tx_index;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tstate   <= T_IDLE;
            tx       <= 1'b1;
            tx_busy  <= 1'b0;
            tx_shift <= 8'h0;
            tx_index <= 3'h0;
        end else begin
            case (tstate)
                T_IDLE: begin
                    tx <= 1'b1;
                    if (sel && we) begin
                        tx_shift <= wdata[7:0];
                        tx_busy  <= 1'b1;
                        tx_index <= 3'h0;
                        tstate   <= T_START;
                    end
                end
                T_START: begin
                    tx <= 1'b0;
                    if (baud_tick) tstate <= T_DATA;
                end
                T_DATA: begin
                    tx <= tx_shift[0];
                    if (baud_tick) begin
                        tx_shift <= {1'b0, tx_shift[7:1]};
                        if (tx_index == 3'd7) tstate <= T_STOP;
                        else                  tx_index <= tx_index + 1'b1;
                    end
                end
                T_STOP: begin
                    tx <= 1'b1;
                    if (baud_tick) begin
                        tx_busy <= 1'b0;
                        tstate  <= T_IDLE;
                    end
                end
            endcase
        end
    end

    // ====================================================================
    // RX SIDE
    // ====================================================================

    // 1) Synchronize the async rx line through 2 flops.
    logic rx_sync1, rx_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;    // idle high.
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    logic rx_in;
    assign rx_in = rx_sync2;     // the clean, synchronized rx line I actually use.

    // 2) A separate baud counter for RX (it runs on the incoming frame's timing,
    //    independent of TX). I need to hit half-bit and full-bit points.
    logic [$clog2(BAUD_DIV)-1:0] rx_cnt;
    logic                        rx_active;   // am I in the middle of receiving?

    typedef enum logic [1:0] {R_IDLE, R_START, R_DATA, R_STOP} rx_state_t;
    rx_state_t rstate;
    logic [7:0] rx_shift;
    logic [2:0] rx_index;
    logic [7:0] rx_data;        // the finished received byte.
    logic       rx_valid;       // 1 = a byte is waiting for the CPU.

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rstate   <= R_IDLE;
            rx_cnt   <= '0;
            rx_index <= 3'h0;
            rx_shift <= 8'h0;
            rx_data  <= 8'h0;
            rx_valid <= 1'b0;
            rx_active<= 1'b0;
        end else begin
            // reading the register clears rx_valid (CPU took the byte).
            if (sel && !we) rx_valid <= 1'b0;

            case (rstate)
                R_IDLE: begin
                    rx_cnt <= '0;
                    if (rx_in == 1'b0) begin      // line dropped -> possible start bit.
                        rstate    <= R_START;
                        rx_active <= 1'b1;
                    end
                end

                R_START: begin
                    // wait HALF a bit-time to reach the center of the start bit.
                    if (rx_cnt == (BAUD_DIV/2)-1) begin
                        rx_cnt <= '0;
                        if (rx_in == 1'b0) begin  // still low? -> real start.
                            rstate   <= R_DATA;
                            rx_index <= 3'h0;
                        end else begin
                            rstate    <= R_IDLE;  // was noise, bail out.
                            rx_active <= 1'b0;
                        end
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end

                R_DATA: begin
                    // wait a FULL bit-time between samples; sample at each center.
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt <= '0;
                        rx_shift <= {rx_in, rx_shift[7:1]};   // shift in, LSB first.
                        if (rx_index == 3'd7) rstate <= R_STOP;
                        else                  rx_index <= rx_index + 1'b1;
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end

                R_STOP: begin
                    // wait one more full bit-time for the stop bit, then finish.
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt    <= '0;
                        rx_data   <= rx_shift;    // the assembled byte.
                        rx_valid  <= 1'b1;        // tell the CPU a byte arrived.
                        rx_active <= 1'b0;
                        rstate    <= R_IDLE;
                    end else begin
                        rx_cnt <= rx_cnt + 1'b1;
                    end
                end
            endcase
        end
    end

    // ====================================================================
    // STATUS / DATA READ.
    //   bit 0       = tx_busy
    //   bit 1       = rx_valid
    //   bits [15:8] = rx_data
    // ====================================================================
    assign rdata = {16'b0, rx_data, 6'b0, rx_valid, tx_busy};

endmodule
