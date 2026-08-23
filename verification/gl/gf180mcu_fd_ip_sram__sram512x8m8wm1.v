// Behavioral model for post-synth GL sim (not timing-accurate)
module gf180mcu_fd_ip_sram__sram512x8m8wm1 (
    input        CLK,
    input        CEN,
    input        GWEN,
    input  [7:0] WEN,
    input  [8:0] A,
    input  [7:0] D,
    output reg [7:0] Q,
    input        VDD,
    input        VSS
);
    reg [7:0] mem [0:511];
    integer i;
    initial begin
        Q = 8'h00;
        for (i = 0; i < 512; i = i + 1) mem[i] = 8'h00;
    end
    always @(posedge CLK) begin
        if (!CEN) begin
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
    end
endmodule
