# Shared verification agents (UVCs)

Single import root for block and chip tests:

    from tb.agents.apb import ApbItem, ApbDriver, ApbMonitor, ApbAgent
    from tb.agents.apb import dut_handle   # block APB signal bind

## Layout

| Path | Role |
|------|------|
| `apb/` | **Shared bus UVC** — item, driver, monitor, agent |
| `uart_serial/` | Passive UART TX monitor (block MDV) |
| `gpio/`, `uart/`, `spi/` | Chip-level pin monitors |
| `scan/` | Scan-chain agent (chip boot / sequences) |

## Rules

1. **Block APB masters** import only from `tb.agents.apb` (no local copy of driver/item).
2. Prefer package imports:
   `from tb.agents.apb import ApbItem, ApbDriver`
   not deep `tb.agents.apb.item` (works either way; package is the contract).
3. `PYTHONPATH` must include `verification/cocotb` (block Makefiles already set this).
4. New bus protocol VIP → new folder under `tb/agents/`, export in that folder’s `__init__.py`.

## Used by

- `block/uart` — ApbDriver / ApbItem
- `block/gpio` — ApbDriver / ApbItem
- `block/spi` — ApbDriver / ApbItem
- chip env — scan / gpio / uart / spi agents

This is the Pico SoC equivalent of a shared `dv/uvc` tree.
