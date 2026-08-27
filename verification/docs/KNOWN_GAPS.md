# Known gaps and accepted limitations

Design limitations that are deliberate or accepted, as distinct from
verification gaps. Verification gaps are tracked in the "Open items" section of
`REQUIREMENTS_TRACEABILITY.md`.

Stating these is not an admission of sloppiness. Each was found, understood,
and consciously accepted rather than discovered by a reviewer.

## Physical

**One antenna violation with the accelerator included.** `_04754_` at 403.68
against a 400 limit — 0.9% over, on Metal4. Seven configurations were tried to
clear it: placement density 52 and 48, `GRT_ADJUSTMENT` 0.15, clock periods 30,
34 and 45 ns, `DRT_ANTENNA_REPAIR_ITERS` (which crashes detailed routing at this
utilisation), a larger 1110x1110 die, and a macro nudge. None produced fewer
than one violation and several produced more. Timing closes on all nine corners
and LVS matches uniquely.

**Four Magic DRC violations (M3.1, Metal3 width).** These are not produced by
this design. Every `gf180mcu_fd_ip_sram__sram*x8m8wm1` LEF in the PDK contains a
0.110 um tall Metal3 port rectangle on the VSS pin, against a 0.56 um minimum.
Both macro instances flag it at identical relative offsets and our LEF copies
are md5-identical to the PDK's. Full evidence and method in
`docs/A45_m3_drc_report.txt`. Reported upstream.

## Architecture

**`.rodata` is not reachable by loads.** The linker places read-only data in
instruction memory, but `pico_shim` routes data accesses through the AHB bus to
the data memory. Firmware must generate constants arithmetically rather than
using string literals or const arrays. This cost one debug cycle before it was
understood.

**No SPI MISO pin.** The 22-pin budget is fully allocated, so the SPI interface
is transmit-only by design and `miso` is tied to `1'b0`. Consequences: reads
return 0 in `rdata[15:8]`, and the SPI FSM's last receive bit is unobservable.

**No unmapped-address error response.** The AHB decode uses `HADDR[17:16]`, two
bits, so all four encodings map to a real slave. A wild pointer silently reads
or writes memory instead of erroring. `HRESP` is tied low everywhere.

**Scan addresses above 0x7F alias.** `ld_word_addr[6:0]` and `rd_word_addr[6:0]`
truncate, so a scan write to word address 0x80 or higher wraps to 0x00 with no
indication. The 512 B instruction memory needs only 7 bits; the frame carries 14.

**No UART overrun flag.** A second byte arriving before the first is read
overwrites `rx_data` silently. Standard UARTs expose an overrun status bit.

**`sys_clk` / `cpu_clk` domain crossing on the memory interface.**
`mem_subsystem` runs on `sys_clk` while `pico_shim` and the whole bus run on
`cpu_clk`, a gated version of it. Edges align while running, so timing closes.
But if the FSM gates the clock off mid-fetch, `pico_shim` freezes holding
`inflight` and waits for an `rvalid` that already happened, wedging the CPU
until reset. Reachable only by leaving RUN during a fetch. Never observed in 30
tests including the countdown case.

**`cpu_clk` fanout is 2,177 terminals.** Functional and timing-closed, but
unusual. Restructuring the clock tree in RTL is future work.

## Notes on deliberate choices

**GPIO read and write layouts differ.** Software writes outputs at bits
`[NUM_OUT-1:0]` but reads them back at `[NUM_IN+NUM_OUT-1:NUM_IN]`. This keeps
inputs at `[1:0]` so existing firmware is unaffected by the addition of output
readback.

**The glitch-free clock mux uses PDK ICG cells rather than hand-built flops.**
An earlier version clocked enable synchronisers on `negedge div_clk`. That is
functionally correct and passes simulation, but making a flop output a clock
source crashes OpenROAD's CTS in `checkFanoutLimitPreamble`. The `icgtp_1`
integrated clock gate is a characterised cell the tools handle natively and
gives the same guarantee.
