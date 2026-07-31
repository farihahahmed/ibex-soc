// ============================================================================
// mem_subsystem.sv - my whole memory system in one block
//
// Pieces I built and verified: rst_sync (one clean reset), mem_wrapper (x2,
// Ibex handshake -> bank), sram_bank_2k (2 KB storage inside each wrapper).
//
// Ibex has TWO memory ports -> TWO memories:
//   u_imem  - instruction memory. Ibex only READS. (never writes instructions)
//   u_dmem  - data memory. Ibex reads AND writes.
//
// NEW (scan-load path): to load a program after tapeout, the SCAN CHAIN needs to
// WRITE imem/dmem before the CPU runs. So I add a scan write port and mux it in:
//   when scan_owns_mem = 1 (during the FSM's LOAD state), the scan chain drives
//   the memory write signals; when 0 (RUN), imem is read-only and dmem follows
//   the CPU as before. This is how the chip loads its own program.
//
// The scan chain provides a WORD-addressed write (scan_addr counts words 0,1,2..).
// My mem_wrapper expects a BYTE address (it does addr[10:2] internally), so I
// shift the scan word address left by 2 to make a byte address.
// ============================================================================

module mem_subsystem (
    input  logic        clk,
    input  logic        rst_n_in,

    // ---- instruction memory port (Ibex fetches here) ----
    input  logic        instr_req_i,
    output logic        instr_gnt_o,
    input  logic [31:0] instr_addr_i,
    output logic        instr_rvalid_o,
    output logic [31:0] instr_rdata_o,

    // ---- data memory port (Ibex loads/stores here) ----
    input  logic        data_req_i,
    output logic        data_gnt_o,
    input  logic        data_we_i,
    input  logic [3:0]  data_be_i,
    input  logic [31:0] data_addr_i,
    input  logic [31:0] data_wdata_i,
    output logic        data_rvalid_o,
    output logic [31:0] data_rdata_o,

    // ---- NEW: scan-load write port (from the scan chain, during LOAD) ----
    input  logic        scan_owns_mem,   // 1 = scan chain owns the write path (FSM LOAD state).
    input  logic        scan_we,         // scan write-enable.
    input  logic [15:0] scan_addr,       // scan WORD address (0,1,2,... per word).
    input  logic [31:0] scan_wdata,      // scan write data.
    input  logic        scan_sel_dmem    // 0 = write imem, 1 = write dmem (which memory to load).
);

    // --------------------------------------------------------------------
    // 1) One clean synchronized reset for both memories.
    // --------------------------------------------------------------------
    logic rst_n;
    rst_sync u_rst_sync (
        .clk      (clk),
        .rst_n_in (rst_n_in),
        .rst_n_out(rst_n)
    );

    // --------------------------------------------------------------------
    // Scan address is a WORD index; the wrapper wants a BYTE address, so <<2.
    // --------------------------------------------------------------------
    logic [31:0] scan_byte_addr;
    assign scan_byte_addr = {14'b0, scan_addr, 2'b00};   // word -> byte address.

    // --------------------------------------------------------------------
    // 2) Instruction memory. Normally read-only from Ibex. During scan LOAD of
    //    imem, the scan chain drives the write signals instead.
    // --------------------------------------------------------------------
    logic        imem_we;
    logic [3:0]  imem_be;
    logic [31:0] imem_addr;
    logic [31:0] imem_wdata;
    logic        imem_req;

    always_comb begin
        if (scan_owns_mem && !scan_sel_dmem) begin
            // scan chain is loading INSTRUCTION memory
            imem_req   = scan_we;             // request a write when scanning a word in
            imem_we    = scan_we;
            imem_be    = 4'b1111;             // write the whole word
            imem_addr  = scan_byte_addr;
            imem_wdata = scan_wdata;
        end else begin
            // normal: Ibex fetches (read-only)
            imem_req   = instr_req_i;
            imem_we    = 1'b0;
            imem_be    = 4'b0000;
            imem_addr  = instr_addr_i;
            imem_wdata = 32'b0;
        end
    end

    mem_wrapper u_imem (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (imem_req),
        .gnt   (instr_gnt_o),
        .we    (imem_we),
        .be    (imem_be),
        .addr  (imem_addr),
        .wdata (imem_wdata),
        .rvalid(instr_rvalid_o),
        .rdata (instr_rdata_o)
    );

    // --------------------------------------------------------------------
    // 3) Data memory. Ibex read/write normally; during scan LOAD of dmem, the
    //    scan chain drives the write signals instead.
    // --------------------------------------------------------------------
    logic        dmem_we;
    logic [3:0]  dmem_be;
    logic [31:0] dmem_addr;
    logic [31:0] dmem_wdata;
    logic        dmem_req;

    always_comb begin
        if (scan_owns_mem && scan_sel_dmem) begin
            // scan chain is loading DATA memory
            dmem_req   = scan_we;
            dmem_we    = scan_we;
            dmem_be    = 4'b1111;
            dmem_addr  = scan_byte_addr;
            dmem_wdata = scan_wdata;
        end else begin
            // normal: Ibex loads/stores
            dmem_req   = data_req_i;
            dmem_we    = data_we_i;
            dmem_be    = data_be_i;
            dmem_addr  = data_addr_i;
            dmem_wdata = data_wdata_i;
        end
    end

    mem_wrapper u_dmem (
        .clk   (clk),
        .rst_n (rst_n),
        .req   (dmem_req),
        .gnt   (data_gnt_o),
        .we    (dmem_we),
        .be    (dmem_be),
        .addr  (dmem_addr),
        .wdata (dmem_wdata),
        .rvalid(data_rvalid_o),
        .rdata (data_rdata_o)
    );

endmodule
