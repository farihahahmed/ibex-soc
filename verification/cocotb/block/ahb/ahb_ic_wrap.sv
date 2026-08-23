// AHB interconnect + 4 always-ready stub slaves (echo addr as data on read).
module ahb_ic_wrap (
    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic [31:0] HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [31:0] HWDATA,
    output logic [31:0] HRDATA,
    output logic        HREADY,
    output logic        HRESP,
    output logic [3:0]  HSEL
);
    logic [31:0] slv_HADDR, slv_HWDATA;
    logic [1:0]  slv_HTRANS;
    logic        slv_HWRITE;

    // Stub: each slave returns its index in low bits, always ready
    logic [31:0] s0_HRDATA, s1_HRDATA, s2_HRDATA, s3_HRDATA;
    assign s0_HRDATA = {24'h0, 8'h00} | slv_HADDR[7:0];
    assign s1_HRDATA = {24'h0, 8'h10} | slv_HADDR[7:0];
    assign s2_HRDATA = {24'h0, 8'h20} | slv_HADDR[7:0];
    assign s3_HRDATA = {24'h0, 8'h30} | slv_HADDR[7:0];

    ahb_interconnect u_ic (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE), .HWDATA(HWDATA),
        .HRDATA(HRDATA), .HREADY(HREADY), .HRESP(HRESP),
        .HSEL(HSEL),
        .slv_HADDR(slv_HADDR), .slv_HTRANS(slv_HTRANS),
        .slv_HWRITE(slv_HWRITE), .slv_HWDATA(slv_HWDATA),
        .s0_HRDATA(s0_HRDATA), .s0_HREADY(1'b1), .s0_HRESP(1'b0),
        .s1_HRDATA(s1_HRDATA), .s1_HREADY(1'b1), .s1_HRESP(1'b0),
        .s2_HRDATA(s2_HRDATA), .s2_HREADY(1'b1), .s2_HRESP(1'b0),
        .s3_HRDATA(s3_HRDATA), .s3_HREADY(1'b1), .s3_HRESP(1'b0)
    );
endmodule
