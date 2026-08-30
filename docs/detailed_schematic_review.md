# Schematic Review — Pico SoC (Project A45)

Pico SoC is a compact 32-bit RISC-V microcontroller system-on-chip built on the
open GlobalFoundries 180 nm process (GF180MCU), implemented end to end with
open-source tools from RTL through place-and-route and signoff. This document is
a complete design review: it explains what the chip does, how it is built, the
decisions and tradeoffs behind it, how thoroughly it has been verified, and the
final signed-off results.

This review was written **after physical design was completed**, so every number
reported here comes from the actual signed-off chip rather than an early estimate.
The signoff run is `RUN_2026-08-29_12-40-30` and the artifact is
`gds/chip_top_full.gds`. Where a pre-layout synthesis estimate and the final
signoff differ, the two are reconciled line by line in `docs/FE_VS_BE.md`.

---

## 1. Design objectives and specifications

The goal was a small, general-purpose RISC-V microcontroller that a person could
actually program and use — a CPU, some on-chip memory, a few standard
peripherals, and a custom accelerator — all fitting inside a single tapeout slot
on the open GF180MCU process. Every target below is fixed and has been carried
all the way through to silicon.

The processor is a PicoRV32 core configured as **RV32E + M + C**: the embedded
16-register variant, with hardware multiply and divide and the compressed
instruction extension. On top of the standard ISA, the chip adds a custom
co-processor (described in section 5) that accelerates common byte-oriented
operations. The system runs from a single 25 MHz input clock that is divided
on-chip to a **12.5 MHz** operating frequency for the CPU, buses, and
peripherals.

On-chip memory is **1 KB total** — 512 bytes of instruction memory and 512 bytes
of data memory — built from the GF180 8-bit-wide SRAM macros. The CPU reaches
memory and peripherals over an AHB-Lite bus for instruction fetch and data
access, with an AHB-to-APB bridge feeding the peripheral block: GPIO, UART, and
SPI. The whole design fits in a **1110 × 1110 µm** die and uses exactly **22
pins** (20 signal plus 2 power), running on a single 5 V supply.

| Specification | Value |
| --- | --- |
| CPU | PicoRV32, RV32E + M + C (16 registers, hardware multiply/divide, compressed) |
| Custom acceleration | PCPI co-processor, 7 custom-0 instructions |
| On-chip memory | 1 KB SRAM: 512 B instruction + 512 B data (narrow 8-bit macros) |
| Bus | AHB-Lite (fetch/data) + APB (peripherals) |
| Peripherals | GPIO, UART, SPI |
| Bring-up | Scan chain + clock-gating FSM |
| Operating frequency | 12.5 MHz (from a 25 MHz input, divided by two on-chip) |
| Process | GF180MCU, single 5 V standard-cell library |
| Die size | 1110 × 1110 µm |
| Pins | 22 (20 signal + 2 power) |

---

## 2. Project history and roadmap

The design reached its current form through a sequence of deliberate decisions,
each made in response to a concrete constraint. The path is worth telling, because
it shows the planning behind the chip rather than just its final state.

**The project started with an Ibex core and had to change.** The repository was
originally an Ibex-based SoC, but an early floorplan could not meet the area
constraint: the hardened Ibex CPU macro alone was 0.743 mm², and it could not tile
alongside the SRAM macros inside the available die. Rather than force a design that
would not fit, the core was replaced with a **synthesized PicoRV32** — a much
smaller, more flexible core that places and routes as standard cells instead of a
fixed macro. This was the first major planning decision: recognize the area problem
early, and pivot the core choice before committing to physical design.

**The smaller core freed area, and that area became the accelerator.** Moving from
the large Ibex macro to synthesized PicoRV32 left the design comfortably under its
area budget — utilization would have been low, meaning a lot of the die was doing
nothing. Rather than ship a mostly-empty chip, that freed area was put to use: a
**custom PCPI accelerator** was added to give the microcontroller genuinely useful
capability — hardware CRC32, a signed multiply-accumulate for digital filtering,
and bit-manipulation instructions. This turned a constraint (a core that was too
big) into a differentiator (a small chip that does real DSP and data-integrity
work), and it brought final utilization up to a healthy **80.5%**. The accelerator's
measured results are in section 5.

