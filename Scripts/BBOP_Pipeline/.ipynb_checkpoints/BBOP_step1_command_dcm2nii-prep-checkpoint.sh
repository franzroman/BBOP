#!/bin/bash
set -euo pipefail

# ===========================================================
# Step 1: DICOM → NIFTI prep + folder setup (BBOP)
#
# Purpose:
#   - Prepare subject data for Brainsight planning
#   - Prepare subject data for BabelBrain simulations
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]
#
# Example:
#   TUSMR_BBOP_step1_command_dcm2nii-prep.sh \
#       /path/to/TUSMR2025 \
#       KC-PILOT \
#       caudate_da_rh mfg5_internal_v3
# ===========================================================

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"
shift 2
ROIS=( "$@" )

SOURCE="$BASE_DIR/Raw-Data/Subjects/sMRI/$SUBJECT"
DEST="$BASE_DIR/Analysis/Zapping/$SUBJECT"
DONE_FLAG="$DEST/.BBOP_step1_done"

###############################################################
# Step A: Basic checks and destination folder setup
###############################################################
if [ ! -d "$SOURCE" ]; then
    echo "Error: Source directory does not exist: $SOURCE"
    exit 1
fi

echo "Creating destination directory (if needed): $DEST"
mkdir -p "$DEST"

echo "Creating core BBOP subfolders..."
mkdir -p \
  "$DEST/DICOM" \
  "$DEST/NIFTI" \
  "$DEST/MR-cache" \
  "$DEST/Babelbrain" \
  "$DEST/Brainsight" \
  "$DEST/QC"

###############################################################
# Step B: Create / update ROI-specific Babelbrain folders
###############################################################
if [ "${#ROIS[@]}" -gt 0 ]; then
    echo "Ensuring Babelbrain ROI folders exist for: ${ROIS[*]}"
    for ROI in "${ROIS[@]}"; do
        ROI_DIR="$DEST/Babelbrain/${ROI}"
        mkdir -p \
          "$ROI_DIR/input" \
          "$ROI_DIR/simulation"
    done
else
    echo "No ROIs specified. Skipping ROI-specific Babelbrain folders."
fi

###############################################################
# Step C: Skip heavy work if Step 1 already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo
    echo ">>> Detected completion flag for Step 1:"
    echo "    $DONE_FLAG"
    echo ">>> DICOM → NIFTI conversion already done."
    echo ">>> Folder structure updated for new ROIs if provided."
    echo
    exit 0
fi

###############################################################
# Step D: Copy DICOM (.IMA) files
###############################################################
echo "Copying .IMA files from $SOURCE to $DEST/DICOM..."
find "$SOURCE" -type f -iname "*.IMA" -exec cp {} "$DEST/DICOM/" \;

if [ ! "$(ls -A "$DEST/DICOM")" ]; then
    echo "Error: No .IMA files found after copy into $DEST/DICOM"
    exit 1
fi

###############################################################
# Step E: Convert DICOM → NIFTI
###############################################################
echo "Running dcm2niix..."
dcm2niix -z y -o "$DEST/NIFTI" "$DEST/DICOM"

# Safety check
n_nifti=$(find "$DEST/NIFTI" -maxdepth 1 -type f \( -name "*.nii" -o -name "*.nii.gz" \) | wc -l | tr -d ' ')

if [ "$n_nifti" -lt 1 ]; then
    echo "Error: dcm2niix produced no NIFTI files in $DEST/NIFTI"
    echo "Contents of $DEST/NIFTI:"
    ls -lah "$DEST/NIFTI" || true
    exit 1
fi

###############################################################
# Step F: Mark step as completed
###############################################################
touch "$DONE_FLAG"
echo "Created completion flag: $DONE_FLAG"

echo
echo "=== Step 1 completed successfully for subject $SUBJECT ==="
echo
