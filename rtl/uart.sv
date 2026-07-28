// ============================================================================
// uart.sv - my UART with TX + RX. Now with SEPARATE status and data registers.
//
// THE FIX: before, ANY read cleared rx_valid. That broke polling - the same read
// that would show rx_valid=1 also cleared it, so software could never catch it.
// Real UARTs split this into two registers:
//   STATUS reg (offset 0): read PEEKS tx_busy/rx_valid - does NOT clear anything.
//   DATA   reg (offset 4): read returns rx_data AND clears rx_valid (byte consumed).
// So software polls STATUS until rx_valid=1, then reads DATA to get the byte.
//
// I pick status vs data using addr[2] (offset 0 vs 4 -> bit 2 is 0 vs 1).
//
// Writes (we=1) still load a byte into TX regardless of offset.
//
// Frame: idle high, start bit low, 8 data LSB-first, stop bit high.
// ============================================================================

module uart #(
    parameter int CLK_FREQ  = 10_000_000,
    parameter int BAUD_RATE = 115200
)(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        sel,
    input  logic        we,
    input  logic [31:0] addr,       // NEW: I look at addr[2] to pick status vs data.
    input  logic [31:0] wdata,
    output logic [31:0] rdata,

    output logic        tx,
    input  logic        rx
);

    localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;

    // ====================================================================
    // TX SIDE
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
                    if (sel && we) begin          // a write loads a byte to send.
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
    logic rx_sync1, rx_sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    logic rx_in;
    assign rx_in = rx_sync2;

    logic [$clog2(BAUD_DIV)-1:0] rx_cnt;
    logic                        rx_active;

    typedef enum logic [1:0] {R_IDLE, R_START, R_DATA, R_STOP} rx_state_t;
    rx_state_t rstate;
    logic [7:0] rx_shift;
    logic [2:0] rx_index;
    logic [7:0] rx_data;
    logic       rx_valid;

    // "read the DATA register" = selected, a read (we=0), and addr offset 4 (addr[2]=1).
    logic data_read;
    assign data_read = sel && !we && addr[2];

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
            // ONLY a DATA-register read clears rx_valid (the byte is consumed).
            // A status read no longer clears it -> polling works.
            if (data_read) rx_valid <= 1'b0;

            case (rstate)
                R_IDLE: begin
                    rx_cnt <= '0;
                    if (rx_in == 1'b0) begin
                        rstate    <= R_START;
                        rx_active <= 1'b1;
                    end
                end
                R_START: begin
                    if (rx_cnt == (BAUD_DIV/2)-1) begin
                        rx_cnt <= '0;
                        if (rx_in == 1'b0) begin
                            rstate   <= R_DATA;
                            rx_index <= 3'h0;
                        end else begin
                            rstate    <= R_IDLE;
                            rx_active <= 1'b0;
                        end
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                R_DATA: begin
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt   <= '0;
                        rx_shift <= {rx_in, rx_shift[7:1]};
                        if (rx_index == 3'd7) rstate <= R_STOP;
                        else                  rx_index <= rx_index + 1'b1;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
                R_STOP: begin
                    if (rx_cnt == BAUD_DIV-1) begin
                        rx_cnt    <= '0;
                        rx_data   <= rx_shift;
                        rx_valid  <= 1'b1;        // a byte arrived (overrides any clear this cycle).
                        rx_active <= 1'b0;
                        rstate    <= R_IDLE;
                    end else rx_cnt <= rx_cnt + 1'b1;
                end
            endcase
        end
    end

    // ====================================================================
    // READ MUX: status vs data by addr[2].
    //   offset 0 (addr[2]=0) = STATUS: bit0=tx_busy, bit1=rx_valid. (peek, no clear)
    //   offset 4 (addr[2]=1) = DATA:   bits[7:0]=rx_data. (clears rx_valid, above)
    // ====================================================================
    always_comb begin
        if (addr[2])
            rdata = {24'b0, rx_data};             // DATA register.
        else
            rdata = {30'b0, rx_valid, tx_busy};   // STATUS register.
    end

endmodule
