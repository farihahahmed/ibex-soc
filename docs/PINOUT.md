# Pinout — chip_top_full

**22 pins total: 20 signal + 2 power** (11 input, 9 output, 2 power).
Verified from the top-level ports of the placed-and-routed netlist `gds/chip_top_full.pnl.v`.

The design drives all 8 outputs as pure outputs (no tri-state, no MISO). The A45
pad frame assigns bidirectional `bi_t` pad cells to them, which is why `info.yaml`
lists those pins as `bidirectional` — the output-enable is tied active and the
input leg is unused.

| Group | Pin | Type |
|-------|-----|------|
| Clock | clk | input |
| Clock | clk_int | input |
| Reset | rst_n | input |
| Scan | scan_in | input |
| Scan | scan_shift | input |
| Scan | scan_load | input |
| Scan | scan_out | output |
| Scan | scan_i0o1 | input |
| GPIO | gpio_in[0] | input |
| GPIO | gpio_in[1] | input |
| GPIO | gpio_out[0] | output |
| GPIO | gpio_out[1] | output |
| GPIO | gpio_out[2] | output |
| GPIO | gpio_out[3] | output |
| UART | uart_tx | output |
| UART | uart_rx | input |
| SPI | spi_miso | input |
| SPI | spi_sclk | output |
| SPI | spi_mosi | output |
| SPI | spi_cs_n | output |
| Power | VDD | power |
| Power | VSS | power |

## Notes

- **clk_int** selects the clock source (1 = internal generated clock, 0 = external `clk` fallback).
- **scan_i0o1** selects scan direction (in vs out), replacing separate capture/select pins. Note: memory readback is not currently functional — `chip_top_full` ties `scan_chain.mem_rdata` to `32'b0`, so the readback path returns zero.
- FSM control (`start`/`load_done`) and state (`fsm_state`) are **not** pins — they are configured and observed through the scan chain (Columbia-style), which removed 4 pins.
- **spi_miso** is a dedicated SPI data input (double-flop synchronized). The SPI master both drives an output device (e.g. LCD) and reads back data (e.g. a sensor).
- GPIO is **2 in / 4 out**: 2 buttons in, 4 outputs for LEDs (and optionally a piezo).

## How it was derived

Synthesized the full SoC with Yosys; the top-level module port list of the resulting
netlist (`gds/chip_top_full.pnl.v`) is the physical signal-pin set. Power pins (VDD/VSS) are added
at the pad ring. Confirmed by gate-level simulation driving all pins.
