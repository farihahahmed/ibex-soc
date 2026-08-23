# Bus properties (B3)

## APB (active)
File: `verification/cocotb/tb/agents/apb/protocol.py`

| Check | Rule |
|-------|------|
| SETUP | PSEL=1, PENABLE=0 |
| ACCESS | PSEL=1, PENABLE=1 |
| IDLE | never PSEL=0 and PENABLE=1 |

Enforced by `ApbDriver` on every transfer (raises `ApbProtocolError`).

## AHB
Optional follow-up: HTRANS/HREADY stable-address rules in a future AHB agent.
