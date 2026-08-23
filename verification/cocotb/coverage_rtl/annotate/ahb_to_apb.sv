//      // verilator_coverage annotation
        // ============================================================================
        // ahb_to_apb.sv - AHB-to-APB bridge (read-data timing fixed)
        //
        // AHB slave on one side, APB master on the other. IDLE -> SETUP -> ACCESS.
        //
        // FIXES so far:
        //   - Capture HWDATA in the SETUP cycle (the AHB data phase), not too early.
        //   - Read data: drive HRDATA COMBINATIONALLY from PRDATA in the ACCESS-complete
        //     cycle, so it's present the SAME cycle HREADY goes high. My earlier version
        //     registered the read data, which delayed it one cycle past HREADY/rvalid and
        //     made the read look invalid. Now HRDATA and HREADY line up.
        // ============================================================================
        
        module ahb_to_apb (
 103918     input  logic        HCLK,
 000039     input  logic        HRESETn,
        
%000003     input  logic        HSEL,
~000199     input  logic [31:0] HADDR,
%000003     input  logic [1:0]  HTRANS,
%000003     input  logic        HWRITE,
%000002     input  logic [31:0] HWDATA,
%000002     output logic [31:0] HRDATA,
%000007     output logic        HREADY,
%000000     output logic        HRESP,
        
%000006     output logic        PSEL,
%000006     output logic        PENABLE,
%000001     output logic        PWRITE,
%000002     output logic [31:0] PADDR,
%000002     output logic [31:0] PWDATA,
%000002     input  logic [31:0] PRDATA,
%000001     input  logic        PREADY
        );
        
            assign HRESP = 1'b0;
        
            typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_t;
%000006     state_t state, next_state;
        
%000003     logic ahb_access;
            assign ahb_access = HSEL & HTRANS[1];
        
            // capture address + control in the address phase.
%000002     logic [31:0] addr_q;
%000001     logic        write_q;
 103956     always_ff @(posedge HCLK or negedge HRESETn) begin
 103918         if (!HRESETn) begin
 000038             addr_q <= 32'h0; write_q <= 1'b0;
~103912         end else if (ahb_access && state == IDLE) begin
%000006             addr_q  <= HADDR;
%000006             write_q <= HWRITE;
                end
            end
        
            // capture write data in the SETUP cycle (= AHB data phase).
%000002     logic [31:0] wdata_q;
 103956     always_ff @(posedge HCLK or negedge HRESETn) begin
 103918         if (!HRESETn) wdata_q <= 32'h0;
~103912         else if (state == SETUP) wdata_q <= HWDATA;
            end
        
 117565     always_comb begin
 117565         next_state = state;
 117565         case (state)
~117553             IDLE:   if (ahb_access) next_state = SETUP;
%000006             SETUP:  next_state = ACCESS;
%000006             ACCESS: if (PREADY) next_state = IDLE;
                endcase
            end
        
 103956     always_ff @(posedge HCLK or negedge HRESETn) begin
 103918         if (!HRESETn) state <= IDLE;
 103918         else          state <= next_state;
            end
        
 103957     always_comb begin
~103957         PSEL    = (state == SETUP) || (state == ACCESS);
 103957         PENABLE = (state == ACCESS);
            end
            assign PWRITE = write_q;
            assign PADDR  = addr_q;
            assign PWDATA = wdata_q;
        
            // READ DATA: drive HRDATA straight from PRDATA (combinational). During the
            // ACCESS phase PRDATA is valid, and that's the same cycle HREADY completes
            // the transfer - so HRDATA and HREADY line up, and rvalid sees correct data.
            assign HRDATA = PRDATA;
        
 117565     always_comb begin
 117547         if (state == IDLE && !ahb_access)
 117547             HREADY = 1'b1;
~000012         else if (state == ACCESS && PREADY)
%000006             HREADY = 1'b1;
                else
 000012             HREADY = 1'b0;
            end
        
        endmodule
        
