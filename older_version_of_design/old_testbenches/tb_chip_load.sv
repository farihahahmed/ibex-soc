`timescale 1ns/1ps
module tb_chip_load;
    logic clk, rst_n;
    logic scan_in, scan_shift, scan_load, scan_capture, scan_out, scan_sel_dmem;
    logic start, load_done;
    logic [1:0] fsm_state;
    logic [31:0] cpu_instr_addr;
    logic        cpu_instr_req;

    chip_top_load dut (
        .clk(clk), .rst_n(rst_n),
        .scan_in(scan_in), .scan_shift(scan_shift), .scan_load(scan_load),
        .scan_capture(scan_capture), .scan_out(scan_out), .scan_sel_dmem(scan_sel_dmem),
        .start(start), .load_done(load_done), .fsm_state(fsm_state),
        .cpu_instr_addr(cpu_instr_addr), .cpu_instr_req(cpu_instr_req)
    );

    initial clk=0; always #5 clk=~clk;

    localparam int NWORDS = 4;
    localparam int BASE_WORD = 32;      // byte 0x80
    logic [31:0] prog [0:NWORDS-1];
    initial begin
        prog[0]=32'h00500093;  // addi x1,x0,5
        prog[1]=32'h00A00113;  // addi x2,x0,10
        prog[2]=32'h00308193;  // addi x3,x1,3
        prog[3]=32'h0000006F;  // jal  x0,0
    end

    task wake_all;
        begin
            dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[0].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[1].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[2].u_macro.cen_dly=1'b1;
            dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_fell=1'b1; dut.u_mem.u_imem.u_bank.lane[3].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[0].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[1].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[2].u_macro.cen_dly=1'b1;
            dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_fell=1'b1; dut.u_mem.u_dmem.u_bank.lane[3].u_macro.cen_dly=1'b1;
        end
    endtask

    integer k;
    task scan_word(input [15:0] waddr, input [31:0] wdata);
        logic [47:0] frame;
        begin
            frame = {waddr, wdata};
            for (k=0; k<48; k=k+1) begin
                @(negedge clk);
                scan_in   = frame[k];      // LSB first
                scan_shift = 1'b1;
            end
            @(negedge clk); scan_shift=1'b0; scan_in=1'b0;
            @(negedge clk); scan_load=1'b1;
            @(negedge clk); scan_load=1'b0;
        end
    endtask

    integer i;
    integer fetch_count;
    logic saw_boot, saw_loop;
    initial begin
        scan_in=0; scan_shift=0; scan_load=0; scan_capture=0; scan_sel_dmem=0;
        start=0; load_done=0;
        saw_boot=0; saw_loop=0; fetch_count=0;

        rst_n=0; repeat(4) @(posedge clk);
        wake_all;
        @(negedge clk); rst_n=1;
        repeat(2) @(posedge clk); wake_all;

        $display("after reset: fsm_state=%0d (expect 0=RESET_HOLD)", fsm_state);

        @(negedge clk); start=1;
        @(posedge clk); @(negedge clk); start=0;
        $display("after start: fsm_state=%0d (expect 1=LOAD)", fsm_state);

        $display("scanning %0d words into imem via the scan chain...", NWORDS);
        for (i=0;i<NWORDS;i=i+1) begin
            scan_word(BASE_WORD[15:0] + i[15:0], prog[i]);
        end
        $display("done scanning.");

        @(negedge clk); load_done=1;
        @(posedge clk); @(negedge clk); load_done=0;
        $display("after load_done: fsm_state=%0d (expect 2=RUN)", fsm_state);

        $display("watching CPU fetch (should climb 0x80->0x8C and loop):");
        for (i=0;i<40;i=i+1) begin
            @(posedge clk); #1;
            wake_all;
            if (cpu_instr_req) begin
                if (fetch_count < 12)
                    $display("  fetch: addr=0x%08h", cpu_instr_addr);
                fetch_count = fetch_count + 1;
                if (cpu_instr_addr == 32'h80)  saw_boot = 1;
                if (cpu_instr_addr == 32'h8C)  saw_loop = 1;
            end
        end

        $display("--------------------------------------------------");
        if (saw_boot && saw_loop)
            $display("PASS: scan-loaded program executed (fetched boot 0x80 and loop 0x8C). LOAD-THEN-RUN ALIVE.");
        else
            $display("CHECK: saw_boot=%0b saw_loop=%0b - inspect fetch trace.", saw_boot, saw_loop);
        $display("--------------------------------------------------");
        $finish;
    end
    initial begin #5000000; $display("TIMEOUT"); $finish; end
endmodule
