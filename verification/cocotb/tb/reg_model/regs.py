"""Register-abstraction layer (RAL) for the pico-soc DV suite.

The point of a RAL is that a register's bit layout lives in *exactly one place*.
Every consumer -- sequences, scoreboards, checks -- asks the model for a field
rather than re-hardcoding shifts and masks. Change the RTL layout, change one
constant here, and every test follows.

This is deliberately a small, dependency-free model rather than a full
``uvm_reg`` stack, because our block tests drive the bus with plain
``apb_write``/``apb_read`` helpers (no pyuvm sequencer), and several of our
registers have a *different read view than write view* (GPIO's output-readback,
UART DATA = TX on write / RX on read). Modelling read and write field maps as
first-class is more honest for this design than forcing one mirrored view.

Access types are documentation + intent for checks:
    RW  read-write        RO  read-only          WO  write-only
    RC  read-clears (a side effect on read, e.g. UART rx_valid)
    W1P write-1-pulses    (one-shot, e.g. SPI start)
"""
from dataclasses import dataclass, field as _dc_field


@dataclass(frozen=True)
class Field:
    name: str
    lsb: int
    width: int
    access: str = "RW"

    @property
    def mask(self):
        return ((1 << self.width) - 1) << self.lsb

    def extract(self, word):
        """Pull this field's value out of a full register word."""
        return (word >> self.lsb) & ((1 << self.width) - 1)

    def place(self, value):
        """Shift a field value into its position in a register word."""
        return (value & ((1 << self.width) - 1)) << self.lsb


class Register:
    """A register with (optionally distinct) read and write field views."""

    def __init__(self, name, offset, wfields=(), rfields=None, reset=0):
        self.name = name
        self.offset = offset
        self.reset = reset
        self.wfields = {f.name: f for f in wfields}
        # if no separate read view is given, reads see the write fields
        self.rfields = {f.name: f for f in (rfields if rfields is not None else wfields)}

    # -- write side -------------------------------------------------------
    def encode(self, **values):
        """Build a register word to WRITE from named write-field values."""
        word = 0
        for name, val in values.items():
            if name not in self.wfields:
                raise KeyError(f"{self.name} has no writable field '{name}'")
            word |= self.wfields[name].place(val)
        return word

    # -- read side --------------------------------------------------------
    def field(self, name, word):
        """Extract a named READ field from a register word."""
        if name not in self.rfields:
            raise KeyError(f"{self.name} has no readable field '{name}'")
        return self.rfields[name].extract(word)

    def decode(self, word):
        """Human-readable decode of a read word, driven by field metadata."""
        return " ".join(
            f"{f.name}=0x{f.extract(word):x}" for f in self.rfields.values()
        )

    def check(self, word, **expected):
        """Assert named read fields equal expected values; raise on mismatch."""
        for name, exp in expected.items():
            got = self.field(name, word)
            if got != exp:
                raise AssertionError(
                    f"{self.name}.{name} = 0x{got:x}, expected 0x{exp:x} "
                    f"(word=0x{word:08x}; {self.decode(word)})"
                )


class RegBlock:
    """A named collection of registers for one peripheral."""

    def __init__(self, name, regs):
        self.name = name
        self.regs = {r.name: r for r in regs}

    def __getattr__(self, item):
        regs = self.__dict__.get("regs", {})
        if item in regs:
            return regs[item]
        raise AttributeError(item)
