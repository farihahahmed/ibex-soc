// ============================================================================
// pcpi_custom.sv - PicoRV32 PCPI co-processor: custom instruction extension.
//
// All instructions live in the RISC-V custom-0 opcode space (0x0B) and are
// selected by funct3, so one shared decode serves the whole extension:
//
//   funct3  mnemonic   operation
//   ------  ---------  ------------------------------------------------------
//   000     crc32.b    rd = crc32_update(crc = rs1, byte = rs2[7:0])
//   001     crc32.w    rd = crc32_update(crc = rs1, word = rs2[31:0])
//   010     popcnt     rd = number of set bits in rs1
//   011     brev       rd = rs1 with its bit order reversed
//   100     mac        acc += signed(rs1[15:0]) * signed(rs2[15:0]); rd = acc
//   101     macrd      rd = acc                     (read, do not modify)
//   110     macclr     acc = 0; rd = 0              (start a new accumulation)
//
// WHY THESE
//   crc32.b/.w  Integrity checking on the UART and SPI links. A table-driven
//               CRC needs a 1 KB lookup table, which does not fit in this
//               chip's 512 B data memory. Reflected IEEE 802.3 polynomial
//               0xEDB88320, so results match zlib and Ethernet.
//   popcnt/brev Bit manipulation for protocol handling and data packing;
//               both are multi-instruction loops in software.
//   mac         Multiply-accumulate is the core of digital filtering, the
//               standard microcontroller DSP workload. Signed, because real
//               signals and filter coefficients both go negative.
//
// DECODE DISCIPLINE
//   Every field is checked. Anything this unit does not claim falls through
//   to PicoRV32's illegal-instruction trap rather than silently doing nothing.
//
// The unit sits entirely inside the CPU boundary: it never touches the bus,
// memory or pins. Only pcpi_rd is on the CPU's critical path.
// ============================================================================
module pcpi_custom (
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
    localparam logic [2:0] F_CRC32B = 3'b000;
    localparam logic [2:0] F_CRC32W = 3'b001;
    localparam logic [2:0] F_POPCNT = 3'b010;
    localparam logic [2:0] F_BREV   = 3'b011;
    localparam logic [2:0] F_MAC    = 3'b100;
    localparam logic [2:0] F_MACRD  = 3'b101;
    localparam logic [2:0] F_MACCLR = 3'b110;

    logic [2:0] funct3;
    logic       is_custom;
    assign funct3    = pcpi_insn[14:12];
    assign is_custom = pcpi_valid
                     && (pcpi_insn[6:0]   == 7'b0001011)
                     && (pcpi_insn[31:25] == 7'b0000000)
                     && (funct3 != 3'b111);

    function automatic logic [31:0] crc_round(input logic [31:0] c);
        crc_round = (c >> 1) ^ (c[0] ? POLY : 32'b0);
    endfunction

    function automatic logic [31:0] crc_byte(input logic [31:0] c,
                                             input logic [7:0]  b);
        logic [31:0] t;
        begin
            t = c ^ {24'b0, b};
            for (int i = 0; i < 8; i++) t = crc_round(t);
            crc_byte = t;
        end
    endfunction

    logic [31:0] crc_b_res, crc_w_res;
    assign crc_b_res = crc_byte(pcpi_rs1, pcpi_rs2[7:0]);
    always_comb begin
        logic [31:0] t;
        t = crc_byte(pcpi_rs1, pcpi_rs2[7:0]);
        t = crc_byte(t,        pcpi_rs2[15:8]);
        t = crc_byte(t,        pcpi_rs2[23:16]);
        t = crc_byte(t,        pcpi_rs2[31:24]);
        crc_w_res = t;
    end

    logic [31:0] popcnt_res, brev_res;
    always_comb begin
        popcnt_res = 32'b0;
        for (int i = 0; i < 32; i++) popcnt_res += {31'b0, pcpi_rs1[i]};
    end
    always_comb begin
        for (int i = 0; i < 32; i++) brev_res[i] = pcpi_rs1[31-i];
    end

    // Signed: an unsigned multiply would read -1 as 65535 and corrupt the sum.
    logic signed [15:0] mul_a, mul_b;
    logic signed [31:0] product, acc, acc_next;
    assign mul_a    = pcpi_rs1[15:0];
    assign mul_b    = pcpi_rs2[15:0];
    assign product  = mul_a * mul_b;
    assign acc_next = acc + product;

    logic [31:0] result;
    always_comb begin
        case (funct3)
            F_CRC32B: result = crc_b_res;
            F_CRC32W: result = crc_w_res;
            F_POPCNT: result = popcnt_res;
            F_BREV:   result = brev_res;
            F_MAC:    result = acc_next;
            F_MACRD:  result = acc;
            F_MACCLR: result = 32'b0;
            default:  result = 32'b0;
        endcase
    end

    assign pcpi_wait = 1'b0;

    always_ff @(posedge clk) begin
        if (!resetn) begin
            pcpi_wr <= 1'b0; pcpi_rd <= 32'b0; pcpi_ready <= 1'b0; acc <= 32'sd0;
        end else begin
            pcpi_wr    <= 1'b0;
            pcpi_ready <= 1'b0;
            if (is_custom && !pcpi_ready) begin
                pcpi_rd    <= result;
                pcpi_wr    <= 1'b1;
                pcpi_ready <= 1'b1;
                if      (funct3 == F_MAC)    acc <= acc_next;
                else if (funct3 == F_MACCLR) acc <= 32'sd0;
            end
        end
    end
endmodule
