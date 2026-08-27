"""Memory-map / address-decode coverage.

Answers the coverage question our block tests don't: was *every* bus region
exercised at its boundaries, and was the unmapped space exercised too?

The interconnect decodes ``HADDR[17:16]`` into four regions (see
``memory_map.md`` and ``rtl/ahb_interconnect.sv``):

    00  memory (dmem, 0x0000_0000-0x0000_01FF)
    01  GPIO   (0x0001_0000-0x0001_000F)
    10  UART   (0x0002_0000-0x0002_000F)
    11  SPI    (0x0003_0000-0x0003_00FF)

For each *mapped* region we want its low, mid, and high address touched at
least once (boundary + interior). We also track that every region's decode
bit-pattern was seen, and that at least one access landed in the unmapped tail
of a region so the "defined behaviour on a gap" path is exercised rather than
assumed.

This is deliberately a plain sampler built on the existing Coverpoint class so
it composes with the current CoverageModel and needs no new dependencies.
"""
from .model import Coverpoint

# region_id -> (name, base, last_valid_offset_inclusive)
REGIONS = {
    0b00: ("dmem", 0x0000_0000, 0x1FF),
    0b01: ("gpio", 0x0001_0000, 0x00F),
    0b10: ("uart", 0x0002_0000, 0x00F),
    0b11: ("spi",  0x0003_0000, 0x0FF),
}


def region_of(addr):
    """Return the 2-bit region id the interconnect would decode for addr."""
    return (addr >> 16) & 0b11


def _band(addr, base, last):
    """Classify an address within its region as low / mid / high / unmapped."""
    off = addr - base
    if off < 0 or off > 0xFFFF:
        return "unmapped"
    if off > last:
        return "unmapped"          # past the region's populated range
    if off == 0:
        return "low"
    if off == last:
        return "high"
    return "mid"


class MemoryMapCoverage:
    """Coverage over region decode and per-region low/mid/high/unmapped bands."""

    def __init__(self, required=True):
        # every region's decode pattern must be seen
        self.regions = Coverpoint(
            "decode_region",
            bins={name for _, (name, _, _) in REGIONS.items()},
            goal=1,
            required=required,
        )
        # per region, the three interior bands
        self.bands = Coverpoint(
            "region_band",
            bins={
                f"{name}:{band}"
                for _, (name, _, _) in REGIONS.items()
                for band in ("low", "mid", "high")
            },
            goal=1,
            required=required,
        )
        # unmapped / out-of-range accesses (not per-region-required, but tracked)
        self.unmapped = Coverpoint(
            "unmapped_access", bins=set(), goal=1, required=False
        )
        self.coverpoints = [self.regions, self.bands, self.unmapped]

    def sample(self, addr):
        rid = region_of(addr)
        name, base, last = REGIONS[rid]
        self.regions.sample(name)
        band = _band(addr, base, last)
        if band == "unmapped":
            self.unmapped.sample()
        else:
            self.bands.sample(f"{name}:{band}")

    # --- reporting / closure, mirroring CoverageModel ---------------------
    def check_required(self):
        misses = []
        for cp in self.coverpoints:
            if cp.required and not cp.is_covered():
                misses.append(f"{cp.name}: missing {cp.missing()}")
        if misses:
            raise AssertionError(
                "Memory-map coverage goals failed: " + "; ".join(misses)
            )

    def report(self):
        lines = ["", "===== Memory-Map / Address-Decode Coverage ====="]
        for cp in self.coverpoints:
            lines.append(cp.report())
        lines.append("================================================")
        return "\n".join(lines)


if __name__ == "__main__":
    # Self-test: sweep low/mid/high of every mapped region + an unmapped gap.
    mm = MemoryMapCoverage()
    for rid, (name, base, last) in REGIONS.items():
        for off in (0, last // 2, last):
            mm.sample(base + off)
    # one deliberately-unmapped access (past dmem's populated tail)
    mm.sample(0x0000_0000 + 0x400)
    print(mm.report())
    mm.check_required()          # must not raise
    print("\nSELF-TEST PASS: all required bands + regions covered")
