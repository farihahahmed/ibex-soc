module ahb_mem (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [3:0]  HWSTRB,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP
);
    assign HRESP = 1'b0;

    logic sel_access;
    assign sel_access = HSEL & HTRANS[1];

    logic        m_req, m_gnt, m_we, m_rvalid;
    logic [3:0]  m_be;
    logic [31:0] m_addr, m_wdata, m_rdata;

    dmem_narrow_top u_dmem (
        .clk(HCLK), .rst_n(HRESETn),
        .req(m_req), .gnt(m_gnt), .we(m_we), .be(m_be),
        .addr(m_addr), .wdata(m_wdata),
        .rvalid(m_rvalid), .rdata(m_rdata),
        .ld_word_en(1'b0), .ld_word_addr(16'b0), .ld_word_data(32'b0), .ld_busy()
    );

    typedef enum logic [1:0] { A_IDLE, A_BUSY, A_DONE } astate_t;
    astate_t astate;

    logic        acc_we;
    logic [3:0]  acc_be;
    logic [31:0] acc_addr, acc_wdata;
    logic        kicked;

    always_ff @(posedge HCLK or negedge HRESETn) begin
        if (!HRESETn) begin
            astate<=A_IDLE; acc_we<=0; acc_be<=0; acc_addr<=0; acc_wdata<=0; kicked<=0;
        end else begin
            case (astate)
                A_IDLE: begin
                    kicked <= 1'b0;
                    if (sel_access) begin
                        acc_we   <= HWRITE;
                        acc_be   <= HWSTRB;
                        acc_addr <= HADDR;
                        astate   <= A_BUSY;
                    end
                end
                A_BUSY: begin
                    // capture write data (valid in data phase = first A_BUSY cycle)
                    if (!kicked) acc_wdata <= HWDATA;
                    if (!kicked && m_gnt) kicked <= 1'b1;
                    if (m_rvalid) astate <= A_DONE;
                end
                A_DONE: astate <= A_IDLE;
                default: astate <= A_IDLE;
            endcase
        end
    end

    assign m_req   = (astate==A_BUSY) && !kicked;
    assign m_we    = acc_we;
    assign m_be    = acc_be;
    assign m_addr  = acc_addr;
    assign m_wdata = kicked ? acc_wdata : HWDATA;

    assign HREADY = (astate==A_IDLE) || (astate==A_DONE);
    assign HRDATA = m_rdata;
endmodule
