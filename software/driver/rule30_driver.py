"""
rule30_driver.py
-----------------
Driver for the Rule 30 hardware PRNG, loaded via a PYNQ Overlay.
Runs on the board (ARM Cortex-A9 PS side, inside Jupyter or a script).

Usage:
    from rule30_driver import Rule30PRNG
    prng = Rule30PRNG(bitfile="/home/xilinx/jupyter_notebooks/rule30_prng.bit")
    prng.seed(0xDEADBEEF)
    print(hex(prng.read()))
    samples = prng.stream(1000)   # list of 1000 32-bit ints
"""

import time

try:
    from pynq import Overlay, MMIO
except ImportError:  # allows importing this module off-board for linting/tests
    Overlay = None
    MMIO = None

# Must match hardware/build/system_bd's Address Editor assignment for the
# custom IP -- check this in Vivado (Address Editor tab) after Connection
# Automation, it will NOT always be 0x43C00000 if you add other PL peripherals.
DEFAULT_BASE_ADDR = 0x40000000
DEFAULT_ADDR_RANGE = 0x1000

SEED_REG_OFFSET = 0x00
DATA_REG_OFFSET = 0x04


class Rule30PRNG:
    def __init__(self, bitfile=None, base_addr=DEFAULT_BASE_ADDR,
                 addr_range=DEFAULT_ADDR_RANGE, overlay=None):
        """
        bitfile: path to .bit (its matching .hwh must sit alongside it).
                 If `overlay` is already loaded elsewhere, pass it instead
                 and leave bitfile=None.
        """
        if overlay is not None:
            self.overlay = overlay
        elif bitfile is not None:
            self.overlay = Overlay(bitfile)
        else:
            raise ValueError("Provide either bitfile= or overlay=")

        self.mmio = MMIO(base_addr, addr_range)

    def seed(self, value: int):
        """Write a 32-bit seed. Any nonzero value works; avoid 0x00000000
        and 0xFFFFFFFF -- both are fixed points of Rule 30 and will not
        evolve (the CA output would be constant)."""
        if value & 0xFFFFFFFF in (0x00000000, 0xFFFFFFFF):
            raise ValueError("Seed must not be all-zero or all-one bits "
                              "(these are Rule 30 fixed points).")
        self.mmio.write(SEED_REG_OFFSET, value & 0xFFFFFFFF)

    def read(self) -> int:
        """Read the current 32-bit CA state."""
        return self.mmio.read(DATA_REG_OFFSET)

    def stream(self, n: int, delay_s: float = 0.0):
        """Collect n successive reads. Because the hardware free-runs at
        the PL clock (e.g. 100 MHz) independent of software timing, each
        AXI read is naturally advanced many generations from the last --
        no artificial delay is required for entropy, but a small delay_s
        is exposed for controlled/benchmarking use."""
        out = []
        for _ in range(n):
            out.append(self.read())
            if delay_s:
                time.sleep(delay_s)
        return out

    def stream_bytes(self, n_bytes: int) -> bytes:
        """Convenience: return raw bytes for feeding into entropy/statistical
        tests or downstream consumers (e.g. key material -- see docs for
        the caveat about why this alone is NOT cryptographically sufficient)."""
        n_words = (n_bytes + 3) // 4
        words = self.stream(n_words)
        raw = b"".join(w.to_bytes(4, "little") for w in words)
        return raw[:n_bytes]
