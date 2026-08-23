module dmem_narrow #(
    parameter int ADDR_BITS = 6
)(
    input  logic        clk,
    input  logic        rst_n,
    input  logic        b_req,
    input  logic        b_sel,
    input  logic        b_we,
    input  logic [31:0] b_addr,
    input  logic [7:0]  b_wdata,
    output logic        b_rvalid,
    output logic [7:0]  b_rdata
);
    logic        cen, gwen;
    logic [7:0]  wen, d, q;
    logic [ADDR_BITS-1:0] a;
    logic [ADDR_BITS-1:0] acc_addr;
    assign acc_addr = b_addr[ADDR_BITS-1:0];

    always_comb begin
        if (b_req && b_we) begin
            cen=1'b0; gwen=1'b0; wen=8'h00; a=acc_addr; d=b_wdata;
        end else if (b_sel) begin
            cen=1'b0; gwen=1'b1; wen=8'hFF; a=acc_addr; d=8'h00;
        end else begin
            cen=1'b1; gwen=1'b1; wen=8'hFF; a='0; d=8'h00;
        end
    end

    supply1 vdd; supply0 vss;
    gf180mcu_fd_ip_sram__sram64x8m8wm1 u_sram (
        .CLK(clk), .CEN(cen), .GWEN(gwen), .WEN(wen),
        .A(a), .D(d), .Q(q), .VDD(vdd), .VSS(vss)
    );

    logic rd_pending;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) rd_pending <= 1'b0;
        else        rd_pending <= b_req & ~b_we;
    end
    assign b_rvalid = rd_pending;
    assign b_rdata  = q;
endmodule
