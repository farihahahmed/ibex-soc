//      // verilator_coverage annotation
        module mem_subsystem (
 117488     input  logic        clk,
 000039     input  logic        rst_n_in,
 000399     input  logic        instr_req_i,
 000876     output logic        instr_gnt_o,
~000199     input  logic [31:0] instr_addr_i,
 000837     output logic        instr_rvalid_o,
~000233     output logic [31:0] instr_rdata_o,
 000038     input  logic        scan_owns_mem,
 000177     input  logic        scan_we,
~001057     input  logic [15:0] scan_addr,
 001057     input  logic [31:0] scan_wdata,
%000000     input  logic        scan_sel_dmem
        );
 000039     logic rst_n;
            rst_sync u_rst_sync (
                .clk(clk), .rst_n_in(rst_n_in), .rst_n_out(rst_n)
            );
        
            // ---- INSTRUCTION memory: narrow 8-bit path ----
            // (Data memory lives in ahb_mem on the AHB bus; the old mem_subsystem dmem
            //  was never used by the CPU, so it has been removed.)
 000177     logic imem_ld_en;
            assign imem_ld_en = scan_owns_mem & ~scan_sel_dmem & scan_we;
        
            imem_narrow_top u_imem (
                .clk(clk), .rst_n(rst_n),
                .req(instr_req_i), .gnt(instr_gnt_o), .addr(instr_addr_i),
                .rvalid(instr_rvalid_o), .rdata(instr_rdata_o),
                .ld_word_en(imem_ld_en), .ld_word_addr(scan_addr),
                .ld_word_data(scan_wdata), .ld_busy()
            );
        endmodule
        
