// Zero-delay SRAM model for Verilator coverage builds only.
// The PDK model's specify/#delay constructs make Verilator emit references to
// internal timing locals (Tdly) that do not exist in the generated class.
// Coverage measures our RTL, not the vendor macro, so a behavioural stand-in
// with identical ports and function is sufficient.
module gf180mcu_fd_ip_sram__sram512x8m8wm1 (
    input        CLK,
    input        CEN,
    input        GWEN,
    input  [7:0] WEN,
    input  [8:0] A,
    input  [7:0] D,
    output [7:0] Q
);
    reg [7:0] mem [0:511];
    reg [7:0] q_r;
    always @(posedge CLK) begin
        if (!CEN) begin
            if (!GWEN) mem[A] <= (mem[A] & WEN) | (D & ~WEN);
            q_r <= mem[A];
        end
    end
    assign Q = q_r;
endmodule
