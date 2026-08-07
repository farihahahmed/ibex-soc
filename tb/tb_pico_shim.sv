`timescale 1ns/1ps
module tb_pico_shim;
    logic clk=0, rst_n=0;
    always #5 clk=~clk;

    // Pico side
    logic        mem_valid, mem_instr, mem_ready;
    logic [31:0] mem_addr, mem_wdata, mem_rdata;
    logic [3:0]  mem_wstrb;
    logic        trap;

    // instr path (read-only imem)
    logic        i_req, i_gnt, i_rvalid;
    logic [31:0] i_addr, i_rdata;
    // data path
    logic        d_req, d_gnt, d_we, d_rvalid;
    logic [3:0]  d_be;
    logic [31:0] d_addr, d_wdata, d_rdata;

    // ---- instruction memory (256 words), read-only, 1-cycle ----
    logic [31:0] imem [0:255];
    initial begin
        integer k; for(k=0;k<256;k=k+1) imem[k]=32'h00000013;
        // program: load-store to data mem then compute
        // addi x1,x0,5 ; sw x1,0(x0) ; lw x2,0(x0) ; add x3,x1,x2 ; jal 0
        imem[0]=32'h00500093; // addi x1,x0,5
        imem[1]=32'h00102023; // sw x1, 0(x0)
        imem[2]=32'h00002103; // lw x2, 0(x0)
        imem[3]=32'h002081b3; // add x3,x1,x2
        imem[4]=32'h0000006f; // jal x0,0
    end
    assign i_gnt = i_req;
    always_ff @(posedge clk or negedge rst_n)
        if(!rst_n) i_rvalid<=0; else i_rvalid<=i_req;
    assign i_rdata = imem[i_addr[31:2]];

    // ---- data memory (256 words), r/w, 1-cycle ----
    logic [31:0] dmem [0:255];
    initial begin integer k; for(k=0;k<256;k=k+1) dmem[k]=0; end
    assign d_gnt = d_req;
    logic d_acc;
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin d_rvalid<=0; d_acc<=0; end
        else begin
            d_acc <= d_req;
            d_rvalid <= d_acc; // 1-cycle latency like ahb path
            if (d_req & d_we) begin
                if(d_be[0]) dmem[d_addr[31:2]][7:0]  <=d_wdata[7:0];
                if(d_be[1]) dmem[d_addr[31:2]][15:8] <=d_wdata[15:8];
                if(d_be[2]) dmem[d_addr[31:2]][23:16]<=d_wdata[23:16];
                if(d_be[3]) dmem[d_addr[31:2]][31:24]<=d_wdata[31:24];
            end
        end
    end
    assign d_rdata = dmem[d_addr[31:2]];

    pico_shim shim (
        .clk(clk), .rst_n(rst_n),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .instr_req(i_req), .instr_gnt(i_gnt), .instr_addr(i_addr),
        .instr_rvalid(i_rvalid), .instr_rdata(i_rdata),
        .data_req(d_req), .data_gnt(d_gnt), .data_we(d_we), .data_be(d_be),
        .data_addr(d_addr), .data_wdata(d_wdata),
        .data_rvalid(d_rvalid), .data_rdata(d_rdata)
    );

    picorv32 #(
        .ENABLE_MUL(1), .ENABLE_DIV(1), .COMPRESSED_ISA(1),
        .ENABLE_IRQ(0), .PROGADDR_RESET(32'h0), .STACKADDR(32'h400),
        .BARREL_SHIFTER(0), .ENABLE_FAST_MUL(0)
    ) cpu (
        .clk(clk), .resetn(rst_n), .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .mem_la_read(), .mem_la_write(), .mem_la_addr(),
        .mem_la_wdata(), .mem_la_wstrb(),
        .pcpi_valid(),.pcpi_insn(),.pcpi_rs1(),.pcpi_rs2(),
        .pcpi_wr(1'b0),.pcpi_rd(32'b0),.pcpi_wait(1'b0),.pcpi_ready(1'b0),
        .irq(32'b0),.eoi(),.trace_valid(),.trace_data()
    );

    integer cyc;
    initial begin
        repeat(4)@(posedge clk); rst_n=1;
        for(cyc=0;cyc<500;cyc=cyc+1) begin
            @(posedge clk);
            if(trap) begin $display("TRAP at %0d",cyc); $finish; end
        end
        if (dmem[0]==32'd5)
            $display("PASS: shim routed fetch+store+load. dmem[0]=%0d (expected 5)",dmem[0]);
        else
            $display("FAIL: dmem[0]=%0d (expected 5)",dmem[0]);
        $finish;
    end
endmodule
