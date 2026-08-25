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
    output logic        ld_busy,
    // ---- scan readback (see scan_chain.sv) ----
    input  logic        scan_owns,      // 1 = scan owns memory, CPU port cut off
    input  logic        rd_word_en,     // pulse to start a readback
    input  logic [15:0] rd_word_addr,   // word address to read
    output logic [31:0] rd_word_data,   // last word read (held until next read)
    output logic        rd_busy
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
            sstate <= S_IDLE; word_lat <= 32'b0; base_lat <= 8'b0;
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

    logic        g_c_req, g_c_gnt, g_c_rvalid;
    logic [31:0] g_c_addr, g_c_rdata;

    // ---- scan readback FSM -------------------------------------------------
    // Reuses the byte-gather path, so a readback returns exactly what a fetch of
    // the same address would. Only runs while scan owns the memory, so it can
    // never collide with a CPU fetch. The result is registered and held, because
    // the scan chain captures it several cycles later (on scan_i0o1).
    typedef enum logic [1:0] { RB_IDLE, RB_REQ, RB_WAIT } rbstate_t;
    rbstate_t    rbstate;
    logic [8:0]  rb_addr;
    logic [31:0] rb_data_q;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rbstate <= RB_IDLE; rb_addr <= 9'b0; rb_data_q <= 32'b0;
        end else begin
            case (rbstate)
                RB_IDLE: if (rd_word_en && !ld_busy && scan_owns) begin
                             rb_addr <= {rd_word_addr[6:0], 2'b00};
                             rbstate <= RB_REQ;
                         end
                RB_REQ:  if (g_c_gnt)    rbstate <= RB_WAIT;
                RB_WAIT: if (g_c_rvalid) begin
                             rb_data_q <= g_c_rdata;
                             rbstate   <= RB_IDLE;
                         end
                default: rbstate <= RB_IDLE;
            endcase
        end
    end

    assign rd_busy      = (rbstate != RB_IDLE);
    assign rd_word_data = rb_data_q;

    // Arbitration: while scan owns the memory the CPU fetch port is cut off and
    // the readback FSM drives the gather unit instead.
    assign g_c_req  = scan_owns ? (rbstate == RB_REQ) : req;
    assign g_c_addr = scan_owns ? {23'b0, rb_addr}    : addr;
    assign gnt      = scan_owns ? 1'b0 : g_c_gnt;
    assign rvalid   = scan_owns ? 1'b0 : g_c_rvalid;
    assign rdata    = g_c_rdata;

    fetch_gather u_gather (
        .clk(clk), .rst_n(rst_n),
        .c_req(g_c_req), .c_gnt(g_c_gnt), .c_addr(g_c_addr),
        .c_rvalid(g_c_rvalid), .c_rdata(g_c_rdata),
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