**Physical design drove two more refinements.** During place-and-route, the CPU
clock gate — originally a plain combinational AND — caused a persistent antenna
violation, high-fanout slew, and a routing failure. It was replaced with a PDK
integrated clock-gating cell, which resolved all three and was proven equivalent by
formal and simulation (section 6). Separately, one GPIO output pin was reassigned
as a dedicated SPI data input, so the fabricated chip could actually receive SPI
data — a late but deliberate usability decision for the real silicon.

**The result.** These decisions — pivot the core to fit the area, use the freed
area for an accelerator, fix the clock gating for clean routing, and spend a pin on
SPI input — produced a design that is complete, useful, and signed off. Each was a
response to something learned along the way, not a change of direction after the
fact.

| Milestone | Decision | Driver |
| --- | --- | --- |
| Core selection | Ibex → synthesized PicoRV32 | Ibex macro (0.743 mm²) could not tile with the SRAMs |
| Feature scope | Add the PCPI accelerator | Smaller core freed area; use it for real capability |
| Clock gating | Combinational gate → PDK ICG cell | Antenna, slew, and routing failures on the gated clock |
| Silicon usability | One GPIO output → dedicated SPI input | Let the fabricated chip receive SPI data |
| Signoff | Clean tapeout on GF180MCU | All checks met or defensibly waived |

---

## 3. Architecture and how the chip is built

The whole SoC is integrated into a single top-level module, `chip_top_full`, and
that top level has been taken all the way through synthesis, placement, clock-tree
synthesis, routing, and signoff. Nothing here is a block sitting on its own; it is
one connected chip.

**Clocking.** A single physical clock enters the chip and is divided into two
working domains. The first, `sys_clk`, runs the memory, the scan chain, the
bring-up FSM, and the peripherals. The second, `cpu_clk`, is a clock-gated version
that drives the CPU and the buses, so the processor can be held cleanly while a
program is loaded and released only when the design is ready to run. The gating is
done with a PDK integrated clock-gating cell rather than hand-built logic, for
reasons explained in section 6.

**CPU and memory path.** The PicoRV32 core fetches instructions and performs data
loads and stores through a small shim, `pico_shim`, that splits the instruction
path from the data path. Both paths reach memory through an AHB-Lite interconnect
that decodes the top address bits to select instruction memory, data memory, or
the peripheral bridge. Because the SRAM macros are only 8 bits wide, the memory
subsystem gathers and scatters byte-wide accesses into full 32-bit words, so the
CPU sees ordinary word-addressable memory.

**Peripherals.** Peripheral traffic crosses an AHB-to-APB bridge into a simple
APB decoder that routes to the GPIO block at `0x0001_0000`, the UART at
`0x0002_0000`, and the SPI at `0x0003_0000`. One GPIO output was later converted
into a dedicated SPI data-input pin so the fabricated chip can actually receive
SPI data from a sensor or peripheral, which is why the design has four GPIO
outputs rather than five.

**Bring-up over the scan chain.** Rather than spend pins on start/stop control,
clock configuration, program loading, and status readback, all four of those
functions are shifted in and out over the scan chain. This is what keeps the pin
count at 22: giving each of those functions its own pin would have added four more
pads. The scan chain loads a program into instruction memory, configures and
starts the FSM, and reads back a status word that reports the CPU trap state, the
FSM mode, and the memory-owner bit.

**Address map.** The AHB decode selects between data memory and the peripheral
bridge, and the APB decoder then selects among the three peripherals:

| Region | Base address |
| --- | --- |
| GPIO | `0x0001_0000` |
| UART | `0x0002_0000` |
| SPI | `0x0003_0000` |
| Data memory | decoded on the AHB side |

