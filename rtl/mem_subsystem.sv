// ============================================================================
// mem_subsystem.sv - my whole memory system in one block
//
// This is where I glue together the pieces I already built and verified:
//   - rst_sync        -> gives me one clean, synchronized reset for both memories
//   - mem_wrapper      -> translates Ibex's handshake to my bank (x2, one per memory)
//   - sram_bank_2k     -> the actual 2 KB storage (lives inside each wrapper)
//
// Ibex has TWO separate memory ports, so I build TWO memories:
//   u_imem  - instruction memory. Ibex only READS from here (it never writes
//             instructions), so I tie the write signals off.
//   u_dmem  - data memory. Ibex reads AND writes here (loads and stores).
//
// Naming: my ports line up with Ibex's port names so hooking this up later is clean.
// Ibex's "_o" = output from Ibex (input to me), "_i" = input to Ibex (output from me).
// ============================================================================

module mem_subsystem (
    input  logic        clk,             // system clock.
    input  logic        rst_n_in,        // raw reset from outside (async). I'll clean it up inside.

    // ---- instruction memory port (Ibex fetches instructions here) ----
    input  logic        instr_req_i,     // Ibex requesting an instruction fetch (its instr_req_o).
    output logic        instr_gnt_o,     // I grant it (goes to Ibex's instr_gnt_i).
    input  logic [31:0] instr_addr_i,    // fetch address (Ibex's instr_addr_o).
    output logic        instr_rvalid_o,  // instruction data valid (Ibex's instr_rvalid_i).
    output logic [31:0] instr_rdata_o,   // the instruction word (Ibex's instr_rdata_i).

    // ---- data memory port (Ibex loads/stores here) ----
    input  logic        data_req_i,      // Ibex requesting a data access (its data_req_o).
    output logic        data_gnt_o,      // I grant it (Ibex's data_gnt_i).
    input  logic        data_we_i,       // 1 = store (write), 0 = load (read) (Ibex's data_we_o).
    input  logic [3:0]  data_be_i,       // byte enables (Ibex's data_be_o).
    input  logic [31:0] data_addr_i,     // data address (Ibex's data_addr_o).
    input  logic [31:0] data_wdata_i,    // data to store (Ibex's data_wdata_o).
    output logic        data_rvalid_o,   // data-read valid (Ibex's data_rvalid_i).
    output logic [31:0] data_rdata_o     // the loaded data (Ibex's data_rdata_i).
);

    // --------------------------------------------------------------------
    // 1) Clean up the reset once, here, and feed the synchronized version
    //    to both memories.
    // --------------------------------------------------------------------
    logic rst_n;                          // my clean, synchronized reset.
    rst_sync u_rst_sync (
        .clk      (clk),
        .rst_n_in (rst_n_in),             // raw async reset in.
        .rst_n_out(rst_n)                 // clean synchronized reset out -> used below.
    );

    // --------------------------------------------------------------------
    // 2) Instruction memory. Read-only from Ibex's side, so I hardwire the
    //    write controls to 0 (never writing, no bytes enabled). wdata is unused
    //    for reads, so I just feed it zeros.
    // --------------------------------------------------------------------
    mem_wrapper u_imem (
        .clk   (clk),
        .rst_n (rst_n),                   // the clean reset.
        .req   (instr_req_i),             // fetch request from Ibex.
        .gnt   (instr_gnt_o),             // grant back to Ibex.
        .we    (1'b0),                    // instruction memory is READ-ONLY -> never write.
        .be    (4'b0000),                 // no byte-enables needed for reads.
        .addr  (instr_addr_i),            // fetch address.
        .wdata (32'b0),                   // unused on reads, tie to 0.
        .rvalid(instr_rvalid_o),          // instruction-valid back to Ibex.
        .rdata (instr_rdata_o)            // the instruction word back to Ibex.
    );

    // --------------------------------------------------------------------
    // 3) Data memory. Full read/write - I pass Ibex's write controls straight through.
    // --------------------------------------------------------------------
    mem_wrapper u_dmem (
        .clk   (clk),
        .rst_n (rst_n),                   // same clean reset.
        .req   (data_req_i),              // data access request.
        .gnt   (data_gnt_o),              // grant back.
        .we    (data_we_i),              // write-enable straight from Ibex.
        .be    (data_be_i),              // byte-enables straight from Ibex.
        .addr  (data_addr_i),            // data address.
        .wdata (data_wdata_i),           // data to store.
        .rvalid(data_rvalid_o),          // read-valid back to Ibex.
        .rdata (data_rdata_o)            // loaded data back to Ibex.
    );

endmodule
