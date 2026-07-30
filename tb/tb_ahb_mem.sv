`timescale 1ns/1ps
module tb_ahb_mem;
    logic HCLK, HRESETn;
    logic        HSEL, HWRITE;
    logic [1:0]  HTRANS;
    logic [31:0] HADDR, HWDATA, HRDATA;
    logic [3:0]  HWSTRB;
    logic        HREADY, HRESP;

    ahb_mem dut (
        .HCLK(HCLK), .HRESETn(HRESETn),
        .HSEL(HSEL), .HADDR(HADDR), .HTRANS(HTRANS), .HWRITE(HWRITE),
        .HWSTRB(HWSTRB), .HWDATA(HWDATA), .HRDATA(HRDATA),
        .HREADY(HREADY), .HRESP(HRESP)
    );

    initial HCLK=0; always #5 HCLK=~HCLK;
    integer errors;
    localparam [1:0] IDLE=2'b00, NONSEQ=2'b10;

    task ahb_write(input [31:0] a, input [31:0] d, input [3:0] strb);
        begin
            @(negedge HCLK);
            HSEL=1; HADDR=a; HWRITE=1; HTRANS=NONSEQ; HWSTRB=strb;
            @(negedge HCLK);
            HTRANS=IDLE; HSEL=0; HWDATA=d;
            while (!HREADY) @(negedge HCLK);
            @(negedge HCLK);
            HWDATA=0;
        end
    endtask

    task ahb_read_chk(input [31:0] a, input [31:0] exp);
        begin
            @(negedge HCLK);
            HSEL=1; HADDR=a; HWRITE=0; HTRANS=NONSEQ; HWSTRB=4'h0;
            @(negedge HCLK);
            HTRANS=IDLE; HSEL=0;
            while (!HREADY) @(negedge HCLK);
            #1;
            if (HRDATA===exp) $display("OK  read @0x%02h = 0x%08h", a, HRDATA);
            else begin $display("BAD read @0x%02h = 0x%08h (exp 0x%08h)", a, HRDATA, exp); errors=errors+1; end
            @(negedge HCLK);
        end
    endtask

    initial begin
        errors=0; HSEL=0; HADDR=0; HWRITE=0; HTRANS=IDLE; HWSTRB=0; HWDATA=0;
        HRESETn=0; repeat(6) @(posedge HCLK); HRESETn=1; repeat(8) @(negedge HCLK);

        ahb_write(32'h00, 32'hCAFEBABE, 4'hF);
        ahb_write(32'h04, 32'h11223344, 4'hF);
        ahb_read_chk(32'h00, 32'hCAFEBABE);
        ahb_read_chk(32'h04, 32'h11223344);
        ahb_write(32'h00, 32'h0077_0000, 4'b0100);
        ahb_read_chk(32'h00, 32'hCA77BABE);

        $display("--------------------------------------------------");
        if (errors==0) $display("ALL PASSED - narrow ahb_mem (wait-state) works!");
        else           $display("FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #200000; $display("TIMEOUT - AHB hung (HREADY never went high?)"); $finish; end
endmodule
