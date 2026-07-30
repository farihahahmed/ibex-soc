`timescale 1ns/1ps
module tb_chip_full;
    localparam int NUM_IO=8, CLK_FREQ=8, BAUD_RATE=1, SPI_CLK_DIV=2;
    logic clk, rst_n;
    logic scan_in, scan_shift, scan_load, scan_capture, scan_out, scan_sel_dmem;
    logic start, load_done;
    logic [1:0] fsm_state;
    logic [NUM_IO-1:0] gpio_out, gpio_in;
    logic uart_tx, uart_rx; assign uart_rx = uart_tx;
    logic spi_sclk, spi_mosi, spi_miso, spi_cs_n; assign spi_miso = spi_mosi;

    chip_top_full #(.NUM_IO(NUM_IO), .CLK_FREQ(CLK_FREQ), .BAUD_RATE(BAUD_RATE), .SPI_CLK_DIV(SPI_CLK_DIV)) dut (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_capture(scan_capture), .scan_out(scan_out), .scan_sel_dmem(scan_sel_dmem),
        .start(start), .load_done(load_done), .fsm_state(fsm_state),
        .gpio_out(gpio_out), .gpio_in(gpio_in),
        .uart_tx(uart_tx), .uart_rx(uart_rx),
        .spi_sclk(spi_sclk), .spi_mosi(spi_mosi), .spi_miso(spi_miso), .spi_cs_n(spi_cs_n)
    );

    initial clk=0; always #5 clk=~clk;

    // waveform dump for GTKWave
    initial begin
        $dumpfile("chip_full.vcd");
        $dumpvars(0, tb_chip_full);
    end
    localparam int BIT_CYCLES = CLK_FREQ/BAUD_RATE;

    localparam int NWORDS = 16;
    localparam int BASE_WORD = 32;
    logic [31:0] prog [0:NWORDS-1];
    initial begin
        prog[0]=32'h00010537;  // lui  x10,0x10
        prog[1]=32'h000205B7;  // lui  x11,0x20
        prog[2]=32'h00030637;  // lui  x12,0x30
        prog[3]=32'h0A500293;  // addi x5,x0,0xA5
        prog[4]=32'h04100313;  // addi x6,x0,0x41
        prog[5]=32'h0B700393;  // addi x7,x0,0xB7
        prog[6]=32'h00552023;  // sw   x5,0(x10)   GPIO
        prog[7]=32'h0065A023;  // sw   x6,0(x11)   UART
        prog[8]=32'h00762023;  // sw   x7,0(x12)   SPI
        prog[9]=32'h00000013;  // L: nop  (loop target)
        prog[10]=32'hFFDFF06F; // jal x0,-4 (jump back to L -> tight 2-instr loop)
        prog[11]=32'h00000013; // nop (prefetch padding)
        prog[12]=32'h00000013; // nop
        prog[13]=32'h00000013; // nop
        prog[14]=32'h00000013; // nop
        prog[15]=32'h00000013; // nop
    end

    task wake_all;
        begin
            dut.u_mem.u_imem.u_mem.u_sram.cen_fell=1'b1; dut.u_mem.u_imem.u_mem.u_sram.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_mem.u_sram.cen_fell=1'b1; dut.u_mem.u_dmem.u_mem.u_sram.cen_dly=1'b1;
            dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_fell=1'b1; dut.u_dmem_slave.u_dmem.u_mem.u_sram.cen_dly=1'b1;
        end
    endtask

    integer k;
    task scan_word(input [15:0] waddr, input [31:0] wdata);
        logic [47:0] frame;
        begin
            frame = {waddr, wdata};
            for (k=0;k<48;k=k+1) begin
                @(negedge clk); scan_in=frame[k]; scan_shift=1'b1;
            end
            @(negedge clk); scan_shift=1'b0; scan_in=1'b0;
            @(negedge clk); scan_load=1'b1;
            @(negedge clk); scan_load=1'b0;
        end
    endtask

    logic [7:0] spi_byte; integer spi_bits;
    initial begin
        spi_byte=8'h0; spi_bits=0;
        forever begin
            @(posedge spi_sclk); #1;
            if (spi_bits<8) begin spi_byte={spi_byte[6:0],spi_mosi}; spi_bits=spi_bits+1; end
        end
    end

    logic [7:0] uart_byte;
    integer bb;
    task decode_uart;
        begin
            @(negedge uart_tx);
            repeat (BIT_CYCLES/2) @(posedge clk);
            for (bb=0;bb<8;bb=bb+1) begin
                repeat (BIT_CYCLES) @(posedge clk);
                #1; uart_byte[bb]=uart_tx;
            end
        end
    endtask

    integer i, errors;
    initial begin
        scan_in=0; scan_shift=0; scan_load=0; scan_capture=0; scan_sel_dmem=0;
        start=0; load_done=0; uart_byte=8'h0; errors=0; gpio_in=0;

        rst_n=0; repeat(4) @(posedge clk); wake_all;
        @(negedge clk); rst_n=1; repeat(2) @(posedge clk); wake_all;

        @(negedge clk); start=1; @(posedge clk); @(negedge clk); start=0;
        $display("FSM: %0d (expect 1=LOAD). Scanning %0d-word program...", fsm_state, NWORDS);
        for (i=0;i<NWORDS;i=i+1) scan_word(BASE_WORD[15:0]+i[15:0], prog[i]);
        $display("scan-load complete.");

        // READBACK: what actually got loaded into imem at each program word?
        for (i=0;i<NWORDS;i=i+1) begin
            $display("  imem[word %0d, byte 0x%02h] = 0x%02h%02h%02h%02h", BASE_WORD+i, (BASE_WORD+i)*4,
                dut.u_mem.u_imem.u_mem.u_sram.mem[(BASE_WORD+i)*4+3],
                dut.u_mem.u_imem.u_mem.u_sram.mem[(BASE_WORD+i)*4+2],
                dut.u_mem.u_imem.u_mem.u_sram.mem[(BASE_WORD+i)*4+1],
                dut.u_mem.u_imem.u_mem.u_sram.mem[(BASE_WORD+i)*4+0]);
        end

        @(negedge clk); load_done=1; @(posedge clk); @(negedge clk); load_done=0;
        $display("FSM: %0d (expect 2=RUN). CPU running the demo...", fsm_state);

        fork
            decode_uart;
            begin
                for (int w=0; w<400; w=w+1) begin @(posedge clk); wake_all; end
            end
        join

        $display("--------------------------------------------------");
        $display("RESULTS:");
        $display("  GPIO out : 0x%02h (expect 0xA5)", gpio_out);
        $display("  UART sent: 0x%02h (expect 0x41)", uart_byte);
        $display("  SPI MOSI : 0x%02h (expect 0xB7), bits=%0d", spi_byte, spi_bits);
        if (gpio_out !== 8'hA5)  errors=errors+1;
        if (uart_byte !== 8'h41) errors=errors+1;
        if (spi_byte !== 8'hB7)  errors=errors+1;
        $display("--------------------------------------------------");
        if (errors==0)
            $display("PASS: full SoC ran multi-function program - GPIO+UART+SPI all driven. v0.8 COMPLETE SoC ALIVE!");
        else
            $display("CHECK: %0d peripheral(s) mismatched - inspect above.", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #8000000; $display("TIMEOUT"); $finish; end
endmodule
