//      // verilator_coverage annotation
        // scan_chain.sv - program-loading scan chain + FSM/ClkGen config writes.
        // FRAME = { tgt[1:0], addr[13:0], data[31:0] } = 48 bits.
        //   tgt: 0=MEMORY, 1=FSM cfg, 2=CLKGEN cfg.
        module scan_chain (
 117488     input  logic        clk,
 000039     input  logic        rst_n,
 001095     input  logic        scan_in,
 000253     input  logic        scan_shift,
 000253     input  logic        scan_load,
%000000     input  logic        scan_i0o1,
 001019     output logic        scan_out,
 000177     output logic        mem_we,
~001057     output logic [15:0] mem_addr,
 001057     output logic [31:0] mem_wdata,
%000000     input  logic [31:0] mem_rdata,
 000038     output logic        fsm_cfg_load,
 001057     output logic [1:0]  fsm_mode,
 001019     output logic [15:0] fsm_count,
 000038     output logic        clk_cfg_load,
 001019     output logic        clk_int,
 001019     output logic [7:0]  clk_div
        );
            localparam int FRAME_BITS = 48;
 001095     logic [FRAME_BITS-1:0] shift_reg;
        
            assign scan_out = shift_reg[0];
        
 117526     always_ff @(posedge clk or negedge rst_n) begin
 117018         if (!rst_n)            shift_reg <= '0;
%000000         else if (scan_i0o1)    shift_reg[31:0] <= mem_rdata;
 104874         else if (scan_shift)   shift_reg <= {scan_in, shift_reg[FRAME_BITS-1:1]};
            end
        
 001095     logic [1:0] tgt;
            assign tgt        = shift_reg[47:46];
            assign mem_addr   = {2'b00, shift_reg[45:32]};
            assign mem_wdata  = shift_reg[31:0];
        
            assign mem_we       = scan_load & (tgt == 2'd0);
            assign fsm_cfg_load = scan_load & (tgt == 2'd1);
            assign clk_cfg_load = scan_load & (tgt == 2'd2);
        
            assign fsm_mode  = shift_reg[17:16];
            assign fsm_count = shift_reg[15:0];
            assign clk_int   = shift_reg[8];
            assign clk_div   = shift_reg[7:0];
        endmodule
        
