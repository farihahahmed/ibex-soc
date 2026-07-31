`timescale 1ns/1ps
module tb_gpio;
    localparam NUM_OUT=5, NUM_IN=2;
    logic clk, rst_n, sel, we;
    logic [31:0] wdata, rdata;
    logic [NUM_OUT-1:0] gpio_out;
    logic [NUM_IN-1:0]  gpio_in;
    integer errors;

    gpio #(.NUM_OUT(NUM_OUT), .NUM_IN(NUM_IN)) dut(.clk(clk), .rst_n(rst_n),
        .sel(sel), .we(we), .wdata(wdata), .rdata(rdata),
        .gpio_out(gpio_out), .gpio_in(gpio_in));

    initial clk=0; always #5 clk=~clk;

    initial begin
        errors=0; sel=0; we=0; wdata=0; gpio_in=0;
        rst_n=0; repeat(2) @(negedge clk); rst_n=1; @(negedge clk);

        // write 0x1F to output (5 bits)
        @(negedge clk); sel=1; we=1; wdata=32'h000000FF; @(negedge clk); sel=0; we=0;
        #1;
        if (gpio_out!==5'h1F) begin $display("BAD out=%h exp 1F", gpio_out); errors=errors+1; end
        else $display("OK output reg = 0x%h (5 bits)", gpio_out);

        // drive inputs, read back through synchronizer (2 cycles)
        gpio_in=2'b10; repeat(3) @(negedge clk);
        @(negedge clk); sel=1; we=0; #1;
        if (rdata[1:0]!==2'b10) begin $display("BAD in rdata=%h exp 2", rdata[1:0]); errors=errors+1; end
        else $display("OK input synced = 0x%h (2 bits)", rdata[1:0]);
        if (rdata[31:2]!==30'd0) begin $display("BAD upper bits nonzero"); errors=errors+1; end
        sel=0;

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - GPIO 2-in/5-out works!");
        else           $display("FAILED (%0d errors)", errors);
        $finish;
    end
    initial begin #100000; $display("TIMEOUT"); $finish; end
endmodule
