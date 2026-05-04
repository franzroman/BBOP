#!/bin/bash
set -euo pipefail

# ===========================================================
# Step 1: Raw DICOM → NIFTI curation + Analysis folder setup
#
# Responsibilities:
#   - Run dcm2niix in RAW BIDS anat folder (if needed)
#   - Create analysis subject folder + substructure
#   - Create ROI-specific Babelbrain folders
#
# Does NOT:
#   - Copy DICOMs
#   - Copy NIFTIs
#
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

SOURCE="$BASE_DIR/Raw-Data/Subjects/$SUBJECT/ses-01/anat"
DEST="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"
DONE_FLAG="$DEST/.BBOP_step1_done"

# Optional: read pipeline version if available
PIPELINE_VERSION_FILE="$(dirname "$0")/BBOP_version.sh"
if [ -f "$PIPELINE_VERSION_FILE" ]; then
  source "$PIPELINE_VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

echo
echo "=== BBOP Step 1: NIFTI preparation ==="
echo "Subject:        $SUBJECT"
echo "BBOP version:   $BBOP_VERSION"
echo "RAW anat:       $SOURCE"
echo "DEST:           $DEST"
echo

###############################################################
# Step A: Basic checks
###############################################################
if [ ! -d "$SOURCE" ]; then
    echo "Error: Source directory does not exist: $SOURCE"
    exit 1
fi

# Skip conversion if already completed
if [ -f "$DONE_FLAG" ]; then
    echo
    echo ">>> Detected completion flag for Step 1:"
    echo "    $DONE_FLAG"
    echo ">>> Skipping Step 1 (already completed)."
    echo
    exit 0
fi

command -v dcm2niix >/dev/null 2>&1 || {
  echo "Error: dcm2niix not found in PATH. Please install dcm2niix and try again."
  exit 1
}
echo "dcm2niix:       $(dcm2niix -v | head -n 1)"

###############################################################
# Step B: Create Analysis folder structure
###############################################################
echo "Creating destination directory (if needed): $DEST"
mkdir -p "$DEST"

echo "Creating core BBOP analysis subfolders..."
mkdir -p \
  "$DEST/MR-cache" \
  "$DEST/Babelbrain" \
  "$DEST/Brainsight" \
  "$DEST/QC"

###############################################################
# Step C: Create / update ROI-specific Babelbrain folders
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
# Step D: DICOM → NIFTI conversion in SOURCE (raw)
###############################################################
echo "Checking raw input in SOURCE: $SOURCE"

# NIfTI check (in SOURCE root, because that's where we output)
n_src_nifti=$(find "$SOURCE" -maxdepth 1 -type f \( -name "*.nii" -o -name "*.nii.gz" \) | wc -l | tr -d ' ')

if [ "$n_src_nifti" -gt 0 ]; then
    echo "NIFTIs already present in SOURCE — skipping dcm2niix."
else
    # Any file at all inside SOURCE (recursively)?
    n_any_files=$(find "$SOURCE" -type f | wc -l | tr -d ' ')

    n_dicom_like=$(find "$SOURCE" -type f \( -iname "*.ima" -o -iname "*.dcm" -o -iname "*.dicom" \) | wc -l | tr -d ' ')
    echo "Found $n_dicom_like files with common DICOM extensions (.IMA/.dcm/.dicom) (informational only)."

    if [ "$n_any_files" -lt 1 ]; then
        echo "Error: No files found in SOURCE to convert: $SOURCE"
        exit 1
    fi

    echo "No NIFTIs found. Attempting dcm2niix conversion..."
    dcm2niix -z y -w 0 -f "%p_%s" -o "$SOURCE" "$SOURCE"
fi

# Final sanity check (NIFTI required, JSON optional)
n_src_nifti=$(find "$SOURCE" -maxdepth 1 -type f \( -name "*.nii" -o -name "*.nii.gz" \) | wc -l | tr -d ' ')
n_json=$(find "$SOURCE" -maxdepth 1 -type f -name "*.json" | wc -l | tr -d ' ')

echo "Detected $n_src_nifti NIFTI file(s) in SOURCE."

if [ "$n_src_nifti" -lt 1 ]; then
    echo "Error: No NIFTI files found in SOURCE after conversion."
    exit 1
fi

if [ "$n_json" -lt 1 ]; then
    echo "Warning: No JSON sidecars found in SOURCE."
    echo "         Continuing anyway (legacy or non-BIDS dataset)."
else
    echo "Detected $n_json JSON sidecar(s)."
fi

###############################################################
# Step E: Mark step as completed
###############################################################
touch "$DONE_FLAG"
echo "Created completion flag: $DONE_FLAG"

echo
echo "=== Step 1 completed successfully for subject $SUBJECT ==="
echo
