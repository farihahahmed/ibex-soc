"""Functional coverage for the depth/stress paths.

Every stress scenario a test exercises is sampled into a named bin, and the
gate can require closure. This turns the depth tests from 'they ran' into
'these behaviors are covered', mirroring the FSM/memory-map collectors.
"""
import json
import os
from .model import Coverpoint

_STORE = os.path.join(os.path.dirname(__file__), "..", "..", "stress_coverage.json")

BINS = {
    "uart": {"tx_back_to_back", "rx_overrun", "rx_glitch_reject",
             "rx_bad_stop", "midframe_reset", "tx_bitlevel",
             "status_poll_race", "full_duplex"},
    "spi": {"busy_handshake", "rx_all_ones", "rx_all_zeros",
            "rx_bit_pattern", "write_while_busy"},
    "ahb": {"routing_random", "routing_multiseed", "hready_stall_mux"},
}


class StressCoverage:
    def __init__(self):
        self.cps = {k: Coverpoint(f"stress_{k}", bins=v, goal=1, required=True)
                    for k, v in BINS.items()}

    def hit(self, group, bin_name):
        self.cps[group].sample(bin_name)
        self._persist(group, bin_name)

    # accumulate across separate test processes, like fsm_cov
    def _persist(self, group, bin_name):
        data = {}
        if os.path.exists(_STORE):
            try:
                data = json.load(open(_STORE))
            except Exception:
                data = {}
        data.setdefault(group, [])
        if bin_name not in data[group]:
            data[group].append(bin_name)
        json.dump(data, open(_STORE, "w"))

    @staticmethod
    def report_and_check():
        data = {}
        if os.path.exists(_STORE):
            data = json.load(open(_STORE))
        lines = ["", "===== Stress-Path Functional Coverage ====="]
        missing = []
        for g, bins in BINS.items():
            hit = set(data.get(g, []))
            lines.append(f"  {g:5} {len(hit & bins)}/{len(bins)}")
            miss = bins - hit
            if miss:
                missing.append(f"{g}: {sorted(miss)}")
        lines.append("=" * 44)
        print("\n".join(lines))
        if missing:
            raise SystemExit("STRESS COVERAGE MISSING -> " + "; ".join(missing))
        print("STRESS COVERAGE: CLOSED")
