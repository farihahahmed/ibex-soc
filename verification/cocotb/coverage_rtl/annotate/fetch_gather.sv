//      // verilator_coverage annotation
        module fetch_gather (
 117488     input  logic        clk,
 000039     input  logic        rst_n,
 000399     input  logic        c_req,
 000876     output logic        c_gnt,
~000199     input  logic [31:0] c_addr,
 000837     output logic        c_rvalid,
~000233     output logic [31:0] c_rdata,
 000876     output logic        m_req,
 000876     output logic        m_sel,
%000001     input  logic        m_gnt,
~002624     output logic [31:0] m_addr,
 000876     input  logic        m_rvalid,
 001830     input  logic [7:0]  m_rdata
        );
            typedef enum logic [1:0] { IDLE, STREAM, DRAIN, PRESENT } state_t;
 001713     state_t state;
~000199     logic [31:0] base_addr;
 001750     logic [2:0]  issue_cnt;
 001712     logic [2:0]  cap_cnt;
~000233     logic [7:0]  b0,b1,b2,b3;
        
 117526     always_ff @(posedge clk or negedge rst_n) begin
 116940         if (!rst_n) begin
 000586             state<=IDLE; base_addr<=32'b0; issue_cnt<=0; cap_cnt<=0;
 000586             b0<=0;b1<=0;b2<=0;b3<=0;
 116940         end else begin
 116940             case (state)
 002361                 IDLE: if (c_req) begin
 000876                         base_addr<=c_addr; issue_cnt<=0; cap_cnt<=0; state<=STREAM;
                            end
 004373                 STREAM: begin
 003499                     if (issue_cnt < 3'd4) issue_cnt<=issue_cnt+3'd1;
 003386                     if (m_rvalid) begin
 003386                         case (cap_cnt[1:0])
 000875                             2'd0: b0<=m_rdata; 2'd1: b1<=m_rdata;
 000837                             2'd2: b2<=m_rdata; 2'd3: b3<=m_rdata;
                                endcase
 003386                         cap_cnt<=cap_cnt+3'd1;
                            end
 003499                     if (issue_cnt==3'd4) state<=DRAIN;
                        end
 109369                 DRAIN: begin
~109369                     if (m_rvalid) begin
%000000                         case (cap_cnt[1:0])
%000000                             2'd0: b0<=m_rdata; 2'd1: b1<=m_rdata;
%000000                             2'd2: b2<=m_rdata; 2'd3: b3<=m_rdata;
                                endcase
%000000                         cap_cnt<=cap_cnt+3'd1;
                            end
 108532                     if (cap_cnt==3'd4) state<=PRESENT;
                        end
 000837                 PRESENT: state<=IDLE;
%000000                 default: state<=IDLE;
                    endcase
                end
            end
            assign m_req  = (state==STREAM) && (issue_cnt < 3'd4);
            assign m_sel  = (state==STREAM) || (state==DRAIN);
 109406     assign m_addr = (state==DRAIN) ? (base_addr + 32'd3)
 008121                                    : (base_addr + {29'b0, issue_cnt[1:0]});
            assign c_gnt    = (state==IDLE) && c_req;
            assign c_rvalid = (state==PRESENT);
            assign c_rdata  = {b3,b2,b1,b0};
        endmodule
        
