#!/bin/bash

# ===========================================================
# Step 7: Create pseudo-CT (pCT) from PETRA using UCL petra-to-ct
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT>
#
# Inputs:
#   ${SUBJECT}_PETRA.nii      (in subject root)
#
# Outputs:
#   ${SUBJECT}_pCT.nii or ${SUBJECT}_pCT.nii.gz
#
# Notes:
#   - Optional step, only used when --with-pCT is passed.
#   - Idempotent: skips if pCT already exists.
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

TOOLS_DIR="$BASE_DIR/Tools"

DEST="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"

# PETRA selection:
# Priority order for now:
#   1) ${SUBJECT}_PETRA_NORM.nii / .nii.gz
#   2) ${SUBJECT}_PETRA_ND.nii / .nii.gz
#   3) ${SUBJECT}_PETRA.nii / .nii.gz
#
# If none are found, skip Step 7 with a warning.
# if --with-pCT is requested but no PETRA exists, Step 7 exits successfully so downstream optional steps can continue.
# If several exist, this priority order decides which one is used.

PETRA_CANDIDATES=(
  "$DEST/${SUBJECT}_PETRA_NORM.nii"
  "$DEST/${SUBJECT}_PETRA_NORM.nii.gz"
  "$DEST/${SUBJECT}_PETRA_ND.nii"
  "$DEST/${SUBJECT}_PETRA_ND.nii.gz"
  "$DEST/${SUBJECT}_PETRA.nii"
  "$DEST/${SUBJECT}_PETRA.nii.gz"
)

PETRA_IN=""
for f in "${PETRA_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then
        PETRA_IN="$f"
        break
    fi
done

PETRA_BASENAME=""
if [ -n "$PETRA_IN" ]; then
    PETRA_BASENAME="$(basename "$PETRA_IN")"
fi

PETRA_MATCHES="$(find "$DEST" -maxdepth 1 -type f \( \
    -name "${SUBJECT}_PETRA*.nii" -o \
    -name "${SUBJECT}_PETRA*.nii.gz" \
  \) | sort || true)"

PETRA_MATCH_COUNT="$(printf "%s\n" "$PETRA_MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')"

if [ "${PETRA_MATCH_COUNT:-0}" -gt 1 ]; then
    echo "Multiple PETRA candidates detected:"
    printf '  %s\n' $PETRA_MATCHES
    echo "Using preferred candidate: $PETRA_IN"
    echo
fi

PCT_OUT=""

SPM_DIR="$TOOLS_DIR/spm25"
NIFTI_TOOLS_DIR="$TOOLS_DIR/matlab_nifti_tools"

DONE_FLAG="$DEST/.BBOP_step7_done"

PCT_OUT_EXISTING="$(ls "$DEST"/${SUBJECT}_pCT.nii "$DEST"/${SUBJECT}_pCT.nii.gz 2>/dev/null | head -n 1 || true)"

###############################################################
# Optional: read pipeline version if available
###############################################################
PIPELINE_VERSION_FILE="$(dirname "$0")/BBOP_version.sh"
if [ -f "$PIPELINE_VERSION_FILE" ]; then
  source "$PIPELINE_VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

echo
echo "=== Step 7: Create pseudo-CT for subject ${SUBJECT} ==="
echo "BBOP version: $BBOP_VERSION"
echo "Subject dir:  $DEST"
echo "PETRA input:  $PETRA_IN"
echo "pCT output:   $DEST/${SUBJECT}_pCT.nii[.gz]"
echo

###############################################################
# Step 1: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ] && [ -n "$PCT_OUT_EXISTING" ] && [ -f "$PCT_OUT_EXISTING" ]; then
    echo ">>> Step 7 already completed."
    echo "    Found existing pCT: $PCT_OUT_EXISTING"
    echo "    Skipping Step 7."
    echo
    exit 0
fi

###############################################################
# Step 2: Sanity checks
###############################################################
if [ ! -d "$DEST" ]; then
    echo "Error: Subject directory not found: $DEST"
    exit 1
fi

if [ -z "$PETRA_IN" ] || [ ! -f "$PETRA_IN" ]; then
    echo "Warning: --with-pCT was requested, but no PETRA file was found."
    echo "Skipping Step 7 pCT generation for subject $SUBJECT."
    echo "Pipeline will continue without pseudo-CT."
    touch "$DONE_FLAG"
    exit 0
