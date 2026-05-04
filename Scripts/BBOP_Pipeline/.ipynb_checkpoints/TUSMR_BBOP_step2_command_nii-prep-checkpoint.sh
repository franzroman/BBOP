#!/bin/bash

# ===========================================================
# Step 2: NIFTI prep and MR-cache organization
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT>
#
# Responsibilities:
#   - (Optionally) perform NIFTI renaming/organization
#   - Identify T1, T2, PETRA from NIFTI folder
#   - Copy them to subject root as:
#         SUBJECT_T1.nii
#         SUBJECT_T2.nii        (if exists)
#         SUBJECT_PETRA.nii     (if exists)
#   - Move DICOM/ and NIFTI/ into MR-cache/
#   - Create a completion flag so reruns skip gracefully
# ===========================================================

set -euo pipefail

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

DEST="$BASE_DIR/Analysis/Zapping/$SUBJECT"
DONE_FLAG="$DEST/.BBOP_step2_done"

echo
echo "=== Step 2: NIFTI prep for subject $SUBJECT ==="
echo "Destination folder: $DEST"
echo

###############################################################
# Step 1: Skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Detected completion flag for Step 2:"
    echo "    $DONE_FLAG"
    echo "    Assuming T1/T2/PETRA copies and MR-cache organization"
    echo "    were already done successfully."
    echo ">>> Skipping Step 2."
    echo
    exit 0
fi

###############################################################
# Step 2: Basic sanity checks
###############################################################
if [ ! -d "$DEST" ]; then
    echo "Error: Destination folder does not exist: $DEST"
    echo "Make sure Step 1 has been run."
    exit 1
fi

###############################################################
# Step 3: NIFTI renaming / organization (placeholder)
###############################################################
echo "Starting NIFTI file renaming and organization for subject $SUBJECT in $DEST..."
echo "Performing file renaming and organization..."
# (Any additional renaming commands can be added here)
echo "NIFTI file renaming and organization completed for subject $SUBJECT."
echo

###############################################################
# Step 4: Identify and copy T1, T2, PETRA to subject root
###############################################################
if [ -d "$DEST/NIFTI" ]; then
    # ---------- T1 ----------
    T1FILE=$(ls "$DEST/NIFTI"/*[Tt]1*.nii* 2>/dev/null | head -n 1 || true)
    if [ -n "${T1FILE:-}" ]; then
        echo "Found T1 file: $T1FILE"
        echo "Copying to subject folder as ${SUBJECT}_T1.nii..."
        if [[ "$T1FILE" == *.nii.gz ]]; then
            gunzip -c "$T1FILE" > "$DEST/${SUBJECT}_T1.nii"
        else
            cp "$T1FILE" "$DEST/${SUBJECT}_T1.nii"
        fi
    else
        echo "Warning: No T1 file found in $DEST/NIFTI."
    fi

    # ---------- T2 ----------
    T2FILE=$(ls "$DEST/NIFTI"/*[Tt]2*.nii* 2>/dev/null | head -n 1 || true)
    if [ -n "${T2FILE:-}" ]; then
        echo
        echo "Found T2 file: $T2FILE"
        echo "Copying to subject folder as ${SUBJECT}_T2.nii..."
        if [[ "$T2FILE" == *.nii.gz ]]; then
            gunzip -c "$T2FILE" > "$DEST/${SUBJECT}_T2.nii"
        else
            cp "$T2FILE" "$DEST/${SUBJECT}_T2.nii"
        fi
    else
        echo
        echo "Warning: No T2 file found in $DEST/NIFTI."
    fi

    # ---------- PETRA ----------
    PETRAFILE=$(ls "$DEST/NIFTI"/*[Pp][Ee][Tt][Rr][Aa]*.nii* 2>/dev/null | head -n 1 || true)
    if [ -n "${PETRAFILE:-}" ]; then
        echo
        echo "Found PETRA file: $PETRAFILE"
        echo "Copying to subject folder as ${SUBJECT}_PETRA.nii..."
        if [[ "$PETRAFILE" == *.nii.gz ]]; then
            gunzip -c "$PETRAFILE" > "$DEST/${SUBJECT}_PETRA.nii"
        else
            cp "$PETRAFILE" "$DEST/${SUBJECT}_PETRA.nii"
        fi
    else
        echo
        echo "Warning: No PETRA file found in $DEST/NIFTI."
    fi
else
    echo "Warning: NIFTI folder does not exist in $DEST. Skipping T1/T2/PETRA detection."
fi

###############################################################
# Step 5: Move DICOM and NIFTI into MR-cache (idempotent)
###############################################################
echo
echo "Moving DICOM and NIFTI folders to MR-cache folder..."
mkdir -p "$DEST/MR-cache"

# ---------- DICOM ----------
if [ -d "$DEST/DICOM" ]; then
    if [ -d "$DEST/MR-cache/DICOM" ]; then
        echo "  MR-cache/DICOM already exists – removing old copy before move."
        rm -rf "$DEST/MR-cache/DICOM"
    fi
    mv "$DEST/DICOM" "$DEST/MR-cache/" && \
        echo "  Moved DICOM folder successfully." || {
        echo "  Error moving DICOM folder."
        exit 1
    }
else
    echo "  Warning: DICOM folder does not exist in $DEST."
fi

# ---------- NIFTI ----------
if [ -d "$DEST/NIFTI" ]; then
    if [ -d "$DEST/MR-cache/NIFTI" ]; then
        echo "  MR-cache/NIFTI already exists – removing old copy before move."
        rm -rf "$DEST/MR-cache/NIFTI"
    fi
    mv "$DEST/NIFTI" "$DEST/MR-cache/" && \
        echo "  Moved NIFTI folder successfully." || {
        echo "  Error moving NIFTI folder."
        exit 1
    }
else
    echo "  Warning: NIFTI folder does not exist in $DEST."
fi

###############################################################
# Step 6: Mark step as completed
###############################################################
touch "$DONE_FLAG"
echo
echo "Created completion flag for Step 2: $DONE_FLAG"
echo "All Step 2 operations completed successfully for subject $SUBJECT."
echo
