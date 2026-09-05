# Rule 30 Hardware PRNG for PYNQ-Z2

This project turns **Rule 30**, a simple cellular-automaton rule, into a small
hardware-based pseudo-random number generator. The design runs on an AMD/Xilinx
Zynq board, specifically the **PYNQ-Z2**, and can be read from Python.

You can use the project in two ways:

- **On a normal PC:** run the reference model, Verilog simulations, and software tests.
- **On a PYNQ-Z2:** build the Vivado design, load the bitstream, and read values from the hardware.

This is a pseudo-random generator, not a complete cryptographic random-number
source. Do not use it by itself for passwords, encryption keys, or other security-
critical secrets.

## Quick Start: PC Only

These steps do not require Vivado or a PYNQ-Z2.

### 1. Clone the project

```powershell
git clone <repository-url>
cd "Hardware Security Primitive Rule 30 Cellular Automaton (PRNG)"
```

### 2. Install the small set of PC tools

Install:

- Python 3.10 or newer
- Icarus Verilog
- Git

Create a Python environment and install the test runner:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip pytest
```

If PowerShell refuses to activate the environment, run the commands with
Command Prompt instead:

```text
.venv\Scripts\activate.bat
```

### 3. Run the Python driver tests

These tests use a fake memory interface, so no board is needed:

```powershell
python -m pytest software/tests/test_driver_mock.py -q
```

Expected result:

```text
5 passed
```

### 4. Run the hardware simulation

From the repository root:

```powershell
Set-Location hardware\ip_repo\rule30_axi_v1_0\tb
python golden_model.py --seed 0xDEADBEEF --generations 32 --gen_vectors expected.hex
iverilog -g2005 -o sim ..\hdl\rule30_core.v tb_rule30_core.v
vvp sim
```

The final line should say:

```text
PASS: all 33 generations match golden model.
```

Return to the repository root before running other commands:

```powershell
Set-Location ..\..\..\..
```

### 5. Run the stronger simulation

```powershell
Set-Location hardware\ip_repo\rule30_axi_v1_0\tb
python generate_harsh_vectors.py
iverilog -g2005 -o sim_harsh ..\hdl\rule30_core.v tb_rule30_core_harsh.v
vvp sim_harsh
```

This checks three additional seeds for 64 generations each.

### 6. Check captured sample data

The statistical checker accepts a binary sample file from hardware:

```powershell
python software/tests/test_statistical.py --file path\to\samples.bin
```

It reports simple monobit, runs, and byte-distribution checks. These checks are
sanity checks, not a certification of cryptographic security.

## PYNQ-Z2 Hardware Path

Use this path only after the PC tests pass.

### Requirements

- Vivado with the Zynq-7000 device family installed
- PYNQ-Z2 board files installed in Vivado
- A PYNQ-Z2 board and compatible PYNQ image
- A network connection between the PC and board

The Vivado version used to build the bitstream should be compatible with the
PYNQ image installed on the board.

### 1. Package the custom IP

The three hardware files are in:

```text
hardware/ip_repo/rule30_axi_v1_0/hdl/
```

They are:

```text
rule30_core.v                 Rule 30 calculation
rule30_axi_v1_0_S00_AXI.v     AXI4-Lite register interface
rule30_axi_v1_0.v             Top-level IP wrapper
```

The `tb` folder contains simulation files. Do not add those testbenches to the
synthesized hardware design.

In Vivado, package the parent folder:

```text
Tools > Create and Package New IP
```

Choose **Package a specified directory**, then select:

```text
hardware/ip_repo/rule30_axi_v1_0
```

Use these IP settings:

```text
Vendor:  xilinx.com
Library: user
Name:    rule30_axi
Version: 1.0
```

The packaged IP should appear as:

```text
xilinx.com:user:rule30_axi:1.0
```

This repository already includes the packaging helper:

```text
scripts/package_rule30_ip.tcl
```

### 2. Create the Vivado block design

Create an RTL project for the PYNQ-Z2 board, add `hardware/ip_repo` under
**Tools > Settings > Project Settings > IP > Repository**, and create a block
design named `system`.

Add these blocks:

1. **Zynq7 Processing System**
2. **Rule 30 AXI PRNG**

Run **Block Automation** for the Zynq processor and accept the PYNQ-Z2 preset.
Then run **Connection Automation** for the Rule 30 IP. Vivado should connect:

```text
processing_system7_0/M_AXI_GP0 -> rule30_axi_0/S00_AXI
```

Vivado should also create the AXI interconnect, clock, and reset connections.
Validate the design, create the HDL wrapper, generate output products, run
synthesis, implementation, and finally generate the bitstream.

### 3. Confirm the address

Open **Window > Address Editor** and find `rule30_axi_0/S00_AXI`.

The current PYNQ-Z2 design uses:

```text
Base address: 0x40000000
Range:        4K (0x1000)
```

The registers are:

```text
Base + 0x00   Write a seed
Base + 0x04   Read the current Rule 30 value
```

If Vivado assigns another base address, update `DEFAULT_BASE_ADDR` in
`software/driver/rule30_driver.py` to match Vivado exactly. Never assume the
address is unchanged after modifying the block design.

### 4. Collect the PYNQ files

After bitstream generation, collect the main hardware handoff and bitstream:

```text
system_wrapper.bit
system.hwh
```

Rename them with the same base name:

```text
rule30_prng.bit
rule30_prng.hwh
```

Keep both files in the same directory. The repository's expected output folder is:

```text
hardware/build/output/
```

Do not use the internal `system_axi_smc_0.hwh`; use the main `system.hwh`.

### 5. Run the board notebook

Copy the matching `.bit` and `.hwh` files, `notebooks/01_bringup.ipynb`, and the
`software` folder to the PYNQ-Z2. Open the notebook in Jupyter and run its cells.
It loads the overlay, writes `0xDEADBEEF`, and reads ten values.

The board-side result should show different values for successive reads.

The included deployment helper is:

```text
scripts/deploy_to_board.sh <board_ip> [user]
```

On Windows, run it from Git Bash or WSL, or copy the files to the board manually
with an SCP program. The default PYNQ username is usually `xilinx`.

## Important Notes

- Do not seed with `0x00000000` or `0xFFFFFFFF`; these states do not evolve under Rule 30.
- The driver rejects those two fixed-point seeds.
- The AXI interface is 32-bit AXI4-Lite.
- Register offsets are `0x00` for seed writes and `0x04` for data reads.
- The empty `hardware/constraints/pynq_z2.xdc` is intentional because this design has no external PL pins.
- The statistical test is an engineering sanity check, not NIST certification.

## Project Map

```text
hardware/ip_repo/.../hdl/   Synthesizable Verilog hardware
hardware/ip_repo/.../tb/    Python and Verilog simulations
software/driver/            PYNQ Python driver
software/tests/              PC-side tests and sample analysis
notebooks/                   PYNQ-Z2 bring-up notebook
scripts/                    Vivado packaging and deployment helpers
docs/address_map.md         Register address reference
```