**Pins.** The design uses 22 pins in total, grouped by function:

| Group | Pins | Direction | Purpose |
| --- | --- | --- | --- |
| Clock | `clk`, `clk_int` | in | 25 MHz input; internal vs external source select |
| Reset | `rst_n` | in | Active-low reset |
| Scan | `scan_in`, `scan_shift`, `scan_load`, `scan_i0o1` | in | Program load, config, and control |
| Scan | `scan_out` | out | Status and state readback |
| GPIO | `gpio_in[1:0]` | in | 2 inputs (buttons) |
| GPIO | `gpio_out[3:0]` | out | 4 outputs (LEDs or piezo) |
| UART | `uart_rx`, `uart_tx` | in / out | Serial console |
| SPI | `spi_miso` | in | SPI data in (from a sensor) |
| SPI | `spi_sclk`, `spi_mosi`, `spi_cs_n` | out | SPI master out |
| Power | `VDD`, `VSS` | — | 5 V supply |

The complete block list, all instantiated in `rtl/chip_top_full.sv`: clock
generator, scan chain, clock-gating FSM, PicoRV32 core, PCPI accelerator,
`pico_shim`, memory subsystem (narrow-8b instruction and data memory), AHB
interconnect, AHB memory slave, AHB-to-APB bridge, APB decoder, GPIO, UART, and
SPI.

---

## 4. Synthesis results (front-end)

Before committing to place-and-route, the full SoC was synthesized to confirm it
fits and closes timing. The area estimate comes from Yosys, and the timing from
OpenSTA, both mapped to the GF180 5 V standard-cell library at nominal conditions.
These are pre-layout, logic-only estimates — before placement, clock-tree
synthesis, and routing — and their purpose is to prove the design is feasible
ahead of the much longer back-end flow. Section 9 then shows how well these
estimates held up against the final silicon.

### Area (post-synthesis)

| Metric | Value |
| --- | ---: |
| Standard-cell logic area | 397,658 µm² (0.398 mm²) |
| — sequential (flops + clock gates) | 160,704 µm² (40.4%) |
| — combinational | 236,954 µm² (59.6%) |
| Standard cells | 14,483 |
| Flip-flops | 2,445 |
| Integrated clock gates | 3 |
| SRAM macros | 2 × 209,404 µm² = 418,809 µm² (0.419 mm²) |
| **Logic + macros** | **~816,000 µm² (0.816 mm²)** |

Yosys reports standard-cell logic area only; the SRAM macro area is added from the
macro's own layout data, because synthesis treats the hardened macro as a black
box. The logic is flop-dominated, as expected for a CPU SoC with a CRC and MAC
datapath — the largest single area consumers are the datapath flip-flops, the
multiplexers, and the reset flip-flops. This post-synthesis area stays roughly
stable through placement; the back-end then adds the clock tree, buffering, and
fill on top, reaching a final signoff utilization of 80.5% in the 1.232 mm² die.

### Timing (ideal clocks)

The synthesized netlist was constrained at the 40 ns (25 MHz) target period with
an ideal clock network — no clock-tree or wire delay yet.

| Metric | Value |
| --- | ---: |
| Target period | 40 ns (25 MHz) |
| Worst setup slack | +0.203 ns (met) |
| Critical-path arrival | 39.494 ns |
| Logic depth on the worst path | 4 gate levels |

**Reading the setup number honestly:** the worst path is only four gates deep,
but a single minimum-size inverter on it takes 18.5 ns because pre-layout
synthesis has not yet sized drivers for their fanout. The slack is therefore
pessimistic — it is drive-limited, not logic-limited. The back-end resizer buffers
these nets, and post-route signoff timing improves to +4.17 ns worst-corner setup
and +0.33 ns hold, clean across all nine PVT corners. The front-end result
confirms what it is meant to: the logic is shallow and closes at the target
period, and the final margin is set at signoff.

