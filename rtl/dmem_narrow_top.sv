module dmem_narrow_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    output logic        gnt,
    input  logic        we,
    input  logic [3:0]  be,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic        rvalid,
    output logic [31:0] rdata,
    input  logic        ld_word_en,
    input  logic [15:0] ld_word_addr,
    input  logic [31:0] ld_word_data,
    output logic        ld_busy
);
    logic        b_req, b_sel, b_we, b_rvalid;
    logic [31:0] b_addr;
    logic [7:0]  b_wdata, b_rdata;

    dmem_narrow #(.ADDR_BITS(6)) u_mem (
        .clk(clk), .rst_n(rst_n),
        .b_req(b_req), .b_sel(b_sel), .b_we(b_we),
        .b_addr(b_addr), .b_wdata(b_wdata),
        .b_rvalid(b_rvalid), .b_rdata(b_rdata)
    );

    typedef enum logic [3:0] {
        D_IDLE, R_STREAM, R_DRAIN, R_PRESENT,
        W_B0, W_B1, W_B2, W_B3, W_DONE,
        L_B0, L_B1, L_B2, L_B3
    } state_t;
    state_t state;

    logic [31:0] base_addr, wdata_lat;
    logic [3:0]  be_lat;
    logic [2:0]  issue_cnt, cap_cnt;
    logic [7:0]  b0,b1,b2,b3;
    logic [31:0] lword;
    logic [5:0]  lbase;
    logic [31:0] addr_aligned;
    assign addr_aligned = {addr[31:2], 2'b00};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state<=D_IDLE; base_addr<=0; wdata_lat<=0; be_lat<=0;
            issue_cnt<=0; cap_cnt<=0; b0<=0;b1<=0;b2<=0;b3<=0;
            lword<=0; lbase<=0;
        end else begin
            case (state)
                D_IDLE: begin
                    if (ld_word_en) begin
                        lword <= ld_word_data;
                        lbase <= {ld_word_addr[3:0], 2'b00};
                        state <= L_B0;
                    end else if (req) begin
                        base_addr <= addr_aligned;
                        wdata_lat <= wdata;
                        be_lat    <= be;
                        issue_cnt <= 0; cap_cnt <= 0;
                        if (we) state <= W_B0;
                        else    state <= R_STREAM;
                    end
                end
                R_STREAM: begin
                    if (issue_cnt < 3'd4) issue_cnt <= issue_cnt + 3'd1;
                    if (b_rvalid) begin
                        case (cap_cnt[1:0])
                            2'd0: b0<=b_rdata; 2'd1: b1<=b_rdata;
                            2'd2: b2<=b_rdata; 2'd3: b3<=b_rdata;
                        endcase
                        cap_cnt <= cap_cnt + 3'd1;
                    end
                    if (issue_cnt == 3'd4) state <= R_DRAIN;
                end
                R_DRAIN: begin
                    if (b_rvalid) begin
                        case (cap_cnt[1:0])
                            2'd0: b0<=b_rdata; 2'd1: b1<=b_rdata;
                            2'd2: b2<=b_rdata; 2'd3: b3<=b_rdata;
                        endcase
                        cap_cnt <= cap_cnt + 3'd1;
                    end
                    if (cap_cnt == 3'd4) state <= R_PRESENT;
                end
                R_PRESENT: state <= D_IDLE;
                W_B0: state <= W_B1;
                W_B1: state <= W_B2;
                W_B2: state <= W_B3;
                W_B3: state <= W_DONE;
                W_DONE: state <= D_IDLE;
                L_B0: state <= L_B1;
                L_B1: state <= L_B2;
                L_B2: state <= L_B3;
                L_B3: state <= D_IDLE;
                default: state <= D_IDLE;
            endcase
        end
    end

    always_comb begin
        b_req=1'b0; b_sel=1'b0; b_we=1'b0; b_addr=32'b0; b_wdata=8'b0;
        case (state)
            R_STREAM: begin
                b_sel=1'b1;
                if (issue_cnt < 3'd4) begin
                    b_req=1'b1; b_addr=base_addr + {29'b0, issue_cnt[1:0]};
                end else begin
                    b_addr=base_addr + 32'd3;
                end
            end
            R_DRAIN: begin b_sel=1'b1; b_addr=base_addr + 32'd3; end
            W_B0: if (be_lat[0]) begin b_req=1;b_we=1;b_addr=base_addr+0;b_wdata=wdata_lat[7:0];   end
            W_B1: if (be_lat[1]) begin b_req=1;b_we=1;b_addr=base_addr+1;b_wdata=wdata_lat[15:8];  end
            W_B2: if (be_lat[2]) begin b_req=1;b_we=1;b_addr=base_addr+2;b_wdata=wdata_lat[23:16]; end
            W_B3: if (be_lat[3]) begin b_req=1;b_we=1;b_addr=base_addr+3;b_wdata=wdata_lat[31:24]; end
            L_B0: begin b_req=1;b_we=1;b_addr={26'b0,lbase}+0;b_wdata=lword[7:0];   end
            L_B1: begin b_req=1;b_we=1;b_addr={26'b0,lbase}+1;b_wdata=lword[15:8];  end
            L_B2: begin b_req=1;b_we=1;b_addr={26'b0,lbase}+2;b_wdata=lword[23:16]; end
            L_B3: begin b_req=1;b_we=1;b_addr={26'b0,lbase}+3;b_wdata=lword[31:24]; end
            default: ;
        endcase
    end

    assign gnt     = (state==D_IDLE) && req && !ld_word_en;
    assign rvalid  = (state==R_PRESENT) || (state==W_DONE);
    assign rdata   = {b3,b2,b1,b0};
    assign ld_busy = (state==L_B0)||(state==L_B1)||(state==L_B2)||(state==L_B3);
endmodule
