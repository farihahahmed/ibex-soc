//      // verilator_coverage annotation
        module imem_narrow (
 117488     input  logic        clk,
 000039     input  logic        rst_n,
 000876     input  logic        m_req,
 000876     input  logic        m_sel,
%000001     output logic        m_gnt,
~002624     input  logic [31:0] m_addr,
 000876     output logic        m_rvalid,
 001830     output logic [7:0]  m_rdata,
 000177     input  logic        ld_en,
~000354     input  logic [7:0]  ld_addr,
 000247     input  logic [7:0]  ld_data
        );
            assign m_gnt = 1'b1;
 000857     logic        cen, gwen;
 001830     logic [7:0]  wen, d, q;
~002867     logic [7:0]  a;
~002624     logic [7:0]  rd_addr;
            assign rd_addr = m_addr[7:0];
        
 117527     always_comb begin
 000708         if (ld_en) begin
 000708             cen=1'b0; gwen=1'b0; wen=8'h00; a=ld_addr; d=ld_data;
 113207         end else if (m_sel) begin
 113207             cen=1'b0; gwen=1'b1; wen=8'hFF; a=rd_addr; d=8'h00;
 003612         end else begin
 003612             cen=1'b1; gwen=1'b1; wen=8'hFF; a=8'b0; d=8'h00;
                end
            end
        
            gf180mcu_fd_ip_sram__sram256x8m8wm1 u_sram (
                .CLK(clk), .CEN(cen), .GWEN(gwen), .WEN(wen),
                .A(a), .D(d), .Q(q)
            );
        
 000876     logic rd_pending;
 117526     always_ff @(posedge clk or negedge rst_n) begin
 116940         if (!rst_n) rd_pending <= 1'b0;
 116940         else        rd_pending <= m_req & ~ld_en;
            end
            assign m_rvalid = rd_pending;
            assign m_rdata  = q;
        endmodule
        
