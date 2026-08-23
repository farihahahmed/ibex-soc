"""Reference model: APB DATA write → expected UART TX bit stream (LSB first)."""

def expected_tx_bits(byte: int):
    """Return list of bits: start(0), d0..d7, stop(1)."""
    bits = [0]  # start
    for i in range(8):
        bits.append((byte >> i) & 1)
    bits.append(1)  # stop
    return bits


def bits_to_byte(data_bits):
    """data_bits: 8 LSB-first bits → integer."""
    v = 0
    for i, b in enumerate(data_bits):
        v |= (b & 1) << i
    return v
