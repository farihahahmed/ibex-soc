"""UART block functional coverage — publish bins for MDV close."""


class UartBlockCov:
    def __init__(self):
        self.tx_bytes = set()          # distinct TX data values
        self.rx_bytes = set()
        self.events = {
            "apb_write_data": 0,
            "apb_read_status": 0,
            "apb_read_data": 0,
            "serial_tx_frame": 0,
            "serial_rx_frame": 0,
            "predictor_match": 0,
        }

    def hit(self, name, value=None):
        if name in self.events:
            self.events[name] += 1
        if name == "tx_byte" and value is not None:
            self.tx_bytes.add(value & 0xFF)
        if name == "rx_byte" and value is not None:
            self.rx_bytes.add(value & 0xFF)

    def report(self):
        lines = ["========== UART block functional coverage =========="]
        for k, v in self.events.items():
            lines.append(f"  {k:20s} hits={v}")
        lines.append(f"  unique TX bytes     {len(self.tx_bytes)} -> {sorted(self.tx_bytes)[:16]}...")
        lines.append(f"  unique RX bytes     {len(self.rx_bytes)} -> {sorted(self.rx_bytes)[:16]}...")
        lines.append("==================================================")
        return "\n".join(lines)

    def pass_gate(self, min_tx_unique=3):
        return (
            self.events["serial_tx_frame"] >= 1
            and self.events["predictor_match"] >= 1
            and len(self.tx_bytes) >= min_tx_unique
        )


# singleton used by block tests
cov = UartBlockCov()
