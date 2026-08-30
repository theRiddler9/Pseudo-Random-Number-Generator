"""
hw_vs_sw_throughput.py
------------------------
Demo-day comparison: how fast can the ARM core (running pure Python Rule 30)
generate 32-bit numbers vs. reading them from the FPGA-accelerated core.

Run on the board:
    python3 software/benchmarks/hw_vs_sw_throughput.py --bitfile /path/to/rule30_prng.bit
"""

import argparse
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..",
                                 "hardware", "ip_repo", "rule30_axi_v1_0", "tb"))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "driver"))

from golden_model import next_state  # noqa: E402


def bench_software(n: int, seed: int = 0xDEADBEEF):
    state = seed
    t0 = time.perf_counter()
    for _ in range(n):
        state = next_state(state)
    t1 = time.perf_counter()
    return t1 - t0


def bench_hardware(n: int, bitfile: str, seed: int = 0xDEADBEEF):
    from rule30_driver import Rule30PRNG
    prng = Rule30PRNG(bitfile=bitfile)
    prng.seed(seed)
    t0 = time.perf_counter()
    for _ in range(n):
        prng.read()
    t1 = time.perf_counter()
    return t1 - t0


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--bitfile", required=True)
    ap.add_argument("--n", type=int, default=5000,
                     help="Number of 32-bit samples to generate/read")
    args = ap.parse_args()

    sw_time = bench_software(args.n)
    hw_time = bench_hardware(args.n, args.bitfile)

    print(f"Software (ARM, pure Python Rule 30): {args.n} samples in {sw_time:.4f}s "
          f"({args.n / sw_time:,.0f} samples/sec)")
    print(f"Hardware (AXI reads from PL core):   {args.n} samples in {hw_time:.4f}s "
          f"({args.n / hw_time:,.0f} samples/sec)")
    print("\nNote: hardware throughput here is bounded by AXI/Python call overhead, "
          "not the CA itself -- the PL core advances a full generation every PL "
          "clock cycle (e.g. 100M generations/sec at 100MHz) regardless of how "
          "fast software polls it. Frame the comparison around 'entropy freshness "
          "per read', not raw read throughput.")
