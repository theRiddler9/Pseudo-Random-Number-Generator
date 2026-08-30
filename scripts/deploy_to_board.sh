#!/usr/bin/env bash
# deploy_to_board.sh
# Copies the bitstream/hwh pair and notebooks to the PYNQ-Z2 over SSH.
#
# Usage:
#   ./scripts/deploy_to_board.sh <board_ip> [user]
# Example:
#   ./scripts/deploy_to_board.sh 192.168.2.99 xilinx
#
# Default PYNQ-Z2 credentials: user "xilinx", password "xilinx".

set -euo pipefail

BOARD_IP="${1:?Usage: deploy_to_board.sh <board_ip> [user]}"
BOARD_USER="${2:-xilinx}"
REMOTE_DIR="/home/xilinx/jupyter_notebooks/rule30_prng"

BIT_SRC="./hardware/build/output/rule30_prng.bit"
HWH_SRC="./hardware/build/output/rule30_prng.hwh"

if [[ ! -f "$BIT_SRC" || ! -f "$HWH_SRC" ]]; then
    echo "ERROR: build outputs not found at $BIT_SRC / $HWH_SRC"
    echo "Run the Vivado build first (scripts/setup_vivado_project.tcl)."
    exit 1
fi

echo "Creating remote directory..."
ssh "${BOARD_USER}@${BOARD_IP}" "mkdir -p ${REMOTE_DIR}"

echo "Copying bitstream + hardware handoff..."
scp "$BIT_SRC" "$HWH_SRC" "${BOARD_USER}@${BOARD_IP}:${REMOTE_DIR}/"

echo "Copying notebooks..."
scp -r ./notebooks/*.ipynb "${BOARD_USER}@${BOARD_IP}:${REMOTE_DIR}/"

echo "Copying driver + test code..."
scp -r ./software "${BOARD_USER}@${BOARD_IP}:${REMOTE_DIR}/"

echo "Done. On the board, open Jupyter at http://${BOARD_IP}:9090 and navigate to"
echo "rule30_prng/notebooks/01_bringup.ipynb"
