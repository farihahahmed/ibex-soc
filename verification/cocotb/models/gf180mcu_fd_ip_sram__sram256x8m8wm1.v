module gf180mcu_fd_ip_sram__sram256x8m8wm1 (
    input  CLK,
    input  CEN,
    input  GWEN,
    input  [7:0] WEN,
    input  [7:0] A,
    input  [7:0] D,
    output reg [7:0] Q
);
    reg [7:0] mem [0:255];

    always @(posedge CLK) begin
        // Ignore CEN for simulation simplicity – always active
        if (!GWEN) begin
            if (!WEN[0]) mem[A][0] <= D[0];
            if (!WEN[1]) mem[A][1] <= D[1];
            if (!WEN[2]) mem[A][2] <= D[2];
            if (!WEN[3]) mem[A][3] <= D[3];
            if (!WEN[4]) mem[A][4] <= D[4];
            if (!WEN[5]) mem[A][5] <= D[5];
            if (!WEN[6]) mem[A][6] <= D[6];
            if (!WEN[7]) mem[A][7] <= D[7];
        end
        Q <= mem[A];
    end
endmodule
