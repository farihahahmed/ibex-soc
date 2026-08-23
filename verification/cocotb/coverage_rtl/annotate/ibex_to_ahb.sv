//      // verilator_coverage annotation
        // ============================================================================
        // ibex_to_ahb.sv - Ibex -> AHB-Lite master.
        //
        // FIX (v0.2 integration): Ibex's data port needs rvalid to pulse for WRITES as
        // well as reads - that's how its load/store unit knows a store completed and it
        // can move on. My earlier version only tracked reads (read_inflight = gnt & ~we),
        // so after a store rvalid never fired and the CPU stalled forever waiting.
        //
        // Now I track ANY granted access (read or write) as "in flight" and pulse rvalid
        // one cycle after it completes. For a read that also delivers the data; for a
        // write it's just the completion acknowledge Ibex is waiting for.
        //
        // Write data is driven combinationally (Ibex holds it stable during the request);
        // registering it caused stale data on back-to-back writes.
        // ============================================================================
        
        module ibex_to_ahb (
 103918     input  logic        clk,
 000039     input  logic        rst_n,
        
%000003     input  logic        req,
%000006     output logic        gnt,
%000003     input  logic        we,
%000003     input  logic [3:0]  be,
~000199     input  logic [31:0] addr,
%000002     input  logic [31:0] wdata,
%000006     output logic        rvalid,
%000002     output logic [31:0] rdata,
        
~000199     output logic [31:0] HADDR,
%000003     output logic [1:0]  HTRANS,
%000003     output logic        HWRITE,
%000003     output logic [3:0]  HWSTRB,
%000002     output logic [31:0] HWDATA,
%000002     input  logic [31:0] HRDATA,
%000007     input  logic        HREADY,
%000000     input  logic        HRESP
        );
        
            localparam logic [1:0] TRANS_IDLE   = 2'b00;
            localparam logic [1:0] TRANS_NONSEQ = 2'b10;
        
            assign HADDR  = addr;
 117553     assign HTRANS = req ? TRANS_NONSEQ : TRANS_IDLE;
            assign HWRITE = we;
            assign HWSTRB = be;
        
            assign gnt = req & HREADY;
        
            // write data driven directly (stable during the request).
            assign HWDATA = wdata;
        
            // Track ANY granted access (read OR write) as in-flight, so rvalid pulses on
            // completion for both. This is the fix: writes now get a completion pulse.
%000003     logic access_inflight;
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n)         access_inflight <= 1'b0;
%000006         else if (gnt)       access_inflight <= 1'b1;   // any granted access (read or write)
~103903         else if (HREADY)    access_inflight <= 1'b0;
            end
        
%000006     logic data_phase_done;
            assign data_phase_done = access_inflight & HREADY;
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) rvalid <= 1'b0;
 103918         else        rvalid <= data_phase_done;
            end
        
            assign rdata = HRDATA;
        
        endmodule
        
