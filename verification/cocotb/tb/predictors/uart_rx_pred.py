"""Reference: observed RX serial bits → expected DATA byte."""
from tb.predictors.uart_tx_pred import bits_to_byte


def decode_rx_frame(bits):
    """bits: [start, d0..d7, stop] → byte or raise."""
    if len(bits) < 10:
        raise ValueError(f"short frame {bits}")
    if bits[0] != 0:
        raise ValueError("missing start bit")
    if bits[9] != 1:
        raise ValueError("missing stop bit")
    return bits_to_byte(bits[1:9])
