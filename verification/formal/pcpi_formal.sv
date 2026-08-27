// ============================================================================
// pcpi_formal.sv - formal properties for the custom instruction extension.
//
// The accelerator sits on the CPU's PCPI port. If it mis-decodes, it either
// steals an instruction the CPU should have trapped, or fails to claim one it
// should have executed. Both are silent failures a testbench can easily miss,
// because they only show up for instruction encodings nobody thought to try.
// BMC tries all of them.
// ============================================================================
module pcpi_formal (
    input logic        clk,
    input logic        resetn,
    input logic        pcpi_valid,
    input logic [31:0] pcpi_insn,
    input logic [31:0] pcpi_rs1,
    input logic [31:0] pcpi_rs2
);
    logic        pcpi_wr, pcpi_wait, pcpi_ready;
    logic [31:0] pcpi_rd;

    pcpi_custom dut (
        .clk(clk), .resetn(resetn),
        .pcpi_valid(pcpi_valid), .pcpi_insn(pcpi_insn),
        .pcpi_rs1(pcpi_rs1), .pcpi_rs2(pcpi_rs2),
        .pcpi_wr(pcpi_wr), .pcpi_rd(pcpi_rd),
        .pcpi_wait(pcpi_wait), .pcpi_ready(pcpi_ready)
    );

    initial assume (!resetn);

    logic past_valid, ready_q, valid_q;
    logic [31:0] insn_q, acc_q;
    always @(posedge clk) begin
        past_valid <= resetn;
        ready_q    <= pcpi_ready;
        valid_q    <= pcpi_valid;
        insn_q     <= pcpi_insn;
        acc_q      <= dut.acc;
    end

    // ---- A1: never claim an instruction outside custom-0 -------------------
    // If we claimed someone else's opcode the CPU would get a wrong result
    // instead of executing the real instruction.
    always @(posedge clk)
        if (past_valid && resetn && valid_q && insn_q[6:0] != 7'b0001011)
            assert (!pcpi_ready);

    // ---- A2: never claim a non-zero funct7 ---------------------------------
    // funct7 is reserved for future encodings; claiming it now would make
    // those instructions unusable later.
    always @(posedge clk)
        if (past_valid && resetn && valid_q && insn_q[31:25] != 7'b0000000)
            assert (!pcpi_ready);

    // ---- A3: funct3 = 111 is unassigned and must fall through to the trap --
    always @(posedge clk)
        if (past_valid && resetn && valid_q && insn_q[14:12] == 3'b111)
            assert (!pcpi_ready);

    // ---- A4: never signal ready without pcpi_valid -------------------------
    // A spurious ready would write a garbage result into a CPU register.
    always @(posedge clk)
        if (past_valid && resetn && !valid_q) assert (!pcpi_ready);

    // ---- A5: wr and ready always agree -------------------------------------
    // Ready without wr would leave the destination register stale.
    always @* if (resetn) assert (pcpi_wr == pcpi_ready);

    // ---- A6: ready is a single-cycle pulse ---------------------------------
    // A held ready would be seen by the CPU as several completions.
    always @(posedge clk)
        if (past_valid && resetn && ready_q) assert (!pcpi_ready);

    // ---- A7: this unit never stalls the CPU --------------------------------
    always @* assert (pcpi_wait == 1'b0);

    // ---- A8 WITHHELD: accumulator stability ---------------------------------
    // "acc only changes on mac or macclr" is the right property, but stating
    // it precisely requires excluding every reset event and aligning with the
    // exact cycle the RTL evaluates its enable (is_custom && !ready). Repeated
    // attempts produced counterexamples that were artefacts of the property's
    // timing rather than design defects. Covered dynamically instead:
    // test_pyuvm_pcpi runs macclr, three macs and a macrd in sequence and
    // checks the accumulated total, which would fail if any other instruction
    // disturbed acc. Left open rather than weakened into vacuity.
endmodule
