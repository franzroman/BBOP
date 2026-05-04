#!/bin/bash

# Step 7: Create pseudo-CT (pCT) from PETRA using the UCL petra-to-ct toolbox.
#
# Responsibilities:
#   - Take ${SUBJECT}_PETRA.nii in the subject folder
#   - Call MATLAB: petraToCT.convert('${SUBJECT}_PETRA.nii')
#   - Copy/rename the resulting pCT to ${SUBJECT}_pCT.nii in the subject folder
#   - Move the original PETRA into the subject's Babelbrain folder
#   - Do NOT move PETRA or pCT into MR-cache
#
# Usage: $0 <BASE_DIR> <SUBJECT>
#
# Example:
#
#    cd /Volumes/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025/Scripts/BBOP_Pipeline/preprocessing
#    chmod +x TUSMR_BBOP_step7_command_create-pCT_local.sh
#
#    export PETRA2CT_DIR="$HOME/matlab/petra-to-ct"   # or wherever +petraToCT lives 
#    which matlab                                     # check matlab is on PATH
#    matlab -batch "disp('MATLAB is working'); exit;"
#
#   ./TUSMR_BBOP_step7_command_create-pCT_local.sh \
#       /Volumes/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
#       KC-PILOT
#
# Notes:
#   - This step is OPTIONAL. It can be run on a different machine
#     (e.g., your local Mac) as long as BASE_DIR points to the same
#     project directory structure.
#
# Requirements:
#   - MATLAB on PATH
#   - UCL petra-to-ct toolbox installed (https://github.com/ucl-bug/petra-to-ct)
#   - Environment variable PETRA2CT_DIR pointing to the toolbox root
#       (directory containing the +petraToCT folder)

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

echo "=== Step 7: Create pseudo-CT for subject ${SUBJECT} ==="

# Sanity checks
if [ ! -d "$DEST" ]; then
    echo "Error: Subject directory not found: $DEST"
    exit 1
fi

if [ ! -f "$PETRA_IN" ]; then
    echo "Error: PETRA file not found at $PETRA_IN"
    echo "Make sure Step 2 has created ${SUBJECT}_PETRA.nii in the subject folder."
    exit 1
fi

if ! command -v matlab >/dev/null 2>&1; then
    echo "Error: MATLAB not found in PATH. Please load or install MATLAB."
    exit 1
fi

if [ -z "${PETRA2CT_DIR:-}" ]; then
    echo "Error: PETRA2CT_DIR environment variable not set."
    echo "Please set PETRA2CT_DIR to the path of the petra-to-ct toolbox (directory containing +petraToCT)."
    exit 1
fi

mkdir -p "$BABELBRAIN_DIR"

echo "Subject directory:   $DEST"
echo "PETRA input file:    $PETRA_IN"
echo "Pseudo-CT output:    $PCT_OUT"
echo "Babelbrain folder:   $BABELBRAIN_DIR"
echo "petra-to-ct toolbox: $PETRA2CT_DIR"
echo

###########################################################
# 1) Run PETRA -> pseudo-CT conversion via MATLAB
###########################################################

# petraToCT.convert('image.nii') will create a 'PetraToCT' subfolder
# in the same directory as the input with (among others) 'pCT.nii'.

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
    echo "Error: Expected pseudo-CT file not found at $PCT_SRC"
    echo "Check MATLAB output and petra-to-ct configuration."
    exit 1
fi

###########################################################
# 2) Copy/rename pCT to subject root
###########################################################

echo "Copying pseudo-CT to $PCT_OUT ..."
cp "$PCT_SRC" "$PCT_OUT"

if [ ! -f "$PCT_OUT" ]; then
    echo "Error: Failed to create $PCT_OUT"
    exit 1
fi

echo "Pseudo-CT successfully created at $PCT_OUT"

###########################################################
# 3) Move PETRA into Babelbrain folder
###########################################################

PETRA_DEST="$BABELBRAIN_DIR/${SUBJECT}_PETRA.nii"

echo "Moving original PETRA to Babelbrain folder..."
mv "$PETRA_IN" "$PETRA_DEST"

if [ -f "$PETRA_DEST" ]; then
    echo "PETRA moved to: $PETRA_DEST"
else
    echo "Error: Failed to move PETRA to Babelbrain folder."
    exit 1
fi

echo
echo "Step 7 completed successfully for subject $SUBJECT."
echo "  - pCT stays in subject folder: $PCT_OUT"
echo "  - PETRA now in Babelbrain folder: $PETRA_DEST"
