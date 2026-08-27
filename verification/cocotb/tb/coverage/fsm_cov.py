"""FSM state and arc coverage.

Samples every state machine in the design each clock and records which states
were entered and which transitions (arcs) were taken.

State coverage answers "did we reach this state". Arc coverage is the stronger
question: "did we take this particular transition". A design can reach every
state and still never exercise the path between two of them.

Unreachable states are declared rather than hidden. Reporting 9/9 with the
other four explained beats reporting 13/13 by quietly dropping them.
"""
from collections import defaultdict
from cocotb.triggers import RisingEdge

FSMS = {
    "u_fsm.mode": ("test_fsm", {0: "IDLE", 1: "RUN", 2: "COUNTDOWN"}),
    "u_mem.u_imem.u_gather.state": ("fetch_gather",
        {0: "IDLE", 1: "STREAM", 2: "DRAIN", 3: "PRESENT"}),
    "u_mem.u_imem.rbstate": ("imem_readback",
        {0: "RB_IDLE", 1: "RB_REQ", 2: "RB_WAIT"}),
    "u_mem.u_imem.sstate": ("imem_load",
        {0: "S_IDLE", 1: "S_B0", 2: "S_B1", 3: "S_B2", 4: "S_B3"}),
    "u_dmem_slave.u_dmem.state": ("dmem_narrow_top",
        {0: "D_IDLE", 1: "R_STREAM", 2: "R_DRAIN", 3: "R_PRESENT",
         4: "W_B0", 5: "W_B1", 6: "W_B2", 7: "W_B3", 8: "W_DONE",
         9: "L_B0", 10: "L_B1", 11: "L_B2", 12: "L_B3"}),
    "u_dmem_slave.astate": ("ahb_mem", {0: "A_IDLE", 1: "A_BUSY", 2: "A_DONE"}),
    "u_bridge.state": ("ahb_to_apb", {0: "IDLE", 1: "SETUP", 2: "ACCESS"}),
    "u_spi.u_spi.state": ("spi", {0: "IDLE", 1: "TRANSFER"}),
    "u_uart.u_uart.tstate": ("uart_tx",
        {0: "T_IDLE", 1: "T_START", 2: "T_DATA", 3: "T_STOP"}),
    "u_uart.u_uart.rstate": ("uart_rx",
        {0: "R_IDLE", 1: "R_START", 2: "R_DATA", 3: "R_STOP"}),
}

UNREACHABLE = {
    ("dmem_narrow_top", s): "ahb_mem ties ld_word_en low - no scan path to dmem"
    for s in ("L_B0", "L_B1", "L_B2", "L_B3")
}


class FsmCoverage:
    def __init__(self):
        self.states = defaultdict(set)
        self.arcs = defaultdict(set)
        self._prev = {}

    def sample(self, block, state):
        self.states[block].add(state)
        prev = self._prev.get(block)
        if prev is not None and prev != state:
            self.arcs[block].add((prev, state))
        self._prev[block] = state

    def report(self):
        L = ["", "========== FSM State and Arc Coverage =========="]
        tot = hit_t = 0
        for path, (block, enc) in FSMS.items():
            all_s = set(enc.values())
            unreach = {s for s in all_s if (block, s) in UNREACHABLE}
            target = all_s - unreach
            hit = self.states.get(block, set()) & target
            tot += len(target); hit_t += len(hit)
            pct = 100.0 * len(hit) / len(target) if target else 0.0
            L.append(f"  {block:18s} states {len(hit):2d}/{len(target):2d} "
                     f"({pct:5.1f}%)  arcs {len(self.arcs.get(block, set())):2d}")
            miss = target - hit
            if miss:
                L.append(f"    {'':16s} not reached: {sorted(miss)}")
            for s in sorted(unreach):
                L.append(f"    {'':16s} excluded {s}: {UNREACHABLE[(block, s)]}")
        pct = 100.0 * hit_t / tot if tot else 0.0
        L.append(f"  {'TOTAL':18s} states {hit_t}/{tot} ({pct:.1f}%)")
        L.append("===============================================")
        return "\n".join(L)


    # ---- cross-process accumulation -------------------------------------
    # Each cocotb test runs in its own process, so hits are persisted to a
    # shared JSON file. The union across the whole gate is the number that
    # matters: one test cannot reach every state, but the suite should.
    def persist(self, path="fsm_coverage.json"):
        import json, os
        data = {"states": {}, "arcs": {}}
        if os.path.exists(path):
            try: data = json.load(open(path))
            except Exception: pass
        for b, ss in self.states.items():
            data["states"][b] = sorted(set(data["states"].get(b, [])) | ss)
        for b, aa in self.arcs.items():
            prev = {tuple(x) for x in data["arcs"].get(b, [])}
            data["arcs"][b] = sorted(list(x) for x in (prev | aa))
        json.dump(data, open(path, "w"), indent=1)

    @staticmethod
    def load(path="fsm_coverage.json"):
        import json
        c = FsmCoverage()
        data = json.load(open(path))
        for b, ss in data["states"].items(): c.states[b] = set(ss)
        for b, aa in data["arcs"].items(): c.arcs[b] = {tuple(x) for x in aa}
        return c


fsm_cov = FsmCoverage()


async def sample_fsms(dut, clk):
    """Background coroutine: sample every FSM on each rising clock edge."""
    handles = {}
    for path, (block, enc) in FSMS.items():
        h = dut
        try:
            for part in path.split("."):
                h = getattr(h, part)
            handles[path] = (h, block, enc)
        except AttributeError:
            pass
    while True:
        await RisingEdge(clk)
        for path, (h, block, enc) in handles.items():
            try:
                v = int(h.value)
            except Exception:
                continue
            fsm_cov.sample(block, enc.get(v, f"?{v}"))