fi

if ! command -v matlab >/dev/null 2>&1; then
    echo "Error: MATLAB not found in PATH."
    exit 1
fi

if [ -z "${PETRA2CT_DIR:-}" ]; then
    echo "Error: PETRA2CT_DIR not set."
    exit 1
fi

echo "Subject directory:   $DEST"
echo "PETRA input file:    $PETRA_IN"
echo "Pseudo-CT output:    $DEST/${SUBJECT}_pCT.nii[.gz]"
echo "petra-to-ct toolbox: $PETRA2CT_DIR"
echo

###############################################################
# Step 3: Run MATLAB pCT conversion
###############################################################
MATLAB_CMD="restoredefaultpath; \
p = strsplit(path, pathsep); \
for i = 1:numel(p), if contains(p{i}, 'Tools for NIfTI and ANALYZE image'), rmpath(p{i}); end, end; \
addpath('$SPM_DIR'); \
addpath(genpath('$NIFTI_TOOLS_DIR'), '-begin'); \
addpath(genpath('$PETRA2CT_DIR'), '-begin'); \
cd('$DEST'); \
petraToCT.convert('$PETRA_BASENAME', 'OutputDir', '$DEST/PetraToCT'); \
exit"
echo "MATLAB version:"
matlab -batch "ver; exit"

echo "MATLAB path sanity check (petraToCT):"
matlab -batch "restoredefaultpath; p = strsplit(path, pathsep); for i = 1:numel(p), if contains(p{i}, 'Tools for NIfTI and ANALYZE image'), rmpath(p{i}); end, end; addpath('$SPM_DIR'); addpath(genpath('$NIFTI_TOOLS_DIR'), '-begin'); addpath(genpath('$PETRA2CT_DIR'), '-begin'); which petraToCT.convert; which load_nii; which load_nii_hdr; exit"

echo "Does PETRA input exist from MATLAB's perspective?"
matlab -batch "cd('$DEST'); disp(exist('$PETRA_BASENAME','file')); exit"

echo "Running MATLAB petraToCT.convert ..."

MATLAB_LOG="$DEST/PetraToCT/matlab_step7_${SUBJECT}.log"
mkdir -p "$DEST/PetraToCT"

matlab -batch "$MATLAB_CMD" >"$MATLAB_LOG" 2>&1 || {
  echo "Error: MATLAB failed. Log at: $MATLAB_LOG"
  tail -n 80 "$MATLAB_LOG"
  exit 1
}

###############################################################
# Step 4: Locate pCT output
###############################################################
PETRA2CT_SUBFOLDER="$DEST/PetraToCT"
PCT_SRC="$(ls -1 \
  "$PETRA2CT_SUBFOLDER"/pct.nii \
  "$PETRA2CT_SUBFOLDER"/pct.nii.gz \
  "$PETRA2CT_SUBFOLDER"/pCT.nii \
  "$PETRA2CT_SUBFOLDER"/pCT.nii.gz \
  2>/dev/null | head -n 1 || true)"

if [ -z "$PCT_SRC" ]; then
    echo "Error: pCT output not found in $PETRA2CT_SUBFOLDER"
    echo "Contents:"
    ls -la "$PETRA2CT_SUBFOLDER" || true
    exit 1
fi

if [[ "$PCT_SRC" == *.nii.gz ]]; then
    PCT_OUT="$DEST/${SUBJECT}_pCT.nii.gz"
else
    PCT_OUT="$DEST/${SUBJECT}_pCT.nii"
fi

###############################################################
# Step 5: Copy pCT to subject root
###############################################################
echo "Copying pseudo-CT to subject root:"
echo "  $PCT_OUT"
cp "$PCT_SRC" "$PCT_OUT"

###############################################################
# Step 6: Mark completion
###############################################################
touch "$DONE_FLAG"
echo "Completion flag written to: $DONE_FLAG"

###############################################################
# Final status
###############################################################
echo
echo "Step 7 completed successfully for subject $SUBJECT."
echo "  - pCT:   $PCT_OUT"
echo "  - PETRA: $PETRA_IN"
echo
