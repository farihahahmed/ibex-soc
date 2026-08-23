//      // verilator_coverage annotation
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
 103918     input  logic        clk,
 000039     input  logic        rst_n,
        
            // ---- register interface ----
%000002     input  logic        sel,
%000002     input  logic        we,
%000002     input  logic [31:0] wdata,
%000001     output logic [31:0] rdata,
        
            // ---- SPI pins ----
%000008     output logic        sclk,        // clock I drive to the slave.
%000003     output logic        mosi,        // data out to the slave.
%000000     input  logic        miso,        // data in from the slave.
%000002     output logic        cs_n         // chip select, active low.
        );
        
            // --------------------------------------------------------------------
            // Clock divider: SCLK toggles every CLK_DIV system-clock cycles (while busy).
            // That makes SCLK slow enough for the slave to follow.
            // --------------------------------------------------------------------
 000018     logic [$clog2(CLK_DIV)-1:0] div_cnt;   // counts up to CLK_DIV.
 000017     logic                        tick;      // pulses when it's time to toggle SCLK.
%000001     logic                        busy;      // am I in a transfer?
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             div_cnt <= '0;
 000038             tick    <= 1'b0;
 103883         end else if (busy) begin
 000018             if (div_cnt == CLK_DIV-1) begin
 000017                 div_cnt <= '0;
 000017                 tick    <= 1'b1;           // time to toggle the SPI clock.
 000018             end else begin
 000018                 div_cnt <= div_cnt + 1'b1;
 000018                 tick    <= 1'b0;
                    end
 103883         end else begin
 103883             div_cnt <= '0;
 103883             tick    <= 1'b0;
                end
            end
        
            // --------------------------------------------------------------------
            // Transfer state machine + shift registers.
            //   IDLE     : CS high, SCLK low, waiting. On a write, load TX and start.
            //   TRANSFER : pulse SCLK 8 times. On each falling edge drive next MOSI bit;
            //              on each rising edge sample MISO. Count 8 bits, then done.
            // --------------------------------------------------------------------
            typedef enum logic {IDLE, TRANSFER} state_t;
%000001     state_t state;
        
%000003     logic [7:0] tx_shift;            // byte going out (shifts left, MSB first).
%000000     logic [7:0] rx_shift;            // byte coming in (shifts in from MISO).
%000004     logic [3:0] bit_count;           // how many SCLK edges so far (0..16 = 8 bits x2 edges).
%000008     logic       sclk_int;            // my internal SCLK level.
%000000     logic [7:0] rx_data;             // the finished received byte.
        
            assign sclk = sclk_int;
            assign mosi = tx_shift[7];       // MSB first: always drive the top bit.
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             state     <= IDLE;
 000038             busy      <= 1'b0;
 000038             cs_n      <= 1'b1;        // deselected.
 000038             sclk_int  <= 1'b0;        // Mode 0: idle low.
 000038             tx_shift  <= 8'h0;
 000038             rx_shift  <= 8'h0;
 000038             rx_data   <= 8'h0;
 000038             bit_count <= 4'h0;
 103918         end else begin
 103918             case (state)
 103883                 IDLE: begin
 103883                     sclk_int <= 1'b0;
 103883                     cs_n     <= 1'b1;
~103916                     if (sel && we) begin        // CPU wrote a byte -> start a transfer.
%000001                         tx_shift  <= wdata[7:0];
%000001                         busy      <= 1'b1;
%000001                         cs_n      <= 1'b0;       // select the slave.
%000001                         bit_count <= 4'h0;
%000001                         state     <= TRANSFER;
                            end
                        end
        
 000035                 TRANSFER: begin
 000018                     if (tick) begin
~000017                         sclk_int <= ~sclk_int;  // toggle the SPI clock.
        
%000009                         if (~sclk_int) begin
                                    // this tick drives SCLK LOW->HIGH = rising edge: SAMPLE MISO.
%000009                             rx_shift <= {rx_shift[6:0], miso};
%000008                         end else begin
                                    // this tick drives SCLK HIGH->LOW = falling edge: SHIFT MOSI.
%000008                             tx_shift <= {tx_shift[6:0], 1'b0};
%000008                             bit_count <= bit_count + 1'b1;
                                end
        
                                // after 8 full bits (8 falling edges), finish.
~000016                         if (bit_count == 4'd8) begin
%000001                             state    <= IDLE;
%000001                             busy     <= 1'b0;
%000001                             cs_n     <= 1'b1;       // deselect.
%000001                             sclk_int <= 1'b0;
%000001                             rx_data  <= rx_shift;   // latch the received byte.
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
        
