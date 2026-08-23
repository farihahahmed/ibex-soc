# Block MDV status – Pico SoC

Gate: `./run_block_regress.sh` → EXIT 0

| Block | Tests |
|-------|--------|
| uart | smoke, tx, rx, random |
| spi | smoke, tx, rx, random |
| gpio | write, read |
| scan | mem, fsm, clkgen frames |
| ahb | smoke, decode, mux, **hready-stall** |
| fsm | smoke, run, countdown, **idle-hold** |

Negative / protocol depth:
- FSM IDLE never leaks cpu_clk
- AHB slave HREADY=0 propagates to master
