// gpio.sv - GPIO peripheral, asymmetric (Columbia-style: few in, more out).
module gpio #(
    parameter int NUM_OUT = 5,
    parameter int NUM_IN  = 2
)(
    input  logic               clk,
    input  logic               rst_n,
    input  logic               sel,
    input  logic               we,
    input  logic [31:0]        wdata,
    output logic [31:0]        rdata,
    output logic [NUM_OUT-1:0] gpio_out,
    input  logic [NUM_IN-1:0]  gpio_in
);
    logic [NUM_OUT-1:0] out_reg;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)          out_reg <= '0;
        else if (sel && we)  out_reg <= wdata[NUM_OUT-1:0];
    end
    assign gpio_out = out_reg;

    logic [NUM_IN-1:0] sync1, sync2;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sync1 <= '0; sync2 <= '0; end
        else begin sync1 <= gpio_in; sync2 <= sync1; end
    end

    assign rdata = {{(32-NUM_IN){1'b0}}, sync2};
endmodule
