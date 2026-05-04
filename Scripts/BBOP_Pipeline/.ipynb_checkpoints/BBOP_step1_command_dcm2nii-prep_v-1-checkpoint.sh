#!/bin/bash

# Step 1: DICOM → NIFTI prep, folder setup, and Brainsight templates
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]
#
# Example:
#   TUSMR_BBOP_step1_command_dcm2nii-prep.sh \
#       /path/to/TUSMR2025 \
#       KC-PILOT \
#       caudate_da_rh mfg5_internal_v3

set -euo pipefail

###############################################################
# Step 0: Parse arguments
###############################################################

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

# Any additional arguments are treated as ROI labels
shift 2
ROIS=( "$@" )

# Define dynamic paths based on BASE_DIR and subject
SOURCE="$BASE_DIR/Raw-Data/Subjects/sMRI/$SUBJECT"
DEST="$BASE_DIR/Analysis/Zapping/$SUBJECT"
DONE_FLAG="$DEST/.BBOP_step1_done"

###############################################################
# Step A: Basic checks and destination folder setup
###############################################################

if [ ! -d "$SOURCE" ]; then
    echo "Error: Source directory $SOURCE does not exist!"
    exit 1
fi

echo "Creating destination directory (if needed): $DEST"
mkdir -p "$DEST"

echo "Creating core subfolders in $DEST..."
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
    echo "Ensuring Babelbrain ROI subfolders exist for: ${ROIS[*]}"
    for ROI in "${ROIS[@]}"; do
        ROI_DIR="$DEST/Babelbrain/${ROI}"
        mkdir -p \
          "$ROI_DIR/input" \
          "$ROI_DIR/sim_baseline" \
          "$ROI_DIR/sim_scaled"
    done
else
    echo "No ROIs specified. Skipping creation of ROI-specific Babelbrain folders."
fi

###############################################################
# Step C: Skip heavy work if Step 1 is already completed
###############################################################

if [ -f "$DONE_FLAG" ]; then
    echo
    echo ">>> Detected completion flag for Step 1:"
    echo "    $DONE_FLAG"
    echo "    Assuming DICOM copy, dcm2niix, and Brainsight templates"
    echo "    have already been successfully created."
    echo "    ROI folders were refreshed above if new ROIs were given."
    echo ">>> Skipping DICOM→NIFTI conversion and template work."
    echo
    exit 0
fi

###############################################################
# Step D: Copy DICOM (.IMA) files into DICOM folder
###############################################################

echo "Copying .IMA files from $SOURCE to $DEST/DICOM..."
find "$SOURCE" -type f -iname "*.IMA" -exec cp {} "$DEST/DICOM/" \;

# Verify that files were copied
if [ ! "$(ls -A "$DEST/DICOM")" ]; then
    echo "Error: No .IMA files found in the source directory $SOURCE!"
    exit 1
fi

###############################################################
# Step E: Convert DICOM → NIFTI with dcm2niix
###############################################################

echo "Running dcm2niix..."
dcm2niix -o "$DEST/NIFTI" "$DEST/DICOM"

###############################################################
# Step F: Copy Brainsight template files and rename
###############################################################

echo "Copying template files to Brainsight folder..."
TEMPLATE_DIR="$BASE_DIR/../Main/Templates"
TARGET_LOG="$DEST/Brainsight/${SUBJECT}_LIFUScog_TargetingLog.csv"
SESSION_LOG="$DEST/Brainsight/${SUBJECT}_LIFUScog_SessionLog.txt"

cp "$TEMPLATE_DIR/LIFUScog_TargetingLog_Template.csv" "$TARGET_LOG"
cp "$TEMPLATE_DIR/LIFUScog_SessionLog_Template.txt"   "$SESSION_LOG"

###############################################################
# Step G: Replace placeholders in template files
###############################################################

echo "Modifying template files with subject ID..."
sed -i "s/<SUBJECT>/${SUBJECT}/g" "$TARGET_LOG"
sed -i "s/<SUBJECT>/${SUBJECT}/g" "$SESSION_LOG"

###############################################################
# Step H: Mark step as completed
###############################################################

touch "$DONE_FLAG"
echo "Created completion flag: $DONE_FLAG"

echo
echo "All Step 1 operations completed successfully for subject $SUBJECT!"
echo
