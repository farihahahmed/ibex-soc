from collections import defaultdict

class Coverpoint:
    def __init__(self, name, bins, goal=1, required=False):
        self.name = name
        self.bins = set(bins)
        self.goal = goal
        self.required = required
        self.hits = defaultdict(int)

    def sample(self, value=None):
        if value is None:
            self.hits["_total"] += 1
        else:
            self.hits[value] += 1

    def is_covered(self):
        if not self.bins:
            return self.hits["_total"] >= self.goal
        return all(self.hits[b] >= self.goal for b in self.bins)

    def missing(self):
        if not self.bins:
            return [] if self.hits["_total"] >= self.goal else ["_total"]
        return [b for b in self.bins if self.hits[b] < self.goal]

    def report(self):
        lines = [f"  Coverpoint '{self.name}' (required={self.required}):"]
        if self.bins:
            for b in sorted(self.bins, key=str):
                h = self.hits[b]
                status = "HIT" if h >= self.goal else "MISS"
                lines.append(f"    bin {b!r:20} hits={h} goal={self.goal} [{status}]")
        lines.append(f"    covered={self.is_covered()}")
        return "\n".join(lines)


class CoverageModel:
    def __init__(self):
        self.gpio = Coverpoint("gpio_value", bins=list(range(1, 32)), goal=1, required=False)
        self.events = Coverpoint(
            "flow_events",
            bins={"program_loaded", "cpu_started", "gpio_matched", "uart_matched", "spi_activity"},
            goal=1,
            required=True,   # MUST be hit or test fails
        )
        self.coverpoints = [self.gpio, self.events]

    def sample_gpio(self, val):
        self.gpio.sample(val & 0x1F)

    def sample_event(self, name):
        self.events.sample(name)

    def check_required(self):
        """Raise if any required coverpoint is incomplete."""
        misses = []
        for cp in self.coverpoints:
            if cp.required and not cp.is_covered():
                misses.append(f"{cp.name}: missing {cp.missing()}")
        if misses:
            raise AssertionError("Coverage goals failed: " + "; ".join(misses))

    def report(self):
        lines = ["", "========== Functional Coverage =========="]
        for cp in self.coverpoints:
            lines.append(cp.report())
        lines.append("=========================================")
        return "\n".join(lines)


cov = CoverageModel()
