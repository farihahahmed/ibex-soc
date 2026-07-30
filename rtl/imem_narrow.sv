module imem_narrow (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        m_req,
    input  logic        m_sel,
    output logic        m_gnt,
    input  logic [31:0] m_addr,
    output logic        m_rvalid,
    output logic [7:0]  m_rdata,
    input  logic        ld_en,
    input  logic [8:0]  ld_addr,
    input  logic [7:0]  ld_data
);
    assign m_gnt = 1'b1;
    logic        cen, gwen;
    logic [7:0]  wen, d, q;
    logic [8:0]  a;
    logic [8:0]  rd_addr;
    assign rd_addr = m_addr[8:0];

    always_comb begin
        if (ld_en) begin
            cen=1'b0; gwen=1'b0; wen=8'h00; a=ld_addr; d=ld_data;
        end else if (m_sel) begin
            cen=1'b0; gwen=1'b1; wen=8'hFF; a=rd_addr; d=8'h00;
        end else begin
            cen=1'b1; gwen=1'b1; wen=8'hFF; a=9'b0; d=8'h00;
        end
    end

    supply1 vdd; supply0 vss;
    gf180mcu_fd_ip_sram__sram512x8m8wm1 u_sram (
        .CLK(clk), .CEN(cen), .GWEN(gwen), .WEN(wen),
        .A(a), .D(d), .Q(q), .VDD(vdd), .VSS(vss)
    );

    logic rd_pending;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rd_pending <= 1'b0;
        else        rd_pending <= m_req & ~ld_en;
    end
    assign m_rvalid = rd_pending;
    assign m_rdata  = q;
endmodule
