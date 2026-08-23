//      // verilator_coverage annotation
        module gf180mcu_fd_ip_sram__sram64x8m8wm1 (
 103918     input  CLK,
%000001     input  CEN,
%000001     input  GWEN,
%000001     input  [7:0] WEN,
%000000     input  [5:0] A,
%000000     input  [7:0] D,
%000000     output reg [7:0] Q
        );
            reg [7:0] mem [0:63];
        
 103918     always @(posedge CLK) begin
                // Always active in simulation
~103918         if (!GWEN) begin
%000000             if (!WEN[0]) mem[A][0] <= D[0];
%000000             if (!WEN[1]) mem[A][1] <= D[1];
%000000             if (!WEN[2]) mem[A][2] <= D[2];
%000000             if (!WEN[3]) mem[A][3] <= D[3];
%000000             if (!WEN[4]) mem[A][4] <= D[4];
%000000             if (!WEN[5]) mem[A][5] <= D[5];
%000000             if (!WEN[6]) mem[A][6] <= D[6];
%000000             if (!WEN[7]) mem[A][7] <= D[7];
                end
 103918         Q <= mem[A];
            end
        endmodule
        
