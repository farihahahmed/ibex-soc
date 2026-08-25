// scan_chain.sv - program-loading scan chain + FSM/ClkGen config writes.
// FRAME = { tgt[1:0], addr[13:0], data[31:0] } = 48 bits.
//   tgt: 0=MEMORY write, 1=FSM cfg, 2=CLKGEN cfg, 3=MEMORY read.
//
// READBACK (tgt=3): shift a frame with tgt=3 and the word address; pulse
// scan_load to start the read; wait >=16 sys_clk cycles for the byte-gather to
// assemble the word; pulse scan_i0o1 to capture it; shift it out. Only serviced
// while the FSM is IDLE (scan owns the memory).
module scan_chain (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        scan_in,
    input  logic        scan_shift,
    input  logic        scan_load,
    input  logic        scan_i0o1,
    output logic        scan_out,
    output logic        mem_we,
    output logic        mem_re,
    output logic [15:0] mem_addr,
    output logic [31:0] mem_wdata,
    input  logic [31:0] mem_rdata,
    output logic        fsm_cfg_load,
    output logic [1:0]  fsm_mode,
    output logic [15:0] fsm_count,
    output logic        clk_cfg_load,
    output logic        clk_int,
    output logic [7:0]  clk_div
);
    localparam int FRAME_BITS = 48;
    logic [FRAME_BITS-1:0] shift_reg;

    assign scan_out = shift_reg[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)            shift_reg <= '0;
        else if (scan_i0o1)    shift_reg[31:0] <= mem_rdata;
        else if (scan_shift)   shift_reg <= {scan_in, shift_reg[FRAME_BITS-1:1]};
    end

    logic [1:0] tgt;
    assign tgt        = shift_reg[47:46];
    assign mem_addr   = {2'b00, shift_reg[45:32]};
    assign mem_wdata  = shift_reg[31:0];

    assign mem_we       = scan_load & (tgt == 2'd0);
    assign mem_re       = scan_load & (tgt == 2'd3);
    assign fsm_cfg_load = scan_load & (tgt == 2'd1);
    assign clk_cfg_load = scan_load & (tgt == 2'd2);

    assign fsm_mode  = shift_reg[17:16];
    assign fsm_count = shift_reg[15:0];
    assign clk_int   = shift_reg[8];
    assign clk_div   = shift_reg[7:0];
endmodule
