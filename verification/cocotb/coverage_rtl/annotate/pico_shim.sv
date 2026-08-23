//      // verilator_coverage annotation
        // ============================================================================
        // pico_shim.sv - PicoRV32 unified memory port -> two existing CPU-side buses.
        // Demuxes Pico's single mem port by mem_instr:
        //   fetch  -> mem_subsystem (imem)   |   data -> ibex_to_ahb -> AHB bus
        // ============================================================================
        module pico_shim (
 103918     input  logic        clk,
 000039     input  logic        rst_n,
        
 000439     input  logic        mem_valid,
%000004     input  logic        mem_instr,
 000401     output logic        mem_ready,
~000199     input  logic [31:0] mem_addr,
%000002     input  logic [31:0] mem_wdata,
%000003     input  logic [3:0]  mem_wstrb,
~000232     output logic [31:0] mem_rdata,
        
 000399     output logic        instr_req,
 000876     input  logic        instr_gnt,
~000199     output logic [31:0] instr_addr,
 000837     input  logic        instr_rvalid,
~000233     input  logic [31:0] instr_rdata,
        
%000003     output logic        data_req,
%000006     input  logic        data_gnt,
%000003     output logic        data_we,
%000003     output logic [3:0]  data_be,
~000199     output logic [31:0] data_addr,
%000002     output logic [31:0] data_wdata,
%000006     input  logic        data_rvalid,
%000002     input  logic [31:0] data_rdata
        );
 000439     logic inflight, sel_instr;
 000439     logic launch;
            assign launch = mem_valid & ~inflight & ~mem_ready;
        
%000004     logic want_instr;
            assign want_instr = mem_instr;
        
            assign instr_req  = (launch & want_instr) | (inflight & sel_instr);
            assign instr_addr = mem_addr;
        
            assign data_req   = (launch & ~want_instr) | (inflight & ~sel_instr);
            assign data_we    = |mem_wstrb;
            assign data_be    = mem_wstrb;
            assign data_addr  = mem_addr;
            assign data_wdata = mem_wdata;
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             inflight  <= 1'b0;
 000038             sel_instr <= 1'b0;
 000439         end else if (launch) begin
 000439             inflight  <= 1'b1;
 000439             sel_instr <= want_instr;
 103078         end else if (mem_ready) begin
 000401             inflight  <= 1'b0;
                end
            end
        
 000401     logic done;
            assign done = inflight & (sel_instr ? instr_rvalid : data_rvalid);
            assign mem_ready = done;
 103896     assign mem_rdata = sel_instr ? instr_rdata : data_rdata;
        endmodule
        
