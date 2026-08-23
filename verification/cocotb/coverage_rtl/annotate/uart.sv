//      // verilator_coverage annotation
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
 103918     input  logic        clk,
 000039     input  logic        rst_n,
        
%000002     input  logic        sel,
%000002     input  logic        we,
%000002     input  logic [31:0] addr,       // NEW: I look at addr[2] to pick status vs data.
%000002     input  logic [31:0] wdata,
%000001     output logic [31:0] rdata,
        
%000004     output logic        tx,
%000003     input  logic        rx
        );
        
            localparam int BAUD_DIV = CLK_FREQ / BAUD_RATE;
        
            // ====================================================================
            // TX SIDE
            // ====================================================================
 000041     logic [$clog2(BAUD_DIV)-1:0] baud_cnt;
 000010     logic                        baud_tick;
%000001     logic                        tx_busy;
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             baud_cnt  <= '0;
 000038             baud_tick <= 1'b0;
 103837         end else if (tx_busy) begin
 000071             if (baud_cnt == BAUD_DIV-1) begin
 000010                 baud_cnt  <= '0;
 000010                 baud_tick <= 1'b1;
 000071             end else begin
 000071                 baud_cnt  <= baud_cnt + 1'b1;
 000071                 baud_tick <= 1'b0;
                    end
 103837         end else begin
 103837             baud_cnt  <= '0;
 103837             baud_tick <= 1'b0;
                end
            end
        
            typedef enum logic [1:0] {T_IDLE, T_START, T_DATA, T_STOP} tx_state_t;
%000002     tx_state_t tstate;
%000002     logic [7:0] tx_shift;
%000004     logic [2:0] tx_index;
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             tstate   <= T_IDLE;
 000038             tx       <= 1'b1;
 000038             tx_busy  <= 1'b0;
 000038             tx_shift <= 8'h0;
 000038             tx_index <= 3'h0;
 103918         end else begin
 103918             case (tstate)
 103837                 T_IDLE: begin
 103837                     tx <= 1'b1;
~103916                     if (sel && we) begin          // a write loads a byte to send.
%000001                         tx_shift <= wdata[7:0];
%000001                         tx_busy  <= 1'b1;
%000001                         tx_index <= 3'h0;
%000001                         tstate   <= T_START;
                            end
                        end
%000009                 T_START: begin
%000009                     tx <= 1'b0;
%000008                     if (baud_tick) tstate <= T_DATA;
                        end
 000064                 T_DATA: begin
 000064                     tx <= tx_shift[0];
~000056                     if (baud_tick) begin
%000008                         tx_shift <= {1'b0, tx_shift[7:1]};
%000007                         if (tx_index == 3'd7) tstate <= T_STOP;
%000007                         else                  tx_index <= tx_index + 1'b1;
                            end
                        end
%000008                 T_STOP: begin
%000008                     tx <= 1'b1;
%000007                     if (baud_tick) begin
%000001                         tx_busy <= 1'b0;
%000001                         tstate  <= T_IDLE;
                            end
                        end
                    endcase
                end
            end
        
            // ====================================================================
            // RX SIDE
            // ====================================================================
%000003     logic rx_sync1, rx_sync2;
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             rx_sync1 <= 1'b1;
 000038             rx_sync2 <= 1'b1;
 103918         end else begin
 103918             rx_sync1 <= rx;
 103918             rx_sync2 <= rx_sync1;
                end
            end
%000003     logic rx_in;
            assign rx_in = rx_sync2;
        
~000040     logic [$clog2(BAUD_DIV)-1:0] rx_cnt;
%000002     logic                        rx_active;
        
            typedef enum logic [1:0] {R_IDLE, R_START, R_DATA, R_STOP} rx_state_t;
%000003     rx_state_t rstate;
%000001     logic [7:0] rx_shift;
%000004     logic [2:0] rx_index;
%000001     logic [7:0] rx_data;
%000001     logic       rx_valid;
        
            // "read the DATA register" = selected, a read (we=0), and addr offset 4 (addr[2]=1).
%000000     logic data_read;
            assign data_read = sel && !we && addr[2];
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             rstate   <= R_IDLE;
 000038             rx_cnt   <= '0;
 000038             rx_index <= 3'h0;
 000038             rx_shift <= 8'h0;
 000038             rx_data  <= 8'h0;
 000038             rx_valid <= 1'b0;
 000038             rx_active<= 1'b0;
 103918         end else begin
                    // ONLY a DATA-register read clears rx_valid (the byte is consumed).
                    // A status read no longer clears it -> polling works.
~103918             if (data_read) rx_valid <= 1'b0;
        
 103918             case (rstate)
 103838                 R_IDLE: begin
 103838                     rx_cnt <= '0;
~103836                     if (rx_in == 1'b0) begin
%000002                         rstate    <= R_START;
%000002                         rx_active <= 1'b1;
                            end
                        end
%000008                 R_START: begin
%000006                     if (rx_cnt == (BAUD_DIV/2)-1) begin
%000002                         rx_cnt <= '0;
%000001                         if (rx_in == 1'b0) begin
%000001                             rstate   <= R_DATA;
%000001                             rx_index <= 3'h0;
%000001                         end else begin
%000001                             rstate    <= R_IDLE;
%000001                             rx_active <= 1'b0;
                                end
%000006                     end else rx_cnt <= rx_cnt + 1'b1;
                        end
 000064                 R_DATA: begin
~000056                     if (rx_cnt == BAUD_DIV-1) begin
%000008                         rx_cnt   <= '0;
%000008                         rx_shift <= {rx_in, rx_shift[7:1]};
%000007                         if (rx_index == 3'd7) rstate <= R_STOP;
%000007                         else                  rx_index <= rx_index + 1'b1;
 000056                     end else rx_cnt <= rx_cnt + 1'b1;
                        end
%000008                 R_STOP: begin
%000007                     if (rx_cnt == BAUD_DIV-1) begin
%000001                         rx_cnt    <= '0;
%000001                         rx_data   <= rx_shift;
%000001                         rx_valid  <= 1'b1;        // a byte arrived (overrides any clear this cycle).
%000001                         rx_active <= 1'b0;
%000001                         rstate    <= R_IDLE;
%000007                     end else rx_cnt <= rx_cnt + 1'b1;
                        end
                    endcase
                end
            end
        
            // ====================================================================
            // READ MUX: status vs data by addr[2].
            //   offset 0 (addr[2]=0) = STATUS: bit0=tx_busy, bit1=rx_valid. (peek, no clear)
            //   offset 4 (addr[2]=1) = DATA:   bits[7:0]=rx_data. (clears rx_valid, above)
            // ====================================================================
 103957     always_comb begin
~103957         if (addr[2])
%000000             rdata = {24'b0, rx_data};             // DATA register.
                else
 103957             rdata = {30'b0, rx_valid, tx_busy};   // STATUS register.
            end
        
        endmodule
        
