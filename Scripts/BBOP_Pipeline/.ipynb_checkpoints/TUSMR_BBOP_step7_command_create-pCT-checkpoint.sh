#!/bin/bash

# ===========================================================
# Step 7: Create pseudo-CT (pCT) from PETRA using UCL petra-to-ct
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT>
#
# Inputs:
#   ${SUBJECT}_PETRA.nii               (in subject root)
#
# Outputs:
#   ${SUBJECT}_pCT.nii                 (in subject root)
#   Babelbrain/${SUBJECT}_PETRA.nii    (moved PETRA)
#
# Notes:
#   - Optional step, only used when --with-pCT is passed.
#   - Idempotent: skips if pCT + moved PETRA already exist.
# ===========================================================

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

DEST="$BASE_DIR/Analysis/Zapping/$SUBJECT"
BABELBRAIN_DIR="$DEST/Babelbrain"

PETRA_IN="$DEST/${SUBJECT}_PETRA.nii"
PCT_OUT="$DEST/${SUBJECT}_pCT.nii"
PETRA_MOVED="$BABELBRAIN_DIR/${SUBJECT}_PETRA.nii"

DONE_FLAG="$DEST/.BBOP_step7_done"

echo
echo "=== Step 7: Create pseudo-CT for subject ${SUBJECT} ==="
echo

###############################################################
# Step 0: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Step 7 already marked as completed (flag: $DONE_FLAG)"

    if [ -f "$PCT_OUT" ] && [ -f "$PETRA_MOVED" ]; then
        echo "    Found existing outputs:"
        echo "      - pCT:   $PCT_OUT"
        echo "      - PETRA: $PETRA_MOVED"
        echo "    Skipping Step 7."
        echo
        exit 0
    else
        echo "    WARNING: Completion flag exists but expected outputs are missing."
        echo "    Re-running Step 7 to regenerate outputs."
        echo
    fi
fi

###############################################################
# Step 1: Sanity checks
###############################################################
if [ ! -d "$DEST" ]; then
    echo "Error: Subject directory not found: $DEST"
    exit 1
fi

if [ ! -f "$PETRA_IN" ]; then
    echo "Error: PETRA file not found at $PETRA_IN"
    exit 1
fi

if ! command -v matlab >/dev/null 2>&1; then
    echo "Error: MATLAB not found in PATH."
    exit 1
fi

if [ -z "${PETRA2CT_DIR:-}" ]; then
    echo "Error: PETRA2CT_DIR not set."
    exit 1
fi

mkdir -p "$BABELBRAIN_DIR"

echo "Subject directory:   $DEST"
echo "PETRA input file:    $PETRA_IN"
echo "Pseudo-CT output:    $PCT_OUT"
echo "Babelbrain folder:   $BABELBRAIN_DIR"
echo "petra-to-ct toolbox: $PETRA2CT_DIR"
echo

###############################################################
# Step 2: Run MATLAB pCT conversion
###############################################################
MATLAB_CMD="
addpath('$PETRA2CT_DIR');
cd('$DEST');
petraToCT.convert('${SUBJECT}_PETRA.nii');
exit;
"

echo "Running MATLAB petraToCT.convert ..."
matlab -batch "$MATLAB_CMD"

PETRA2CT_SUBFOLDER="$DEST/PetraToCT"
PCT_SRC="$PETRA2CT_SUBFOLDER/pCT.nii"

if [ ! -f "$PCT_SRC" ]; then
    echo "Error: Expected pseudo-CT not found at:"
    echo "  $PCT_SRC"
    exit 1
fi

###############################################################
# Step 3: Copy pCT to subject root
###############################################################
echo "Copying pseudo-CT to $PCT_OUT ..."
cp "$PCT_SRC" "$PCT_OUT"

###############################################################
# Step 4: Move PETRA into BabelBrain folder
###############################################################
echo "Moving original PETRA to $PETRA_MOVED ..."
mv "$PETRA_IN" "$PETRA_MOVED"

###############################################################
# Step 5: Mark completion
###############################################################
touch "$DONE_FLAG"
echo "Completion flag written to: $DONE_FLAG"

###############################################################
# Final status
###############################################################
echo
echo "Step 7 completed successfully for subject $SUBJECT."
echo "  - pCT:   $PCT_OUT"
echo "  - PETRA: $PETRA_MOVED"
echo
