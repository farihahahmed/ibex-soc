//      // verilator_coverage annotation
        // gpio.sv - GPIO peripheral, asymmetric (Columbia-style: few in, more out).
        module gpio #(
            parameter int NUM_OUT = 5,
            parameter int NUM_IN  = 2
        )(
 103918     input  logic               clk,
 000039     input  logic               rst_n,
%000002     input  logic               sel,
%000002     input  logic               we,
%000002     input  logic [31:0]        wdata,
%000000     output logic [31:0]        rdata,
%000001     output logic [NUM_OUT-1:0] gpio_out,
%000000     input  logic [NUM_IN-1:0]  gpio_in
        );
%000001     logic [NUM_OUT-1:0] out_reg;
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n)          out_reg <= '0;
~103916         else if (sel && we)  out_reg <= wdata[NUM_OUT-1:0];
            end
            assign gpio_out = out_reg;
        
%000000     logic [NUM_IN-1:0] sync1, sync2;
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin sync1 <= '0; sync2 <= '0; end
 103918         else begin sync1 <= gpio_in; sync2 <= sync1; end
            end
        
            assign rdata = {{(32-NUM_IN){1'b0}}, sync2};
        endmodule
        
