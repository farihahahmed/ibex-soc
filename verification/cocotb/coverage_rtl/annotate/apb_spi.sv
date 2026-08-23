//      // verilator_coverage annotation
        // ============================================================================
        // apb_spi.sv - APB slave wrapper around the spi master.
        //
        // Puts SPI on the APB bus (behind the bridge) at 0x0003_0000. Same pattern as
        // apb_gpio / apb_uart: the ACCESS phase (PSEL & PENABLE) turns into the spi's
        // sel/we. SPI responds fast enough that PREADY is always 1.
        //
        // The 4 SPI pins (sclk/mosi/miso/cs_n) pass straight through to the chip edge,
        // where after tapeout I'll wire them to an LED/LCD/sensor.
        //
        //   write -> load a byte and start a transfer.
        //   read  -> bit0 = busy, bits[15:8] = last received byte.
        // ============================================================================
        
        module apb_spi #(
            parameter int CLK_DIV = 4
        )(
 103918     input  logic        PCLK,
 000039     input  logic        PRESETn,
        
            // ---- APB slave interface ----
%000002     input  logic        PSEL,
%000006     input  logic        PENABLE,
%000001     input  logic        PWRITE,
%000002     input  logic [31:0] PADDR,
%000002     input  logic [31:0] PWDATA,
%000001     output logic [31:0] PRDATA,
%000001     output logic        PREADY,
        
            // ---- SPI pins (to the outside world) ----
%000008     output logic        sclk,
%000003     output logic        mosi,
%000000     input  logic        miso,
%000002     output logic        cs_n
        );
        
            assign PREADY = 1'b1;              // zero-wait.
        
%000002     logic access_phase;
            assign access_phase = PSEL & PENABLE;
        
%000002     logic        spi_sel;
%000002     logic        spi_we;
%000001     logic [31:0] spi_rdata;
        
            assign spi_sel = access_phase;
            assign spi_we  = access_phase & PWRITE;
        
            spi #(.CLK_DIV(CLK_DIV)) u_spi (
                .clk   (PCLK),
                .rst_n (PRESETn),
                .sel   (spi_sel),
                .we    (spi_we),
                .wdata (PWDATA),
                .rdata (spi_rdata),
                .sclk  (sclk),
                .mosi  (mosi),
                .miso  (miso),
                .cs_n  (cs_n)
            );
        
            assign PRDATA = spi_rdata;
        
        endmodule
        
