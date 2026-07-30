module imem_narrow_top (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        req,
    output logic        gnt,
    input  logic [31:0] addr,
    output logic        rvalid,
    output logic [31:0] rdata,
    input  logic        ld_word_en,
    input  logic [15:0] ld_word_addr,
    input  logic [31:0] ld_word_data,
    output logic        ld_busy
);
    logic        g_m_req, g_m_sel, g_m_gnt, g_m_rvalid;
    logic [31:0] g_m_addr;
    logic [7:0]  g_m_rdata;
    logic        s_ld_en;
    logic [8:0]  s_ld_addr;
    logic [7:0]  s_ld_data;

    typedef enum logic [2:0] { S_IDLE, S_B0, S_B1, S_B2, S_B3 } sstate_t;
    sstate_t sstate;
    logic [31:0] word_lat;
    logic [8:0]  base_lat;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sstate <= S_IDLE; word_lat <= 32'b0; base_lat <= 9'b0;
        end else begin
            case (sstate)
                S_IDLE: if (ld_word_en) begin
                            word_lat <= ld_word_data;
                            base_lat <= {ld_word_addr[6:0], 2'b00};
                            sstate   <= S_B0;
                        end
                S_B0: sstate <= S_B1;
                S_B1: sstate <= S_B2;
                S_B2: sstate <= S_B3;
                S_B3: sstate <= S_IDLE;
                default: sstate <= S_IDLE;
            endcase
        end
    end

    always_comb begin
        s_ld_en   = 1'b0;
        s_ld_addr = 9'b0;
        s_ld_data = 8'b0;
        case (sstate)
            S_B0: begin s_ld_en=1; s_ld_addr=base_lat+9'd0; s_ld_data=word_lat[7:0];   end
            S_B1: begin s_ld_en=1; s_ld_addr=base_lat+9'd1; s_ld_data=word_lat[15:8];  end
            S_B2: begin s_ld_en=1; s_ld_addr=base_lat+9'd2; s_ld_data=word_lat[23:16]; end
            S_B3: begin s_ld_en=1; s_ld_addr=base_lat+9'd3; s_ld_data=word_lat[31:24]; end
            default: ;
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
