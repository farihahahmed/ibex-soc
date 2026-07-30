module fetch_gather (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        c_req,
    output logic        c_gnt,
    input  logic [31:0] c_addr,
    output logic        c_rvalid,
    output logic [31:0] c_rdata,
    output logic        m_req,
    output logic        m_sel,
    input  logic        m_gnt,
    output logic [31:0] m_addr,
    input  logic        m_rvalid,
    input  logic [7:0]  m_rdata
);
    typedef enum logic [1:0] { IDLE, STREAM, DRAIN, PRESENT } state_t;
    state_t state;
    logic [31:0] base_addr;
    logic [2:0]  issue_cnt;
    logic [2:0]  cap_cnt;
    logic [7:0]  b0,b1,b2,b3;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=IDLE; base_addr<=32'b0; issue_cnt<=0; cap_cnt<=0;
            b0<=0;b1<=0;b2<=0;b3<=0;
        end else begin
            case (state)
                IDLE: if (c_req) begin
                        base_addr<=c_addr; issue_cnt<=0; cap_cnt<=0; state<=STREAM;
                    end
                STREAM: begin
                    if (issue_cnt < 3'd4) issue_cnt<=issue_cnt+3'd1;
                    if (m_rvalid) begin
                        case (cap_cnt[1:0])
                            2'd0: b0<=m_rdata; 2'd1: b1<=m_rdata;
                            2'd2: b2<=m_rdata; 2'd3: b3<=m_rdata;
                        endcase
                        cap_cnt<=cap_cnt+3'd1;
                    end
                    if (issue_cnt==3'd4) state<=DRAIN;
                end
                DRAIN: begin
                    if (m_rvalid) begin
                        case (cap_cnt[1:0])
                            2'd0: b0<=m_rdata; 2'd1: b1<=m_rdata;
                            2'd2: b2<=m_rdata; 2'd3: b3<=m_rdata;
                        endcase
                        cap_cnt<=cap_cnt+3'd1;
                    end
                    if (cap_cnt==3'd4) state<=PRESENT;
                end
                PRESENT: state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
    assign m_req  = (state==STREAM) && (issue_cnt < 3'd4);
    assign m_sel  = (state==STREAM) || (state==DRAIN);
    assign m_addr = (state==DRAIN) ? (base_addr + 32'd3)
                                   : (base_addr + {29'b0, issue_cnt[1:0]});
    assign c_gnt    = (state==IDLE) && c_req;
    assign c_rvalid = (state==PRESENT);
    assign c_rdata  = {b3,b2,b1,b0};
endmodule
