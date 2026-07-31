// ============================================================================
// tb_chip_v02.sv - v0.2 smoke test: CPU stores then loads through the BUS.
//
// Program stores 0x2A2 to dmem[0x800] then loads it back. If the load returns
// 0x2A2, data traveled Ibex -> adapter -> interconnect -> ahb_mem -> dmem and
// back. That proves the real CPU can drive my bus to reach memory = v0.2.
//
// I watch the DATA bus (adapter <-> interconnect) to see the store and load:
//   - store: HWRITE=1, HADDR=0x800, HWDATA=0x2A2
//   - load:  HWRITE=0, HADDR=0x800, then HRDATA=0x2A2 comes back
//
// Macros need the sim wake-up (cen_fell force) - now for imem AND the ahb_mem
// dmem, which lives at a different hierarchy path (u_dmem_slave.u_dmem...).
// ============================================================================
`timescale 1ns/1ps
module tb_chip_v02;
    logic clk, rst_n;
    chip_top dut (.clk(clk), .rst_n(rst_n));
    initial clk = 0; always #5 clk = ~clk;

    localparam int BASE_WORD = 32;   // byte 0x80
    logic [31:0] prog_mem [0:5];
    initial begin
        prog_mem[0]=32'h2A200293;  // addi x5,x0,0x2A2
        prog_mem[1]=32'h00100313;  // addi x6,x0,1
        prog_mem[2]=32'h00B31313;  // slli x6,x6,11
        prog_mem[3]=32'h00532023;  // sw   x5,0(x6)
        prog_mem[4]=32'h00032383;  // lw   x7,0(x6)
        prog_mem[5]=32'h0000006F;  // jal  x0,0
    end
    integer i;

    // load program into imem (mem_subsystem's imem)
    task load_imem(input integer w, input [31:0] d);
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.mem[w] = d[7:0];
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.mem[w] = d[15:8];
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.mem[w] = d[23:16];
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.mem[w] = d[31:24];
        end
    endtask

    // wake ALL macros: imem (mem_subsystem) + dmem-in-ahb_mem + mem_subsystem's
    // own (unused) dmem. I force cen_fell/cen_dly operational.
    // The tool needs CONSTANT genblock indices in hierarchical paths, so I
    // unroll the lanes explicitly (no loop variable).
    task wake_all;
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_dly  = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_fell = 1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_dly  = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[0].u_macro.cen_fell = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[0].u_macro.cen_dly  = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[1].u_macro.cen_fell = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[1].u_macro.cen_dly  = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[2].u_macro.cen_fell = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[2].u_macro.cen_dly  = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[3].u_macro.cen_fell = 1'b1;
            dut.u_dmem_slave.u_dmem.u_bank.lane[3].u_macro.cen_dly  = 1'b1;
        end
    endtask

    // data-bus probes (adapter <-> interconnect)
    wire [31:0] d_haddr  = dut.HADDR;
    wire        d_hwrite = dut.HWRITE;
    wire [31:0] d_hwdata = dut.HWDATA;
    wire [31:0] d_hrdata = dut.HRDATA;
    wire        d_hready = dut.HREADY;
    wire        d_htrans1= dut.HTRANS[1];

    // Ibex data-port handshake probes (to see if the store "completes" via rvalid)
    wire        dp_req    = dut.data_req;
    wire        dp_gnt    = dut.data_gnt;
    wire        dp_rvalid = dut.data_rvalid;
    wire        dp_we     = dut.data_we;
    wire [31:0] dp_addr   = dut.data_addr;

    integer cycle;
    logic [31:0] last_load;

    initial begin
        rst_n = 0;
        repeat (5) @(posedge clk);
        for (i=0;i<6;i=i+1) load_imem(BASE_WORD+i, prog_mem[i]);
        wake_all;
        @(negedge clk); rst_n = 1;
        $display("---- v0.2: watching data bus for store then load ----");
        last_load = 32'hDEAD;
        for (cycle=0; cycle<120; cycle=cycle+1) begin
            @(posedge clk); #1;
            if (cycle < 2) wake_all;
            // trace the Ibex data port handshake for the first 20 cycles
            if (cycle < 20)
                $display("  [dp] cyc %0d: req=%b gnt=%b rvalid=%b we=%b addr=0x%08h",
                         cycle, dp_req, dp_gnt, dp_rvalid, dp_we, dp_addr);
            // print only cycles where a real data transfer is happening
            if (d_htrans1) begin
                $display("cyc %0d: %s HADDR=0x%08h HWDATA=0x%08h HRDATA=0x%08h ready=%b",
                    cycle, d_hwrite ? "WRITE" : "READ ", d_haddr, d_hwdata, d_hrdata, d_hready);
            end
            // capture read data on ANY completing read transfer
            if (!d_hwrite && d_htrans1 && d_hready)
                last_load = d_hrdata;
        end
        $display("--------------------------------------------------");
        $display("Load from 0x800 returned: 0x%08h (expect 0x000002A2)", last_load);
        if (last_load == 32'h2A2) $display("PASS: store+load through the bus works. v0.2 ALIVE.");
        else                      $display("CHECK: value mismatch - inspect the trace above.");
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #500000; $display("TIMEOUT"); $finish; end
endmodule
