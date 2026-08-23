//      // verilator_coverage annotation
        module dmem_narrow_top (
 103918     input  logic        clk,
 000039     input  logic        rst_n,
%000000     input  logic        req,
%000000     output logic        gnt,
%000000     input  logic        we,
%000000     input  logic [3:0]  be,
%000000     input  logic [31:0] addr,
%000002     input  logic [31:0] wdata,
%000000     output logic        rvalid,
%000000     output logic [31:0] rdata,
%000000     input  logic        ld_word_en,
%000000     input  logic [15:0] ld_word_addr,
%000000     input  logic [31:0] ld_word_data,
%000000     output logic        ld_busy
        );
%000000     logic        b_req, b_sel, b_we, b_rvalid;
%000000     logic [31:0] b_addr;
%000000     logic [7:0]  b_wdata, b_rdata;
        
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
%000000     state_t state;
        
%000000     logic [31:0] base_addr, wdata_lat;
%000000     logic [3:0]  be_lat;
%000000     logic [2:0]  issue_cnt, cap_cnt;
%000000     logic [7:0]  b0,b1,b2,b3;
%000000     logic [31:0] lword;
%000000     logic [8:0]  lbase;
%000000     logic [31:0] addr_aligned;
            assign addr_aligned = {26'b0, addr[5:2], 2'b00};
        
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) begin
 000038             state<=D_IDLE; base_addr<=0; wdata_lat<=0; be_lat<=0;
 000038             issue_cnt<=0; cap_cnt<=0; b0<=0;b1<=0;b2<=0;b3<=0;
 000038             lword<=0; lbase<=0;
 103918         end else begin
 103918             case (state)
 103918                 D_IDLE: begin
%000000                     if (ld_word_en) begin
%000000                         lword <= ld_word_data;
%000000                         lbase <= {5'b0, ld_word_addr[3:0], 2'b00};
%000000                         state <= L_B0;
~103918                     end else if (req) begin
%000000                         base_addr <= addr_aligned;
%000000                         wdata_lat <= wdata;
%000000                         be_lat    <= be;
%000000                         issue_cnt <= 0; cap_cnt <= 0;
%000000                         if (we) state <= W_B0;
%000000                         else    state <= R_STREAM;
                            end
                        end
%000000                 R_STREAM: begin
%000000                     if (issue_cnt < 3'd4) issue_cnt <= issue_cnt + 3'd1;
%000000                     if (b_rvalid) begin
%000000                         case (cap_cnt[1:0])
%000000                             2'd0: b0<=b_rdata; 2'd1: b1<=b_rdata;
%000000                             2'd2: b2<=b_rdata; 2'd3: b3<=b_rdata;
                                endcase
%000000                         cap_cnt <= cap_cnt + 3'd1;
                            end
%000000                     if (issue_cnt == 3'd4) state <= R_DRAIN;
                        end
%000000                 R_DRAIN: begin
%000000                     if (b_rvalid) begin
%000000                         case (cap_cnt[1:0])
%000000                             2'd0: b0<=b_rdata; 2'd1: b1<=b_rdata;
%000000                             2'd2: b2<=b_rdata; 2'd3: b3<=b_rdata;
                                endcase
%000000                         cap_cnt <= cap_cnt + 3'd1;
                            end
%000000                     if (cap_cnt == 3'd4) state <= R_PRESENT;
                        end
%000000                 R_PRESENT: state <= D_IDLE;
%000000                 W_B0: state <= W_B1;
%000000                 W_B1: state <= W_B2;
%000000                 W_B2: state <= W_B3;
%000000                 W_B3: state <= W_DONE;
%000000                 W_DONE: state <= D_IDLE;
%000000                 L_B0: state <= L_B1;
%000000                 L_B1: state <= L_B2;
%000000                 L_B2: state <= L_B3;
%000000                 L_B3: state <= D_IDLE;
%000000                 default: state <= D_IDLE;
                    endcase
                end
            end
        
 103957     always_comb begin
 103957         b_req=1'b0; b_sel=1'b0; b_we=1'b0; b_addr=32'b0; b_wdata=8'b0;
 103957         case (state)
%000000             R_STREAM: begin
%000000                 b_sel=1'b1;
%000000                 if (issue_cnt < 3'd4) begin
%000000                     b_req=1'b1; b_addr=base_addr + {29'b0, issue_cnt[1:0]};
%000000                 end else begin
%000000                     b_addr=base_addr + 32'd3;
                        end
                    end
%000000             R_DRAIN: begin b_sel=1'b1; b_addr=base_addr + 32'd3; end
%000000             W_B0: if (be_lat[0]) begin b_req=1;b_we=1;b_addr=base_addr+0;b_wdata=wdata_lat[7:0];   end
%000000             W_B1: if (be_lat[1]) begin b_req=1;b_we=1;b_addr=base_addr+1;b_wdata=wdata_lat[15:8];  end
%000000             W_B2: if (be_lat[2]) begin b_req=1;b_we=1;b_addr=base_addr+2;b_wdata=wdata_lat[23:16]; end
%000000             W_B3: if (be_lat[3]) begin b_req=1;b_we=1;b_addr=base_addr+3;b_wdata=wdata_lat[31:24]; end
%000000             L_B0: begin b_req=1;b_we=1;b_addr={23'b0,lbase}+0;b_wdata=lword[7:0];   end
%000000             L_B1: begin b_req=1;b_we=1;b_addr={23'b0,lbase}+1;b_wdata=lword[15:8];  end
%000000             L_B2: begin b_req=1;b_we=1;b_addr={23'b0,lbase}+2;b_wdata=lword[23:16]; end
%000000             L_B3: begin b_req=1;b_we=1;b_addr={23'b0,lbase}+3;b_wdata=lword[31:24]; end
 103957             default: ;
                endcase
            end
        
            assign gnt     = (state==D_IDLE) && req && !ld_word_en;
            assign rvalid  = (state==R_PRESENT) || (state==W_DONE);
            assign rdata   = {b3,b2,b1,b0};
            assign ld_busy = (state==L_B0)||(state==L_B1)||(state==L_B2)||(state==L_B3);
        endmodule
        
