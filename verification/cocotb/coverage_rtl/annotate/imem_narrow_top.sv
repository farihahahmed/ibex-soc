//      // verilator_coverage annotation
        module imem_narrow_top (
 117488     input  logic        clk,
 000039     input  logic        rst_n,
 000399     input  logic        req,
 000876     output logic        gnt,
~000199     input  logic [31:0] addr,
 000837     output logic        rvalid,
~000233     output logic [31:0] rdata,
 000177     input  logic        ld_word_en,
~001057     input  logic [15:0] ld_word_addr,
 001057     input  logic [31:0] ld_word_data,
 000177     output logic        ld_busy
        );
~000876     logic        g_m_req, g_m_sel, g_m_gnt, g_m_rvalid;
~002624     logic [31:0] g_m_addr;
 001830     logic [7:0]  g_m_rdata;
 000177     logic        s_ld_en;
~000354     logic [7:0]  s_ld_addr;
 000247     logic [7:0]  s_ld_data;
        
            typedef enum logic [2:0] { S_IDLE, S_B0, S_B1, S_B2, S_B3 } sstate_t;
 000354     sstate_t sstate;
~000082     logic [31:0] word_lat;
~000087     logic [7:0]  base_lat;
        
 117526     always_ff @(posedge clk or negedge rst_n) begin
 116940         if (!rst_n) begin
 000586             sstate <= S_IDLE; word_lat <= 32'b0; base_lat <= 8'b0;
 116940         end else begin
 116940             case (sstate)
 116232                 S_IDLE: if (ld_word_en) begin
 000177                             word_lat <= ld_word_data;
 000177                             base_lat <= {2'b0, ld_word_addr[5:0], 2'b00};
 000177                             sstate   <= S_B0;
                                end
 000177                 S_B0: sstate <= S_B1;
 000177                 S_B1: sstate <= S_B2;
 000177                 S_B2: sstate <= S_B3;
 000177                 S_B3: sstate <= S_IDLE;
%000000                 default: sstate <= S_IDLE;
                    endcase
                end
            end
        
 117527     always_comb begin
 117527         s_ld_en   = 1'b0;
 117527         s_ld_addr = 8'b0;
 117527         s_ld_data = 8'b0;
 117527         case (sstate)
 000177             S_B0: begin s_ld_en=1; s_ld_addr=base_lat+8'd0; s_ld_data=word_lat[7:0];   end
 000177             S_B1: begin s_ld_en=1; s_ld_addr=base_lat+8'd1; s_ld_data=word_lat[15:8];  end
 000177             S_B2: begin s_ld_en=1; s_ld_addr=base_lat+8'd2; s_ld_data=word_lat[23:16]; end
 000177             S_B3: begin s_ld_en=1; s_ld_addr=base_lat+8'd3; s_ld_data=word_lat[31:24]; end
 116819             default: ;
                endcase
            end
            assign ld_busy = (sstate != S_IDLE);
        
            fetch_gather u_gather (
                .clk(clk), .rst_n(rst_n),
                .c_req(req), .c_gnt(gnt), .c_addr(addr),
                .c_rvalid(rvalid), .c_rdata(rdata),
                .m_req(g_m_req), .m_sel(g_m_sel), .m_gnt(g_m_gnt),
                .m_addr(g_m_addr), .m_rvalid(g_m_rvalid), .m_rdata(g_m_rdata)
            );
            imem_narrow u_mem (
                .clk(clk), .rst_n(rst_n),
                .m_req(g_m_req), .m_sel(g_m_sel), .m_gnt(g_m_gnt),
                .m_addr(g_m_addr), .m_rvalid(g_m_rvalid), .m_rdata(g_m_rdata),
                .ld_en(s_ld_en), .ld_addr(s_ld_addr), .ld_data(s_ld_data)
            );
        endmodule
        
