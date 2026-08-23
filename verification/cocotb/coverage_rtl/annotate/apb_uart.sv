//      // verilator_coverage annotation
        // ============================================================================
        // apb_uart.sv - APB slave wrapper around the uart module.
        //
        // Now passes PADDR through to the uart, because the uart uses addr[2] to pick
        // its STATUS register (offset 0) vs DATA register (offset 4).
        //   read offset 0 -> status (tx_busy, rx_valid) - peek, no clear
        //   read offset 4 -> data (rx_data) - clears rx_valid
        //   write         -> load a byte into TX
        // ============================================================================
        
        module apb_uart #(
            parameter int CLK_FREQ  = 10_000_000,
            parameter int BAUD_RATE = 115200
        )(
 103918     input  logic        PCLK,
 000039     input  logic        PRESETn,
        
%000002     input  logic        PSEL,
%000006     input  logic        PENABLE,
%000001     input  logic        PWRITE,
%000002     input  logic [31:0] PADDR,
%000002     input  logic [31:0] PWDATA,
%000001     output logic [31:0] PRDATA,
%000001     output logic        PREADY,
        
%000004     output logic        tx,
%000003     input  logic        rx
        );
        
            assign PREADY = 1'b1;
        
%000002     logic access_phase;
            assign access_phase = PSEL & PENABLE;
        
%000002     logic        uart_sel;
%000002     logic        uart_we;
%000001     logic [31:0] uart_rdata;
        
            assign uart_sel = access_phase;
            assign uart_we  = access_phase & PWRITE;
        
            uart #(.CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE)) u_uart (
                .clk   (PCLK),
                .rst_n (PRESETn),
                .sel   (uart_sel),
                .we    (uart_we),
                .addr  (PADDR),               // pass address through (uart uses addr[2]).
                .wdata (PWDATA),
                .rdata (uart_rdata),
                .tx    (tx),
                .rx    (rx)
            );
        
            assign PRDATA = uart_rdata;
        
        endmodule
        