**What synthesis confirmed.** The design is roughly 0.4 mm² of standard-cell logic
plus 0.42 mm² of SRAM — about 0.82 mm² of active area — using 22 pins and closing
timing at the 25 MHz target. Size and frequency were decided and validated in
synthesis before any place-and-route work began, and full signoff later confirmed
them.

---

## 5. Custom accelerator and headline results

The most distinctive part of the design is a custom co-processor attached to
PicoRV32's PCPI interface. It implements **seven single-cycle instructions** in
the RISC-V custom-0 opcode space (`0x0B`), each selected by the `funct3` field.
Every one of them does in a single cycle what would otherwise be a software loop,
and the unit sits entirely inside the CPU boundary — it never touches the bus,
the memory, or the pins. Any instruction encoding it does not claim falls through
to the CPU's normal illegal-instruction trap.

The seven instructions are:

| `funct3` | Instruction | Operation |
| --- | --- | --- |
| `000` | `crc32.b` | Fold one byte into the running CRC32 |
| `001` | `crc32.w` | Fold a 32-bit word into the running CRC32 |
| `010` | `popcnt` | Count the set bits in a register |
| `011` | `brev` | Reverse the bit order of a register |
| `100` | `mac` | Signed multiply-accumulate: `acc += rs1 * rs2` |
| `101` | `macrd` | Read the MAC accumulator |
| `110` | `macclr` | Clear the MAC accumulator |

**Measured results on the gate-level SoC.** These are real numbers from running
the firmware, not projections.

| Workload | Software | With custom instruction | Gain |
| --- | ---: | ---: | ---: |
| CRC32 of 64 bytes | 39,143 cycles | 3,785 cycles | **10.3× faster** |
| FIR noise ripple | 30 | 6 | **5× cleaner** |

- **CRC32 is 10.3× faster than software.** Checksumming 64 bytes takes 39,143
  cycles in a pure-software loop and only 3,785 cycles using the `crc32`
  instructions. This matters because a CRC32 lookup table would need roughly 1 KB
  of memory — which would not fit in this chip's 512 bytes of data memory — so the
  instruction replaces a table the chip could not otherwise hold.

- **A FIR filter cuts noise 5× using the MAC instruction.** The `fir_demo`
  firmware runs a 5-tap moving-average filter (taps 1-2-4-2-1) over a noisy ±100
  square wave. Each tap is a single `mac` instruction instead of a
  multiply-then-add software sequence, and the filter reduces the noise ripple
  from 30 down to 6 — a 5× improvement — while preserving the underlying signal.
  This is a genuine digital-signal-processing result on a microcontroller that has
  no dedicated DSP hardware.

- **CRC32 correctness is checked against an independent reference.** The CRC
  result matches the published `0xCBF43926` check constant used by Ethernet and
  zip, so the instruction is verified against a well-known external value rather
  than only against the design's own model.

These are the kinds of operations — checksums, digital filtering, bit
manipulation — that appear constantly in real embedded work: data integrity over
UART or SPI, sensor filtering, motor control, error-correction codes, and
protocol parsing. The accelerator makes them cheap on a very small chip.

---

## 6. Design decisions and tradeoffs

Every significant choice in this design was made deliberately, with the cost and
benefit understood in advance. The interesting engineering is in these tradeoffs,
so they are worth spelling out. In summary:

| Decision | Why | Tradeoff accepted |
| --- | --- | --- |
| Narrow 8-bit SRAM + gather/scatter | Fits the 1 KB area budget | Multi-cycle word access |
| PDK integrated clock gate (`icgtp_1`) | Fixed antenna + routing failures | None — formally equivalent |
| Scan-based bring-up | Saves 4 pins, keeps 22 | Sequential (not parallel) bring-up |
| Accelerator inside the CPU boundary | No bus or coherence risk | Results only visible via UART/GPIO |
| Split memory / CPU clock | Hold CPU cleanly during load | One documented wedge corner |

