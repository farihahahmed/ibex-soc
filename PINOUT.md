# Pinout — chip_top_full

**22 pins total: 20 signal + 2 power** (12 input, 8 output, 2 power). No bidirectional pins.
Verified from the top-level ports of the synthesized netlist `chip_top.nl.v`.

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
| GPIO | gpio_out[4] | output |
| UART | uart_tx | output |
| UART | uart_rx | input |
| SPI | spi_sclk | output |
| SPI | spi_mosi | output |
| SPI | spi_cs_n | output |
| Power | VDD | power |
| Power | VSS | power |

## Notes

- **clk_int** selects the clock source (1 = internal generated clock, 0 = external `clk` fallback).
- **scan_i0o1** selects scan direction (in vs out) for readback, replacing separate capture/select pins.
- FSM control (`start`/`load_done`) and state (`fsm_state`) are **not** pins — they are configured and observed through the scan chain (Columbia-style), which removed 4 pins.
- **spi_miso** is omitted: the SPI interface is output-only (drives an LCD), matching the reference design.
- GPIO is **2 in / 5 out**: 2 buttons in, 5 outputs for LEDs (and optionally a piezo).

## How it was derived

Synthesized the full SoC with Yosys; the top-level module port list of the resulting
netlist (`chip_top.nl.v`) is the physical signal-pin set. Power pins (VDD/VSS) are added
at the pad ring. Confirmed by gate-level simulation driving all pins.
