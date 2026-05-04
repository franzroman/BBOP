#!/bin/bash

# Step 4: Resample T1 (required) and T2 (optional) to 1 mm isotropic resolution.
#
# Usage: $0 <BASE_DIR> <SUBJECT>
#
# Inputs (expected from previous steps):
#   BASE_DIR/Analysis/Zapping/$SUBJECT/${SUBJECT}_T1.nii     (required)
#   BASE_DIR/Analysis/Zapping/$SUBJECT/${SUBJECT}_T2.nii     (optional)
#
# Outputs:
#   BASE_DIR/Analysis/Zapping/$SUBJECT/${SUBJECT}_T1_iso1mm.nii.gz
#   BASE_DIR/Analysis/Zapping/$SUBJECT/${SUBJECT}_T2_iso1mm.nii.gz   (only if T2 exists)
#
# Notes:
#   - T1 is mandatory for BBOP.
#   - T2 is optional. If missing, T2 resampling and subsequent steps (6–7) will be skipped gracefully.
#   - Originals (T1 and/or T2) are moved to MR-cache/.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

folder_path="$BASE_DIR/Analysis/Zapping/$SUBJECT"
mrcache_path="$folder_path/MR-cache"
DONE_FLAG="$folder_path/.BBOP_step4_done"

# Input files
t1_input="$folder_path/${SUBJECT}_T1.nii"
t2_input="$folder_path/${SUBJECT}_T2.nii"

# Output files
t1_output="$folder_path/${SUBJECT}_T1_iso1mm.nii.gz"
t2_output="$folder_path/${SUBJECT}_T2_iso1mm.nii.gz"

echo
echo "=== Step 4: Resampling images for subject ${SUBJECT} ==="
echo "Subject folder: $folder_path"
echo

###############################################################
# Step 0: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Step 4 already completed earlier (flag found: $DONE_FLAG)"

    if [ -f "$t1_output" ]; then
        echo "    T1_iso1mm exists: $t1_output"
        if [ -f "$t2_input" ] && [ -f "$t2_output" ]; then
            echo "    T2_iso1mm exists and T2 is present: $t2_output"
        fi
        echo "    Skipping Step 4."
        echo
        exit 0
    else
        echo "    Warning: completion flag exists but $t1_output is missing."
        echo "    Re-running Step 4 to regenerate outputs."
        echo
    fi
fi

###############################################################
# Step 1: Resample T1 (required)
###############################################################
if [ ! -f "$t1_input" ]; then
    echo "ERROR: Required T1 file not found at:"
    echo "  $t1_input"
    echo "Make sure Step 2 created ${SUBJECT}_T1.nii."
    exit 1
fi

echo "### Resampling T1 (${t1_input}) to 1 mm isotropic ###"
flirt -in "$t1_input" -ref "$t1_input" -applyisoxfm 1.0 -nosearch -out "$t1_output"

if [ ! -f "$t1_output" ]; then
    echo "Error: T1 resampling failed — no output created."
    exit 1
fi
echo "T1 resampled image created: $t1_output"

###############################################################
# Step 2: Resample T2 (optional)
###############################################################
if [ -f "$t2_input" ]; then
    echo
    echo "### Resampling T2 (${t2_input}) to 1 mm isotropic ###"
    flirt -in "$t2_input" -ref "$t2_input" -applyisoxfm 1.0 -nosearch -out "$t2_output"

    if [ ! -f "$t2_output" ]; then
        echo "Warning: T2 resampling failed — continuing without T2."
    else
        echo "T2 resampled image created: $t2_output"
    fi
else
    echo
    echo "### No T2 file found — skipping T2 resampling. ###"
fi

###############################################################
# Step 3: Move originals to MR-cache
###############################################################
echo
echo "### Moving original files to MR-cache ###"
mkdir -p "$mrcache_path"

# Always move T1
if [ -f "$t1_input" ]; then
    mv "$t1_input" "$mrcache_path/" && echo "Moved original T1 → MR-cache"
fi

# Move T2 only if it exists
if [ -f "$t2_input" ]; then
    mv "$t2_input" "$mrcache_path/" && echo "Moved original T2 → MR-cache"
fi

###############################################################
# Step 4: Mark completion
###############################################################
touch "$DONE_FLAG"

echo
echo "### Step 4 completed for subject ${SUBJECT}. ###"
echo "Completion flag written to: $DONE_FLAG"
echo
