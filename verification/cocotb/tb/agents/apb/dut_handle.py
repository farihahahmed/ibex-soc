"""Shared APB handle for block + chip (ApbIf or legacy DUT)."""

# Prefer IF (ApbIf). Legacy DUT kept for old tests that set DUT only.
IF = None
DUT = None

def get_bus():
    if IF is not None:
        return IF
    if DUT is not None:
        return DUT
    return None
