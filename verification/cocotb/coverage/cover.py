"""Simple functional coverage for ibex-soc"""

from collections import defaultdict

class Coverage:
    def __init__(self):
        self.bins = defaultdict(set)      # name → set of hit values
        self.counts = defaultdict(int)    # name → hit count

    def hit(self, name, value=None):
        """Record a hit. If value is given it is treated as a bin."""
        self.counts[name] += 1
        if value is not None:
            self.bins[name].add(value)

    def report(self):
        print("\n========== Functional Coverage Report ==========")
        for name in sorted(self.counts.keys()):
            cnt = self.counts[name]
            bins = self.bins.get(name)
            if bins is not None:
                print(f"  {name:25s}  hits={cnt:4d}  unique_bins={len(bins)}  values={sorted(bins)}")
            else:
                print(f"  {name:25s}  hits={cnt:4d}")
        print("================================================\n")

    def get_coverage_summary(self):
        return dict(self.counts), {k: len(v) for k, v in self.bins.items()}


# Global coverage instance that tests can import
cov = Coverage()
