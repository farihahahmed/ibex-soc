//      // verilator_coverage annotation
        module ahb_mem (
 103918     input  logic        HCLK,
 000039     input  logic        HRESETn,
%000000     input  logic        HSEL,
~000199     input  logic [31:0] HADDR,
%000003     input  logic [1:0]  HTRANS,
%000003     input  logic        HWRITE,
%000003     input  logic [3:0]  HWSTRB,
%000002     input  logic [31:0] HWDATA,
%000000     output logic [31:0] HRDATA,
%000001     output logic        HREADY,
%000000     output logic        HRESP
        );
            assign HRESP = 1'b0;
        
%000000     logic sel_access;
            assign sel_access = HSEL & HTRANS[1];
        
%000000     logic        m_req, m_gnt, m_we, m_rvalid;
%000000     logic [3:0]  m_be;
%000002     logic [31:0] m_addr, m_wdata, m_rdata;
        
            dmem_narrow_top u_dmem (
                .clk(HCLK), .rst_n(HRESETn),
                .req(m_req), .gnt(m_gnt), .we(m_we), .be(m_be),
                .addr(m_addr), .wdata(m_wdata),
                .rvalid(m_rvalid), .rdata(m_rdata),
                .ld_word_en(1'b0), .ld_word_addr(16'b0), .ld_word_data(32'b0), .ld_busy()
            );
        
            typedef enum logic [1:0] { A_IDLE, A_BUSY, A_DONE } astate_t;
%000000     astate_t astate;
        
%000000     logic        acc_we;
%000000     logic [3:0]  acc_be;
%000000     logic [31:0] acc_addr, acc_wdata;
%000000     logic        kicked;
        
 103956     always_ff @(posedge HCLK or negedge HRESETn) begin
 103918         if (!HRESETn) begin
 000038             astate<=A_IDLE; acc_we<=0; acc_be<=0; acc_addr<=0; acc_wdata<=0; kicked<=0;
 103918         end else begin
 103918             case (astate)
 103918                 A_IDLE: begin
 103918                     kicked <= 1'b0;
~103918                     if (sel_access) begin
%000000                         acc_we   <= HWRITE;
%000000                         acc_be   <= HWSTRB;
%000000                         acc_addr <= HADDR;
%000000                         astate   <= A_BUSY;
                            end
                        end
%000000                 A_BUSY: begin
                            // capture write data (valid in data phase = first A_BUSY cycle)
~103918                     if (!kicked) acc_wdata <= HWDATA;
~103918                     if (!kicked && m_gnt) kicked <= 1'b1;
%000000                     if (m_rvalid) astate <= A_DONE;
                        end
%000000                 A_DONE: astate <= A_IDLE;
%000000                 default: astate <= A_IDLE;
                    endcase
                end
            end
        
            assign m_req   = (astate==A_BUSY) && !kicked;
            assign m_we    = acc_we;
            assign m_be    = acc_be;
            assign m_addr  = acc_addr;
~103957     assign m_wdata = kicked ? acc_wdata : HWDATA;
        
            assign HREADY = (astate==A_IDLE) || (astate==A_DONE);
            assign HRDATA = m_rdata;
        endmodule
        
