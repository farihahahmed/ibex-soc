// ============================================================================
// pcpi_crc32.sv - PicoRV32 PCPI co-processor: single-instruction CRC32 step.
//
// Instruction (RISC-V custom-0 space):
//   crc32  rd, rs1, rs2
//   opcode = 7'b0001011 (0x0B, custom-0), funct3 = 000, funct7 = 0000000
//   rd = crc32_update(crc = rs1, byte = rs2[7:0])
//
// Reflected IEEE 802.3 polynomial 0xEDB88320 - the same one Ethernet and zlib
// use, so results match the standard software implementation:
//     crc ^= byte;
//     repeat 8: crc = (crc >> 1) ^ (0xEDB88320 & -(crc & 1));
//
// The 8 rounds are unrolled combinationally, folding a byte into the running
// CRC in ONE instruction instead of the ~20-30 the software loop needs.
// Purpose: integrity checking on the UART/SPI links, where the usual 1 KB
// table-driven CRC does not fit in this chip's 512 B data memory.
// ============================================================================
module pcpi_crc32 (
    input  logic        clk,
    input  logic        resetn,
    input  logic        pcpi_valid,
    input  logic [31:0] pcpi_insn,
    input  logic [31:0] pcpi_rs1,
    input  logic [31:0] pcpi_rs2,
    output logic        pcpi_wr,
    output logic [31:0] pcpi_rd,
    output logic        pcpi_wait,
    output logic        pcpi_ready
);
    localparam logic [31:0] POLY = 32'hEDB88320;

    // Exact decode: anything we do not claim must fall through to the CPU's
    // illegal-instruction trap, so all three fields are checked.
    logic is_crc32;
    assign is_crc32 = pcpi_valid
                    && (pcpi_insn[6:0]   == 7'b0001011)
                    && (pcpi_insn[14:12] == 3'b000)
                    && (pcpi_insn[31:25] == 7'b0000000);

    logic [31:0] c0, c1, c2, c3, c4, c5, c6, c7, c8;
    assign c0 = pcpi_rs1 ^ {24'b0, pcpi_rs2[7:0]};
    assign c1 = (c0 >> 1) ^ (c0[0] ? POLY : 32'b0);
    assign c2 = (c1 >> 1) ^ (c1[0] ? POLY : 32'b0);
    assign c3 = (c2 >> 1) ^ (c2[0] ? POLY : 32'b0);
    assign c4 = (c3 >> 1) ^ (c3[0] ? POLY : 32'b0);
    assign c5 = (c4 >> 1) ^ (c4[0] ? POLY : 32'b0);
    assign c6 = (c5 >> 1) ^ (c5[0] ? POLY : 32'b0);
    assign c7 = (c6 >> 1) ^ (c6[0] ? POLY : 32'b0);
    assign c8 = (c7 >> 1) ^ (c7[0] ? POLY : 32'b0);

    assign pcpi_wait = 1'b0;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            pcpi_wr <= 1'b0; pcpi_rd <= 32'b0; pcpi_ready <= 1'b0;
        end else begin
            pcpi_wr <= 1'b0; pcpi_ready <= 1'b0;
            if (is_crc32 && !pcpi_ready) begin
                pcpi_rd <= c8; pcpi_wr <= 1'b1; pcpi_ready <= 1'b1;
            end
        end
    end
endmodule
