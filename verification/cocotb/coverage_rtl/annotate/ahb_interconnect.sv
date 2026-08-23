//      // verilator_coverage annotation
        // ============================================================================
        // ahb_interconnect.sv - my AHB-Lite decoder + response multiplexor
        //
        // This is the traffic controller. One master (Ibex, via the adapter) talks AHB
        // to me, and I fan it out to N slaves (data mem, GPIO, UART, SPI). I do two jobs:
        //   1. DECODE: look at HADDR in the address phase, assert HSEL for exactly one slave.
        //   2. MUX: route the selected slave's HRDATA / HREADY / HRESP back to the master.
        //
        // THE KEY AHB TIMING FACT: AHB is pipelined. The address is on the bus ONE CYCLE
        // before its data. So I decode HSEL from the address phase, but the read data
        // (HRDATA) that comes back belongs to the address from the PREVIOUS cycle. That's
        // why I register the selection ("sel_q") by one cycle before I use it to mux the
        // response. Control is a cycle ahead of data - same idea as my rvalid flip-flop.
        //
        // I'm building this for 4 slaves. Slave index:
        //   0 = data memory   1 = GPIO   2 = UART   3 = SPI
        // The address regions come straight from my memory_map.md.
        // ============================================================================
        
        module ahb_interconnect (
 103918     input  logic        HCLK,          // AHB clock (same as my system clock).
 000039     input  logic        HRESETn,       // AHB reset, active-low.
        
            // ---- from the master (Ibex adapter drives these) ----
~000199     input  logic [31:0] HADDR,         // address for this transfer.
%000003     input  logic [1:0]  HTRANS,        // transfer type. bit[1]=1 means a real transfer.
%000003     input  logic        HWRITE,        // 1 = write, 0 = read.
%000002     input  logic [31:0] HWDATA,        // write data (valid in the data phase).
        
            // ---- back to the master ----
%000002     output logic [31:0] HRDATA,        // read data from the selected slave.
%000007     output logic        HREADY,        // 1 = transfer complete (from selected slave).
%000000     output logic        HRESP,         // 0 = OKAY, 1 = ERROR.
        
            // ---- to/from the 4 slaves ----
            // I broadcast address/control to all slaves and pick one with HSEL.
%000001     output logic [3:0]  HSEL,          // one-hot select, one bit per slave.
~000199     output logic [31:0] slv_HADDR,     // shared address to all slaves.
%000003     output logic [1:0]  slv_HTRANS,    // shared transfer type.
%000003     output logic        slv_HWRITE,    // shared write flag.
%000002     output logic [31:0] slv_HWDATA,    // shared write data.
        
            // each slave hands back its own read data / ready / resp:
%000001     input  logic [31:0] s0_HRDATA, input logic s0_HREADY, input logic s0_HRESP,
%000007     input  logic [31:0] s1_HRDATA, input logic s1_HREADY, input logic s1_HRESP,
%000007     input  logic [31:0] s2_HRDATA, input logic s2_HREADY, input logic s2_HRESP,
%000007     input  logic [31:0] s3_HRDATA, input logic s3_HREADY, input logic s3_HRESP
        );
        
            // --------------------------------------------------------------------
            // 1) Broadcast the shared master signals to every slave. They all SEE the
            //    address/control; only the one with HSEL set will act on it.
            // --------------------------------------------------------------------
            assign slv_HADDR  = HADDR;
            assign slv_HTRANS = HTRANS;
            assign slv_HWRITE = HWRITE;
            assign slv_HWDATA = HWDATA;
        
            // --------------------------------------------------------------------
            // 2) DECODE (address phase). Look at the address and pick one slave.
            //    HTRANS[1] = 1 means "this is a real transfer" (not IDLE/BUSY). If it's
            //    idle, I select nobody. I decode on the high address bits per my map:
            //      data mem : 0x0000_0xxx  (region 0)
            //      GPIO     : 0x0001_xxxx  (region 1)
            //      UART     : 0x0002_xxxx  (region 2)
            //      SPI      : 0x0003_xxxx  (region 3)
            //    I look at HADDR[17:16] to pick the region cheaply.
            // --------------------------------------------------------------------
%000003     logic        active;               // is this a real transfer this cycle?
%000002     logic [1:0]  region;               // which region the address falls in.
        
            assign active = HTRANS[1];         // top bit of HTRANS set = NONSEQ or SEQ = real.
            assign region = HADDR[17:16];      // 00=mem, 01=GPIO, 10=UART, 11=SPI.
        
 117565     always_comb begin
 117565         HSEL = 4'b0000;                // default: nobody selected.
 117553         if (active) begin
 000012             HSEL[region] = 1'b1;       // one-hot: light up exactly the chosen slave.
                end
            end
        
            // --------------------------------------------------------------------
            // 3) Register the selection by ONE cycle. The response (HRDATA/HREADY) that
            //    comes back this cycle belongs to the address from LAST cycle, so I mux
            //    the response using the PREVIOUS selection, not the current one.
            // --------------------------------------------------------------------
%000002     logic [1:0] region_q;              // which slave was selected last cycle.
%000003     logic       active_q;              // was last cycle a real transfer?
        
 103956     always_ff @(posedge HCLK or negedge HRESETn) begin
 103918         if (!HRESETn) begin
 000038             region_q <= 2'b00;
 000038             active_q <= 1'b0;
 103918         end else begin
 103918             region_q <= region;        // remember this cycle's region for next cycle's data phase.
 103918             active_q <= active;
                end
            end
        
            // --------------------------------------------------------------------
            // 4) MUX the response back to the master, based on the REGISTERED selection.
            //    Pick the read data / ready / resp of whichever slave was addressed last cycle.
            // --------------------------------------------------------------------
 117565     always_comb begin
 117565         case (region_q)
 117547             2'b00: begin HRDATA = s0_HRDATA; HREADY = s0_HREADY; HRESP = s0_HRESP; end
%000006             2'b01: begin HRDATA = s1_HRDATA; HREADY = s1_HREADY; HRESP = s1_HRESP; end
%000006             2'b10: begin HRDATA = s2_HRDATA; HREADY = s2_HREADY; HRESP = s2_HRESP; end
%000006             2'b11: begin HRDATA = s3_HRDATA; HREADY = s3_HREADY; HRESP = s3_HRESP; end
%000000             default: begin HRDATA = 32'h0; HREADY = 1'b1; HRESP = 1'b0; end
                endcase
            end
        
        endmodule
        
