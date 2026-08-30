"""
test_driver_mock.py
--------------------
Runs WITHOUT a PYNQ board. Mocks the MMIO/Overlay layer so the driver's
logic (seed validation, byte packing, error handling) can be verified by
a coding agent or CI runner that has no hardware attached.

Run:  python3 -m pytest software/tests/test_driver_mock.py -v
  or: python3 software/tests/test_driver_mock.py
"""

import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "driver"))

import rule30_driver  # noqa: E402


class FakeMMIO:
    """Minimal stand-in for pynq.MMIO backed by a dict, simulating the
    CA advancing by a fixed step on every read (good enough to test
    driver plumbing, NOT a substitute for the real hardware sim)."""
    def __init__(self, base_addr, addr_range):
        self.base_addr = base_addr
        self.addr_range = addr_range
        self._state = 0
        self._reads = 0

    def write(self, offset, value):
        if offset == rule30_driver.SEED_REG_OFFSET:
            self._state = value

    def read(self, offset):
        if offset == rule30_driver.DATA_REG_OFFSET:
            self._reads += 1
            self._state = (self._state * 1103515245 + 12345) & 0xFFFFFFFF
            return self._state
        return 0


def make_driver():
    rule30_driver.MMIO = FakeMMIO
    drv = rule30_driver.Rule30PRNG(overlay="fake-overlay-object")
    return drv


def test_seed_rejects_all_zero():
    drv = make_driver()
    try:
        drv.seed(0x00000000)
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_seed_rejects_all_one():
    drv = make_driver()
    try:
        drv.seed(0xFFFFFFFF)
        assert False, "expected ValueError"
    except ValueError:
        pass


def test_seed_and_read_roundtrip():
    drv = make_driver()
    drv.seed(0xDEADBEEF)
    val = drv.read()
    assert 0 <= val <= 0xFFFFFFFF


def test_stream_length():
    drv = make_driver()
    drv.seed(0xCAFEF00D)
    samples = drv.stream(50)
    assert len(samples) == 50
    assert len(set(samples)) > 1  # not stuck constant


def test_stream_bytes_length():
    drv = make_driver()
    drv.seed(0x12345678)
    raw = drv.stream_bytes(37)
    assert len(raw) == 37


if __name__ == "__main__":
    tests = [v for k, v in list(globals().items()) if k.startswith("test_")]
    passed = 0
    for t in tests:
        t()
        print(f"PASS: {t.__name__}")
        passed += 1
    print(f"\n{passed}/{len(tests)} tests passed")
