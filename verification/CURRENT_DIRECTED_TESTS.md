# Current Directed Test Suite (Frozen Baseline)

| File                      | Type      | What it tests                                      | Status |
|---------------------------|-----------|----------------------------------------------------|--------|
| `tb_chip_v2.sv`            | Top-level | Full SoC: scan-load → boot → GPIO/UART/SPI checks  | Keep   |
| `tb_chip_gate_v2.sv`       | Top-level | Gate-level version of the above                    | Keep   |
| `tb_gpio.sv`               | Block     | GPIO outputs + inputs + reset                      | Keep   |
| `tb_uart.sv`               | Block     | UART transmitter (byte 0x41)                       | Keep   |
| `tb_spi.sv`                | Block     | SPI activity                                       | Keep   |
| `tb_pico_boot.sv`          | Block     | PicoRV32 boot process                              | Keep   |
| `tb_pico_shim.sv`          | Block     | Pico interface shim                                | Keep   |
| `tb_imem_narrow.sv`        | Block     | Narrow instruction memory                          | Keep   |
| `tb_imem_narrow_top.sv`    | Block     | Top wrapper for narrow IMEM                        | Keep   |
| `tb_dmem_narrow.sv`        | Block     | Narrow data memory                                 | Keep   |
| `tb_fetch_gather.sv`       | Block     | Byte gather/scatter logic                          | Keep   |
| `tb_ahb_mem.sv`            | Block     | AHB memory interface                               | Keep   |
| `tb_scan_chain.sv`         | Block     | Scan chain                                         | Keep   |
| `tb_clk_gen.sv`            | Block     | Clock generator                                    | Keep   |
| `tb_rst_sync.sv`           | Block     | Reset synchronizer                                 | Keep   |
| `tb_test_fsm.sv`           | Block     | Test / clock-gating FSM                            | Keep   |
| `tb_piezo.sv`              | Block     | Piezo / GPIO tone related                          | Keep   |
| `tb_demo.sv`               | Demo      | Demonstration testbench                            | Keep   |
| `g_primes_prog.svh`        | Header    | Firmware data for primes                           | Keep   |
| `g_tune_prog.svh`          | Header    | Firmware data for piezo_tune                       | Keep   |
| `g_game_prog.svh`          | Header    | Firmware data for game                             | Keep   |
