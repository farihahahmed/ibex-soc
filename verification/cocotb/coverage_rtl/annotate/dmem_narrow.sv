//      // verilator_coverage annotation
        module dmem_narrow #(
            parameter int ADDR_BITS = 6
        )(
 103918     input  logic        clk,
 000039     input  logic        rst_n,
%000000     input  logic        b_req,
%000000     input  logic        b_sel,
%000000     input  logic        b_we,
%000000     input  logic [31:0] b_addr,
%000000     input  logic [7:0]  b_wdata,
%000000     output logic        b_rvalid,
%000000     output logic [7:0]  b_rdata
        );
%000001     logic        cen, gwen;
%000001     logic [7:0]  wen, d, q;
%000000     logic [ADDR_BITS-1:0] a;
%000000     logic [ADDR_BITS-1:0] acc_addr;
            assign acc_addr = b_addr[ADDR_BITS-1:0];
        
 103957     always_comb begin
~103957         if (b_req && b_we) begin
%000000             cen=1'b0; gwen=1'b0; wen=8'h00; a=acc_addr; d=b_wdata;
~103957         end else if (b_sel) begin
%000000             cen=1'b0; gwen=1'b1; wen=8'hFF; a=acc_addr; d=8'h00;
 103957         end else begin
 103957             cen=1'b1; gwen=1'b1; wen=8'hFF; a='0; d=8'h00;
                end
            end
        
            gf180mcu_fd_ip_sram__sram64x8m8wm1 u_sram (
                .CLK(clk), .CEN(cen), .GWEN(gwen), .WEN(wen),
                .A(a), .D(d), .Q(q)
            );
        
%000000     logic rd_pending;
 103956     always_ff @(posedge clk or negedge rst_n) begin
 103918         if (!rst_n) rd_pending <= 1'b0;
~103918         else        rd_pending <= b_req & ~b_we;
            end
            assign b_rvalid = rd_pending;
            assign b_rdata  = q;
        endmodule
        