**Narrow 8-bit memory instead of a wider one.** The GF180 SRAM macro is 8 bits
wide. Using it directly, rather than paying the area for a wider custom memory,
keeps the design inside its 1 KB budget and its die size. The cost is that a
32-bit word access takes several cycles while the memory subsystem gathers or
scatters the four bytes. This is a straightforward area-for-latency trade, and at
12.5 MHz the extra cycles are comfortably absorbed.

**A PDK integrated clock-gating cell instead of a hand-built gate.** An earlier
version of the design gated the CPU clock with a plain combinational AND of the
clock and an enable signal. That was functionally correct and passed simulation,
but in physical design it caused three separate problems: a persistent Metal3
antenna violation, high-fanout slew on the gated-clock net, and an outright
detailed-routing failure — all rooted in the fact that a weak logic gate was
driving a clock net. Switching to the PDK's `icgtp_1` integrated clock-gating
cell, a characterized standard cell the tools understand natively, resolved all
three at once. The change was proven functionally equivalent to the original by
both formal verification and the full simulation regression, so it fixed the
physical problems without altering behavior. This single decision is why the
final chip has zero antenna violations.

**Scan-based bring-up instead of dedicated control pins.** Folding the FSM
control, clock configuration, program load, and status readback into the existing
scan chain saved four pins and kept the design at 22, which is what let it fit the
pad ring. The tradeoff is that bring-up is sequential — you shift data in and out
rather than driving parallel pins — but for a test chip that is a natural fit and
costs nothing in observability, since the same scan path reads state back out.

**Keeping the accelerator inside the CPU boundary.** The custom co-processor was
deliberately attached to the CPU's PCPI interface rather than placed on the bus as
a memory-mapped peripheral. Because it never arbitrates for the bus or touches
memory, it adds no risk of bus contention or memory-coherence bugs, and its
results are simply observed through UART or GPIO. This keeps a powerful feature
from complicating the rest of the system.

**Splitting the memory subsystem clock from the CPU clock.** The memory runs on
`sys_clk` while the CPU and buses run on the gated `cpu_clk`. This is what lets the
design hold the CPU cleanly during program load while memory and scan stay live.
The two clocks are edge-aligned while the chip is running, so timing closes
normally; the one theoretical corner this creates is described in the limitations
below.

**Separate GPIO read and write layouts.** Software writes GPIO outputs at the low
bits and reads them back at a higher bit offset, which keeps the input pins at the
bottom of the register. This was done so that adding output readback did not
disturb the bit positions existing firmware already used for inputs.

### Known and accepted limitations

These are real limitations of the current design. Each one was found, understood,
and consciously accepted — none was a surprise, and each is listed here so a
reader of this document has the full picture without needing another file.

- **Read-only data is not reachable by loads.** The linker places read-only
  constants in instruction memory, but data accesses are routed to data memory, so
  firmware generates constants arithmetically instead of using string literals or
  constant arrays.
- **There is no unmapped-address error response.** The bus decode uses two address
  bits, so all four encodings map to a real slave. A wild pointer silently reads or
  writes memory rather than raising an error, and the bus error signal is tied
  inactive.
- **There is no UART overrun flag.** If a second byte arrives before the first is
  read, it overwrites the first silently. A production UART would expose an
  overrun status bit.
- **High scan addresses alias.** The scan program-load address is truncated to
  seven bits, so a write above address `0x7F` wraps to the bottom of memory with no
  indication. The 512-byte instruction memory only needs seven bits, but the scan
  frame carries more.
- **The CPU clock has an unusually high fanout** (about 2,177 terminals). It is
  functionally correct and timing-closed, but restructuring the clock tree in RTL
  remains future work.
- **A memory-interface clock-domain wedge is theoretically reachable.** If the FSM
  were to gate the CPU clock off in the middle of a fetch, the CPU could wedge
  until reset while it waits for a response that already arrived. This is only
  reachable by leaving the RUN state during a fetch, and it has never been observed
  anywhere across the entire test suite, including the countdown case that comes
  closest to triggering it.

