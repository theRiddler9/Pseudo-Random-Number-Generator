"""
test_statistical.py
--------------------
Lightweight entropy sanity checks - NOT a replacement for full NIST STS,
but enough to catch a broken/degenerate PRNG at demo time and to make a
believable "quality of randomness" slide.

Run against real hardware samples:
    python3 software/tests/test_statistical.py --bitfile /path/to/rule30_prng.bit

Run against captured data (no board needed):
    python3 software/tests/test_statistical.py --file data/raw_samples/samples.bin
"""

import argparse
import math
import sys
import os


def monobit_test(bits: str) -> float:
    """Frequency (monobit) test: proportion of 1s should be ~0.5.
    Returns the p-value-like score via a simple normal approximation."""
    n = len(bits)
    ones = bits.count("1")
    s = abs(ones - (n - ones)) / math.sqrt(n)
    p = math.erfc(s / math.sqrt(2))
    return p


def runs_test(bits: str) -> float:
    """Runs test: checks the number of transitions (0->1, 1->0) is
    consistent with what a random sequence would produce."""
    n = len(bits)
    ones = bits.count("1")
    pi = ones / n
    if abs(pi - 0.5) >= (2 / math.sqrt(n)):
        return 0.0  # frequency test would already fail; runs test not meaningful
    v_obs = 1
    for i in range(1, n):
        if bits[i] != bits[i - 1]:
            v_obs += 1
    p = math.erfc(abs(v_obs - 2 * n * pi * (1 - pi)) /
                   (2 * math.sqrt(2 * n) * pi * (1 - pi)))
    return p


def byte_chi_square(raw: bytes) -> float:
    """Chi-square goodness-of-fit of byte values against a uniform
    distribution over 0-255. Lower chi-square (closer to 255 dof) = more
    uniform. Returns the chi-square statistic (not a p-value)."""
    counts = [0] * 256
    for b in raw:
        counts[b] += 1
    n = len(raw)
    expected = n / 256
    chi2 = sum(((c - expected) ** 2) / expected for c in counts)
    return chi2


def bytes_to_bitstring(raw: bytes) -> str:
    return "".join(format(b, "08b") for b in raw)


def run_all(raw: bytes):
    bits = bytes_to_bitstring(raw)
    n_bits = len(bits)
    n_bytes = len(raw)

    print(f"Sample size: {n_bytes} bytes ({n_bits} bits)\n")

    p_mono = monobit_test(bits)
    print(f"Monobit test        p ~= {p_mono:.4f}  "
          f"{'OK' if p_mono > 0.01 else 'SUSPECT (check for stuck bits)'}")

    p_runs = runs_test(bits)
    print(f"Runs test           p ~= {p_runs:.4f}  "
          f"{'OK' if p_runs > 0.01 else 'SUSPECT (check for periodicity)'}")

    chi2 = byte_chi_square(raw)
    # For 255 dof, chi2 should land roughly in [190, 320] for a good uniform source
    print(f"Byte chi-square     chi2 = {chi2:.1f}  (255 dof; ~200-320 expected)  "
          f"{'OK' if 150 < chi2 < 400 else 'SUSPECT (check for byte bias)'}")


def collect_from_board(bitfile: str, n_bytes: int) -> bytes:
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "driver"))
    from rule30_driver import Rule30PRNG
    prng = Rule30PRNG(bitfile=bitfile)
    prng.seed(0xDEADBEEF)
    return prng.stream_bytes(n_bytes)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--bitfile", help="Path to .bit to load on the board and sample live")
    ap.add_argument("--file", help="Path to a raw binary file of previously captured samples")
    ap.add_argument("--n_bytes", type=int, default=4096)
    args = ap.parse_args()

    if args.bitfile:
        data = collect_from_board(args.bitfile, args.n_bytes)
    elif args.file:
        with open(args.file, "rb") as f:
            data = f.read()
    else:
        print("Provide --bitfile (run on board) or --file (analyze captured data)")
        sys.exit(1)

    run_all(data)
