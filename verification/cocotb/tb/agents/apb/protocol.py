"""APB protocol checks (B3 bus properties)."""

class ApbProtocolError(AssertionError):
    pass

def check_setup(item, psel, penable, pwrite, paddr, pwdata):
    """Call at start of SETUP (PSEL=1, PENABLE=0)."""
    if int(psel) != 1:
        raise ApbProtocolError("SETUP: PSEL must be 1")
    if int(penable) != 0:
        raise ApbProtocolError("SETUP: PENABLE must be 0")

def check_access(item, psel, penable, pready):
    """Call during ACCESS (PSEL=1, PENABLE=1)."""
    if int(psel) != 1:
        raise ApbProtocolError("ACCESS: PSEL must be 1")
    if int(penable) != 1:
        raise ApbProtocolError("ACCESS: PENABLE must be 1")
    # PREADY may be 0 for wait states; driver waits until 1

def check_idle(psel, penable):
    """Between transfers."""
    if int(psel) == 0 and int(penable) == 1:
        raise ApbProtocolError("IDLE: PENABLE=1 with PSEL=0 is illegal")