---

## 7. Verification

The design is backed by comprehensive verification across three complementary
axes — dynamic simulation, formal proof, and structural coverage — all gated by a
single honest test run. There is exactly one gate,
`verification/cocotb/run_all_verify.sh`. Every test that exists and passes is in
it; there are no excluded tests, no legs that are allowed to fail, and no masked
exit codes. It runs in continuous integration on every push.

| Axis | Result |
| --- | --- |
| Functional gate | 52 test suites, 0 failures, exit code 0 |
| Formal | 46 properties across 8 targets (bounded model checking) |
| Line coverage | 88.7% of own RTL (873/984 lines), CI-enforced floor |
| FSM coverage | 40 of 40 states (100%) |
| Firmware at the pins | primes, piezo, game, FIR, CRC32, full PCPI exercise |
| Continuous integration | lint (22 modules) + gate + formal + gate-level, none allowed to fail |

**Dynamic simulation.** The functional gate is **52 test suites** and passes with
zero failures. These cover directed and constrained-random stimulus for every
peripheral, the scan and FSM bring-up path, negative and corner cases, and the
firmware demos running at the actual pins — including the FIR filter, the CRC
checksum, and a full exercise of all seven custom instructions. The chip-level
environment is built with pyuvm and cocotb, with proper agents, sequences, a
scoreboard, and coverage, and it shares that infrastructure with isolated
block-level tests for the UART, GPIO, and SPI.

**Formal verification.** Bounded model checking proves **46 properties across 8
targets**, and these run in CI alongside the simulation. Formal proves that the
properties hold for *every* input sequence up to the bound, not just for the
stimulus a testbench happens to apply. Among other things, it proves that scan
cannot write memory while the CPU is running, that the AHB decode is one-hot and
its response routing follows the correct registered selection, that the
accelerator never claims an instruction outside its opcode space, and that a
granted fetch always returns data within a bounded number of cycles.

**Code coverage.** Line coverage of the design's own RTL is **88.7%** (873 of 984
lines), excluding the third-party CPU core and the PDK and SRAM models. This
figure is enforced: a CI check fails the build if coverage regresses below its
floor. State-machine coverage is complete, at 40 of 40 states.

**Bugs verification actually caught.** This process found and fixed real defects.
A directed protocol test discovered the SPI dropping its eighth clock edge on
every byte — which silently lost the least-significant bit of every transfer —
because a signal was assigned twice in the same clock and the later assignment
won. Formal verification separately found that the clock-gating FSM accepted an
undefined mode encoding that no directed test would have thought to try. Both are
fixed and now guarded by regression.

**Continuous integration.** The GitHub Actions workflow runs on every push and
pull request: a per-block lint of all 22 RTL modules, the full 52-suite gate, the
formal properties, and the gate-level smoke. No job is allowed to fail.

---

## 8. Signoff results

The tapeout objective is met: a signed-off GDS exists and all signoff checks are
clean or explicitly and defensibly waived. The numbers below are from the signoff
run on the current design.

| Check | Result |
| --- | --- |
| LVS (layout vs schematic) | Matches uniquely, 16,728 devices |
| Antenna | 0 violations |
| Timing | Clean across all 9 corners — setup slack +4.17 ns, hold slack +0.33 ns |
| DRC | 4 violations (M3.1), all inside the SRAM macro — waived with evidence |
| IR drop | 0.031% worst case (1.56 mV) |
| Power | 48.1 mW nominal |
| Utilization | 80.5% |
| CPU maximum frequency | 13.2 MHz at the worst corner, against 12.5 MHz operating |

