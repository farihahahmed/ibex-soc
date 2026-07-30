module fetch_gather (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        c_req,
    output logic        c_gnt,
    input  logic [31:0] c_addr,
    output logic        c_rvalid,
    output logic [31:0] c_rdata,
    output logic        m_req,
    input  logic        m_gnt,
    output logic [31:0] m_addr,
    input  logic        m_rvalid,
    input  logic [7:0]  m_rdata
);
    typedef enum logic [1:0] { IDLE, GATHER, PRESENT } state_t;
    state_t state;
    logic [31:0] base_addr;
    logic [2:0]  issue_cnt;
    logic [2:0]  cap_cnt;
    logic [7:0]  b [0:3];
    logic do_issue;
    assign do_issue = (state == GATHER) && (issue_cnt < 3'd4);
    assign m_req  = do_issue;
    assign m_addr = base_addr + {29'b0, issue_cnt[1:0]};
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; base_addr <= 32'b0; issue_cnt <= 3'd0; cap_cnt <= 3'd0;
            b[0]<=8'b0; b[1]<=8'b0; b[2]<=8'b0; b[3]<=8'b0;
        end else begin
            case (state)
                IDLE: if (c_req) begin
                        base_addr <= c_addr; issue_cnt <= 3'd0; cap_cnt <= 3'd0; state <= GATHER;
                    end
                GATHER: begin
                    if (do_issue) issue_cnt <= issue_cnt + 3'd1;
                    if (m_rvalid) begin
                        b[cap_cnt[1:0]] <= m_rdata;
                        cap_cnt <= cap_cnt + 3'd1;
                    end
                    if (m_rvalid && cap_cnt == 3'd3) state <= PRESENT;
                end
                PRESENT: state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
    assign c_gnt    = (state == IDLE) && c_req;
    assign c_rvalid = (state == PRESENT);
    assign c_rdata  = {b[3], b[2], b[1], b[0]};
endmodule
