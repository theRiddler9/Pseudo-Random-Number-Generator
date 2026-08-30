# Rule 30 Hardware Security Primitive (PRNG) — PYNQ-Z2

A hardware PRNG based on the Rule 30 elementary cellular automaton, exposed to the
ARM Cortex-A9 (PS) over AXI4-Lite on a Zynq-7000 SoC (PYNQ-Z2).

## Status of this scaffold

The **software model and RTL core are already written and verified** in this repo:
`hardware/ip_repo/rule30_axi_v1_0/hdl/rule30_core.v` was simulated against
`hardware/ip_repo/rule30_axi_v1_0/tb/golden_model.py` with Icarus Verilog and
**passes bit-exact across 33 generations**. The AXI wrapper syntax-checks cleanly.
What's left is Vivado-side work (IP packaging, block design, bitstream) which needs
the actual Vivado GUI/toolchain — see the step order below.

## Build order (do not skip ahead)

1. **Python golden model** — `hardware/ip_repo/rule30_axi_v1_0/tb/golden_model.py`.
   Defines "correct" behavior in ~15 lines of Python before any RTL exists. Run it,
   eyeball the trace, confirm it looks chaotic and non-repeating.
2. **Verilog core** — `hardware/ip_repo/rule30_axi_v1_0/hdl/rule30_core.v`.
   Written to match the golden model's indexing exactly (mod-WIDTH neighbor lookup).
3. **Simulate & diff** — `hardware/ip_repo/rule30_axi_v1_0/tb/tb_rule30_core.v`.
   ```
   cd hardware/ip_repo/rule30_axi_v1_0/tb
   python3 golden_model.py --seed 0xDEADBEEF --generations 32 --gen_vectors expected.hex
   iverilog -g2005 -o sim ../hdl/rule30_core.v tb_rule30_core.v
   vvp sim
   ```
   Must print `PASS: all 33 generations match golden model.` before moving on.
4. **AXI wrapper** — `hdl/rule30_axi_v1_0_S00_AXI.v` + `hdl/rule30_axi_v1_0.v`.
   Standard AXI4-Lite slave state machine, already wired to the verified core.
5. **Vivado**: package the IP, build the block design, generate the bitstream.
   Use `scripts/setup_vivado_project.tcl` as a starting point (batch-mode reproducible
   build) — you will still need to open Vivado at least once to confirm the IP's VLNV
   after packaging and to check the Address Editor for the assigned base address.
6. **Deploy** — `scripts/deploy_to_board.sh <board_ip>` copies the `.bit`/`.hwh` pair,
   notebooks, and software to the board over SSH.
7. **Bring-up** — `notebooks/01_bringup.ipynb`. Load the overlay, seed, read 10 times,
   confirm values differ.
8. **Statistical validation** — `software/tests/test_statistical.py` (monobit, runs,
   byte chi-square) against live hardware samples or a captured `.bin` file.
9. **Demo polish** — `software/benchmarks/hw_vs_sw_throughput.py` for the
   hardware-vs-software comparison talking point; `notebooks/02_entropy_analysis.ipynb`
   for histograms/plots (create this from `test_statistical.py`'s data path).

## Folder structure

See `docs/` for the address map. Full layout:

```
rule30-hw-prng/
├── hardware/           Verilog RTL, testbench, Vivado build scripts, constraints
├── software/           PYNQ driver, tests (mocked + statistical), benchmarks
├── notebooks/          Jupyter notebooks for bring-up and the live demo
├── ui/                 Optional dashboard front-end
├── data/               Captured samples, sim outputs (gitignore the large ones)
├── docs/               Address map, math derivation, block diagram
└── scripts/            Vivado Tcl build + SSH deploy scripts
```

## Known pitfalls (read before debugging blind)

- **Seed of `0x00000000` or `0xFFFFFFFF` never evolves** — both are Rule 30 fixed
  points. The driver rejects them; don't remove that check.
- **Base address mismatch** — Vivado's Connection Automation does not always assign
  `0x43C00000`. Check Address Editor and update `software/driver/rule30_driver.py`.
- **All-X on first read** — usually means `rst_n` never deasserted or `load_seed`
  never pulsed. Re-check the AXI write-address/write-data handshake timing in
  `tb_rule30_core.v`'s style if you add a full-AXI testbench.
- **Vivado/PYNQ version mismatch** — the Vivado version used to build the bitstream
  must match what your board's PYNQ image expects. Check `pynq.__version__` on the
  board against Xilinx's compatibility table before building.
