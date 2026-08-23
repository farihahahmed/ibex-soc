// ============================================================================
// scan_chain.sv - my program-loading scan chain.
//
// After tapeout my chip has only ~20 pins - not enough to wire a full address +
// data bus to load a program. So I load memory SERIALLY through one pin: shift a
// program in bit by bit, assemble each word into a full (address, data) frame
// inside the chip, then write that word to memory. Repeat for the whole program.
//
// This is done while the CPU is held in reset. Once memory is loaded I release
// reset and the CPU runs. I can also read memory back out serially to verify.
//
// FRAME = { addr[15:0], data[31:0] } = 48 bits.
//   16 address bits reach 64 KB (my memory is only 4 KB, so plenty).
//   32 data bits    = one instruction/data word.
//
// Modes (driven by control pins):
//   shift=1        : each clock, pull one bit in on scan_in, everything shifts,
//                    oldest bit falls out scan_out. Do this 48 times to fill a frame.
//   load=1  (pulse): write the assembled frame to memory (mem_we, mem_addr, mem_wdata).
//   capture=1      : latch a memory word into the data field so I can shift it out
//                    (read-back for verification).
// ============================================================================

module scan_chain (
    input  logic        clk,
    input  logic        rst_n,

    // ---- serial scan interface (these become chip pins) ----
    input  logic        scan_in,       // serial data in.
    input  logic        scan_shift,    // 1 = shift one bit this clock.
    input  logic        scan_load,     // 1 = write the current frame to memory (pulse).
    input  logic        scan_capture,  // 1 = grab mem_rdata into the frame (for read-back).
    output logic        scan_out,      // serial data out (oldest bit / read-back).

    // ---- memory write/read port (drives instruction or data memory) ----
    output logic        mem_we,        // write enable to memory.
    output logic [15:0] mem_addr,      // address to memory.
    output logic [31:0] mem_wdata,     // data to write.
    input  logic [31:0] mem_rdata      // data read back (for capture).
);

    localparam int FRAME_BITS = 48;    // 16 addr + 32 data.

    // The shift register that holds one frame. Bit layout while shifting:
    //   I shift IN at the top (bit 47) and OUT at the bottom (bit 0). After 48
    //   shifts, the first bits I sent have travelled down to the low end.
    //   I define the frame as { addr[15:0], data[31:0] }, so once full:
    //     shift_reg[47:32] = address
    //     shift_reg[31:0]  = data
    logic [FRAME_BITS-1:0] shift_reg;

    // scan_out is the bit about to fall off the bottom.
    assign scan_out = shift_reg[0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= '0;
        end else if (scan_capture) begin
            // load a read-back word into the data field so I can shift it out.
            // (address field kept as-is; I mainly care about the data bits.)
            shift_reg[31:0] <= mem_rdata;
        end else if (scan_shift) begin
            // shift everything down one; new bit enters at the top.
            shift_reg <= {scan_in, shift_reg[FRAME_BITS-1:1]};
        end
        // when idle (no shift/capture) the register holds its value, so a load
        // can use the assembled frame.
    end

    // ---- memory write path ----
    // On a load pulse, drive the memory write port with the assembled frame.
    // mem_we is combinational off scan_load so the write happens the cycle load
    // is asserted (the memory registers it on the clock edge).
    assign mem_addr  = shift_reg[47:32];
    assign mem_wdata = shift_reg[31:0];
    assign mem_we    = scan_load;

endmodule
