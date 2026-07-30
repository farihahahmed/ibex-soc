`timescale 1ns/1ps
module tb_imem_narrow;
    logic clk, rst_n;
    logic        m_req, m_gnt, m_rvalid;
    logic [31:0] m_addr;
    logic [7:0]  m_rdata;
    logic        ld_en;
    logic [8:0]  ld_addr;
    logic [7:0]  ld_data;

    imem_narrow dut (
        .clk(clk), .rst_n(rst_n),
        .m_req(m_req), .m_gnt(m_gnt), .m_addr(m_addr),
        .m_rvalid(m_rvalid), .m_rdata(m_rdata),
        .ld_en(ld_en), .ld_addr(ld_addr), .ld_data(ld_data)
    );

    initial clk = 0; always #5 clk = ~clk;
    integer errors;

    task load_byte(input [8:0] la, input [7:0] ld);
        begin
            @(negedge clk);
            ld_en = 1'b1; ld_addr = la; ld_data = ld;
            @(negedge clk);
            ld_en = 1'b0;
        end
    endtask

    task read_check(input [8:0] ra, input [7:0] exp_val);
        begin
            @(negedge clk);
            m_req = 1'b1; m_addr = {23'b0, ra};
            @(negedge clk);
            m_req = 1'b0;
            wait (m_rvalid);
            #1;
            if (m_rdata === exp_val)
                $display("OK  read [0x%03h] = 0x%02h", ra, m_rdata);
            else begin
                $display("BAD read [0x%03h] = 0x%02h (expected 0x%02h)", ra, m_rdata, exp_val);
                errors = errors + 1;
            end
            @(negedge clk);
        end
    endtask

    initial begin
        errors = 0;
        m_req = 0; m_addr = 0; ld_en = 0; ld_addr = 0; ld_data = 0;
        rst_n = 0;
        repeat (4) @(posedge clk);
        rst_n = 1;
        @(negedge clk);

        load_byte(9'h000, 8'h11);
        load_byte(9'h001, 8'h22);
        load_byte(9'h002, 8'h33);
        load_byte(9'h003, 8'h44);
        load_byte(9'h010, 8'hAA);
        load_byte(9'h020, 8'hBB);
        load_byte(9'h0FF, 8'hCC);
        load_byte(9'h1FF, 8'hDD);

        read_check(9'h000, 8'h11);
        read_check(9'h001, 8'h22);
        read_check(9'h002, 8'h33);
        read_check(9'h003, 8'h44);
        read_check(9'h010, 8'hAA);
        read_check(9'h020, 8'hBB);
        read_check(9'h0FF, 8'hCC);
        read_check(9'h1FF, 8'hDD);

        $display("--------------------------------------------------");
        if (errors == 0) $display("ALL TESTS PASSED - narrow imem writes & reads correctly");
        else             $display("TESTS FAILED (%0d errors)", errors);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #20000; $display("TIMEOUT - memory hung"); $finish; end
endmodule
