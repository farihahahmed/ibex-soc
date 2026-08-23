//      // verilator_coverage annotation
        module gf180mcu_fd_ip_sram__sram256x8m8wm1 (
 117488     input  CLK,
 000857     input  CEN,
 000178     input  GWEN,
 000178     input  [7:0] WEN,
~002867     input  [7:0] A,
 000247     input  [7:0] D,
 001830     output reg [7:0] Q
        );
            reg [7:0] mem [0:255];
        
 117488     always @(posedge CLK) begin
                // Ignore CEN for simulation simplicity – always active
 116780         if (!GWEN) begin
~000708             if (!WEN[0]) mem[A][0] <= D[0];
~000708             if (!WEN[1]) mem[A][1] <= D[1];
~000708             if (!WEN[2]) mem[A][2] <= D[2];
~000708             if (!WEN[3]) mem[A][3] <= D[3];
~000708             if (!WEN[4]) mem[A][4] <= D[4];
~000708             if (!WEN[5]) mem[A][5] <= D[5];
~000708             if (!WEN[6]) mem[A][6] <= D[6];
~000708             if (!WEN[7]) mem[A][7] <= D[7];
                end
 117488         Q <= mem[A];
            end
        endmodule
        