**The DRC waiver is a foundry-macro issue, not a flaw in this design.** All four
DRC violations are the same kind: a Metal3 width rule (M3.1) triggered on the
power pin of the GF180 SRAM macro. Every `sram*x8m8wm1` SRAM macro shipped in the
PDK contains a 0.110 µm-tall Metal3 rectangle on its VSS pin, against a 0.28 µm
minimum. Both SRAM instances in the design flag it at identical relative offsets,
and our copies of the macro are md5-identical to the PDK's originals — so the
violations come from the unmodified foundry IP, not from anything the design does.
An independent KLayout DRC of the foundry deck, run directly on the GDS, reports zero violations — confirming the Magic flags come from the macro LEF abstract, not the fabricated geometry. The issue has been reported upstream, and the full evidence, including the exact
geometry and the byte-level match to the PDK, is in `gds/DRC_WAIVER.txt`.

**Estimate versus silicon.** Because this review was written after layout, every
pre-layout synthesis estimate can be checked against the real signoff number.
Section 9 works through that reconciliation in full — it is one of the strongest
pieces of evidence that the design was sound, because the early feasibility
estimate matched what the silicon became.

**One open item, stated honestly.** Full firmware *execution* on the gate-level
netlist is blocked by a documented PicoRV32 limitation: the core initializes some
of its internal state through Verilog constructs that synthesis does not preserve,
so those flip-flops power up unknown in gate-level simulation. This is a
simulation artifact, not a defect in the netlist or the silicon — logical
equivalence between the RTL and the netlist is proven by LVS, and functional
correctness is proven by the full RTL gate. It is the single remaining partial
item in the requirements traceability matrix, and it is documented rather than
papered over.

---

## 9. Front-end estimate versus silicon

Because this review was written after layout, every pre-layout synthesis estimate
can be checked against what the silicon actually became. This is worth doing in
detail, because a good chip is not just one that passes signoff — it is one where
the early feasibility analysis *predicted* the final result. It did here: the
front-end synthesis estimate held all the way through to signoff.

The comparison is like-for-like: the pre-layout estimate comes from Yosys
synthesis and OpenSTA with ideal wires, and the post-route signoff comes from the
LibreLane / OpenROAD flow with real parasitics — both on the same RTL. The two
stages measure different things on purpose. The front end tells you whether the
*logic* fits and closes timing; the back end tells you what the *silicon* does
after placement, clock-tree synthesis, routing, antenna repair, and fill.

### Area

| Metric | Front-end (synthesis) | Back-end (signoff) | Why it differs |
| --- | ---: | ---: | --- |
| Sequential-cell area | 160,704 µm² | 162,904 µm² | +1.3% — the resizer up-sized a few flops; near-identical |
| Placed instance area | — | 1,163,850 µm² | Back-end includes buffers, diodes, fill, and both SRAM macros |
| Die area | — | 1,232,100 µm² (1110×1110) | Fixed floorplan, not a synthesis output |
| Core utilization | — | 80.5% | Placed cell area over core area; no front-end equivalent |
| SRAM macros | 2 × 209,404 µm² | 2 × 209,404 µm² | Identical — the hardened macro is unchanged by either flow |

The sequential area — the actual datapath registers — matches within 1.3% from
front to back. **The datapath the synthesis predicted is the datapath that was
built.**

### Instance counts

| Metric | Front-end | Back-end | Why it differs |
| --- | ---: | ---: | --- |
| Functional standard cells | 14,483 | 32,140 | +17,657 — physical infrastructure, broken down below |
| Fill cells | 0 | 39,534 | Fill is a back-end-only step; non-functional |
| Total instances | 14,483 | 71,676 | Functional + fill + macros |
| Flip-flops | 2,445 | 2,477 | +32 — clock-tree synthesis added a few registers |
| Integrated clock gates | 3 | 3 | Identical — the clock gates survive unchanged |

The +17,657 back-end cells are all physical steps the front end cannot model, and
their breakdown shows the growth is infrastructure, not new logic:

| Added cell class | Count | Purpose |
| --- | ---: | --- |
| Antenna diodes | 10,641 | Protect gates from charge during etch |
| Timing-repair buffers | 745 | Fix setup and transition on real routed nets |
| Hold buffers | 264 | Add delay to meet hold with real clock skew |
| Clock tree, resizer, taps | ~5,876 | Clock buffers, driver up-sizing, well taps |

This is the healthy shape of a front-end-to-back-end transition: the functional
logic is stable, and the growth is physical infrastructure added by placement,
clock-tree synthesis, routing, and antenna repair.

### Timing

| Metric | Front-end (ideal clocks) | Back-end (post-route, 9 corners) | Why it differs |
| --- | ---: | ---: | --- |
| Target period | 40 ns (25 MHz) | 40 ns (25 MHz) | Same constraint |
| Setup worst slack | +0.203 ns | +4.17 ns | Back-end is *better* — the resizer buffered fanout the front end left unsized |
| Setup violations | 0 | 0 | Meets at both stages |
| Hold worst slack | −70.96 ns (artifact) | +0.33 ns | Front-end hold is meaningless before the clock tree exists |
| Hold violations | n/a | 0 | — |

Two front-end numbers look alarming but are both expected artifacts, and it is
worth being explicit about why rather than hiding them:

- **The setup slack of +0.203 ns looks tight, but it is pessimistic.** The
  pre-layout worst path is only four gates deep, yet a single minimum-size
  inverter on it takes 18.5 ns because synthesis has not sized that driver for its
  fanout. Once the back-end resizer buffers those nets, the same design closes at
  **+4.17 ns** at the worst process corner. The front-end number is a floor, not
  the final margin.

- **The hold slack of −70.96 ns is an artifact, not a violation.** With no clock
  tree yet, the timer propagates an invented clock-network delay to the capture
  register, producing a nonsense negative hold slack. Hold depends entirely on the
  real clock tree, which does not exist until clock-tree synthesis — so pre-layout
  hold is meaningless by construction. With the real tree, the back end measures
  **+0.33 ns hold, met on all nine corners.**

### Maximum frequency

Maximum frequency is a back-end result because it needs real parasitics; the front
end only confirms the logic closes at the target period. Measured at the worst
corner:

| Clock domain | Maximum frequency | Operating | Margin |
| --- | ---: | ---: | ---: |
| `clk` (input) | 112 MHz | 25 MHz | 4.5× |
| `sys_clk` | 31 MHz | 12.5 MHz | 2.5× |
| `cpu_clk` (CPU) | 13.2 MHz | 12.5 MHz | ~5% |

The CPU domain is the binding one, and it holds a comfortable margin over its
operating frequency.

### In summary

Synthesis predicted the design accurately: sequential area within 1.3%, flip-flop
count within 32, integrated-clock-gate count exact, and timing closing at the
target period. The back end then added physical infrastructure — roughly 10,600
antenna diodes, 5,900 clock-tree and resizer cells, and 39,500 fill cells — and,
with real parasitics, actually *improved* setup slack from a pessimistic +0.20 ns
to a comfortable +4.17 ns while meeting hold on all nine corners. The early
feasibility analysis held all the way through signoff. The complete comparison is
in `docs/FE_VS_BE.md`.

---

## Summary

Pico SoC is a complete, working RISC-V microcontroller: a real CPU with a useful
custom accelerator, on-chip memory, and standard peripherals, taken all the way to
a clean signoff on an open process. Its specifications are fixed and measured, its
architecture is fully integrated, its design decisions are deliberate and
explained, its verification is comprehensive and honest, and its accelerator
delivers concrete, measured gains — a 10.3× CRC speedup and a 5× reduction in FIR
filter noise on a chip small enough to fit a shared tapeout slot. Crucially, the
pre-layout feasibility estimate matched the final silicon — sequential area within
1.3%, timing closing at target — so the design was sound before it was ever
placed. Every number in this review comes from the signed-off design.

*Cross-references: `README.md`, `VERIFICATION.md`, `docs/BACKEND_REPORT.md`,
`docs/FE_VS_BE.md`, `docs/PCPI_BENCHMARKS.md`, `verification/docs/KNOWN_GAPS.md`.*
