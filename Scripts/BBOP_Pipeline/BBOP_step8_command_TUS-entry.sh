#!/bin/bash

# ===========================================================
# Step 8: TUS-entry (optimal transducer position) – multi ROI
# ===========================================================

set -euo pipefail

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <BASE_DIR> <SUBJECT> ROI1 [ROI2 ...] [flags]"
  exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"
shift 2

###############################################################
# Optional: read pipeline version if available
###############################################################
PIPELINE_VERSION_FILE="$(dirname "$0")/BBOP_version.sh"
if [ -f "$PIPELINE_VERSION_FILE" ]; then
  source "$PIPELINE_VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

###############################################################
# Defaults
###############################################################
TUSENTRY_DIR_CLI=""
DEFAULT_MIN_CM="0.5"
DEFAULT_MAX_CM="8.0"
GLOBAL_MIN_CM=""
GLOBAL_MAX_CM=""
DO_TRAJECTORY=false
ROIS=()

###############################################################
# Step 1: Parse ROIs + flags
###############################################################
while [ "$#" -gt 0 ]; do
  case "$1" in
    --tusentry-dir) shift; TUSENTRY_DIR_CLI="$1"; shift ;;
    --min-cm)       shift; GLOBAL_MIN_CM="$1"; shift ;;
    --max-cm)       shift; GLOBAL_MAX_CM="$1"; shift ;;
    --trajectory)   DO_TRAJECTORY=true; shift ;;
    --help|-h)
      echo "Usage: $0 <BASE_DIR> <SUBJECT> ROI1 [ROI2 ...] [flags]"
      exit 0 ;;
    --*) echo "Error: Unknown flag: $1"; exit 1 ;;
    *) ROIS+=("$1"); shift ;;
  esac
done

MIN_CM="${GLOBAL_MIN_CM:-$DEFAULT_MIN_CM}"
MAX_CM="${GLOBAL_MAX_CM:-$DEFAULT_MAX_CM}"

###############################################################
# Step 2: Sanity checks
###############################################################
if [ "${#ROIS[@]}" -eq 0 ]; then
  echo "No ROIs provided. Nothing to do."
  exit 0
fi

for cmd in flirt fslmaths fslstats Rscript; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: '$cmd' not found in PATH."
    exit 1
  }
done

###############################################################
# Step 3: Locate TUS_entry
###############################################################
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
TUS_ENTRY_DIR="${TUSENTRY_DIR_CLI:-${TUS_ENTRY_DIR:-${BASE_DIR}/Tools/TUS_entry}}"
TUS_ENTRY_R="$TUS_ENTRY_DIR/TUS_entry.R"
TUS_TRAJECTORY_R="$TUS_ENTRY_DIR/TUS_trajectory.R"

if [ ! -f "$TUS_ENTRY_R" ]; then
  echo "Error: TUS_entry.R not found at:"
  echo "  $TUS_ENTRY_R"
  exit 1
fi

if [ ! -f "$TUS_TRAJECTORY_R" ]; then
  echo "Error: TUS_trajectory.R not found at:"
  echo "  $TUS_TRAJECTORY_R"
  exit 1
fi

###############################################################
# Step 4: Subject paths
###############################################################
DEST="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"
M2M="$DEST/m2m_${SUBJECT}"
T1="$M2M/T1.nii.gz"
FINAL_TISSUES="$M2M/final_tissues.nii.gz"
HEADMASK="$M2M/headmask_for_TUSentry.nii.gz"

###############################################################
# Header
###############################################################
echo
echo "=== Step 8: TUS-entry for subject ${SUBJECT} ==="
echo "BBOP version:      $BBOP_VERSION"
echo "ROIs:              ${ROIS[*]}"
echo "Trajectory export: $DO_TRAJECTORY"
echo "Distance range:    ${MIN_CM}–${MAX_CM} cm"
echo

###############################################################
# Prepare headmask (once)
###############################################################
if [ ! -f "$HEADMASK" ]; then
  echo "Preparing headmask for TUS-entry..."
  fslmaths "$FINAL_TISSUES" -thr 0.5 -bin "$HEADMASK"
fi

###############################################################
# Step 5: Per-ROI processing
###############################################################
for ROI in "${ROIS[@]}"; do
  echo
  echo "=== ROI: $ROI ==="

  ROI_INPUT="$DEST/Babelbrain/$ROI/input"
  mkdir -p "$ROI_INPUT"

  TGT1="$ROI_INPUT/${SUBJECT}_${ROI}_mask_fromcoords_T1space.nii.gz"
  TGT2="$ROI_INPUT/${SUBJECT}_${ROI}_mask_T1space.nii.gz"
  [ -f "$TGT1" ] && TGT="$TGT1" || TGT="$TGT2"

  if [ ! -f "$TGT" ]; then
    echo "No target mask found — skipping ROI."
    continue
  fi

  OUT_NEURONAV="$ROI_INPUT/${SUBJECT}_${ROI}_TUSentry_neuronav.nii.gz"
  OUT_VALID="$ROI_INPUT/${SUBJECT}_${ROI}_TUSentry_validation.nii.gz"
  OUT_REPORT="$ROI_INPUT/${SUBJECT}_${ROI}_TUSentry_report.txt"
  OUT_TRAJ="$ROI_INPUT/${SUBJECT}_${ROI}_TUSentry_trajectory.txt"
  DONE_FLAG="$ROI_INPUT/.BBOP_step8_TUSentry_done"

  #############################################################
  # Skip logic (STRICT)
  #############################################################
  if [ -f "$DONE_FLAG" ] &&
     [ -f "$OUT_NEURONAV" ] &&
     [ -f "$OUT_VALID" ] &&
     [ -f "$OUT_REPORT" ] &&
     { [ "$DO_TRAJECTORY" = false ] || [ -f "$OUT_TRAJ" ]; }; then
    echo "ROI already completed — skipping."
    continue
  fi

  #############################################################
  # Resample target + headmask to T1 grid
  #############################################################
  TGT_T1="$ROI_INPUT/${SUBJECT}_${ROI}_target_T1grid.nii.gz"
  HEAD_T1="$ROI_INPUT/${SUBJECT}_${ROI}_headmask_T1grid.nii.gz"

  flirt -in "$TGT" -ref "$T1" -applyxfm -usesqform -interp nearestneighbour -out "$TGT_T1"
  fslmaths "$TGT_T1" -bin "$TGT_T1"

  flirt -in "$HEADMASK" -ref "$T1" -applyxfm -usesqform -interp nearestneighbour -out "$HEAD_T1"
  fslmaths "$HEAD_T1" -bin "$HEAD_T1"

  #############################################################
  # Run TUS-entry (R)
  #############################################################
  echo "Running TUS-entry (this may take several minutes)..."

    if [ "$DO_TRAJECTORY" = true ]; then
      R_DO_TRAJECTORY="TRUE"
    else
      R_DO_TRAJECTORY="FALSE"
    fi

Rscript --vanilla - <<RSCRIPT
library(oro.nifti)
source("$TUS_ENTRY_R")
source("$TUS_TRAJECTORY_R")

DO_TRAJ <- $R_DO_TRAJECTORY

target <- readNIfTI("$TGT_T1", reorient = FALSE)
scalp  <- readNIfTI("$HEAD_T1", reorient = FALSE)
t1img  <- readNIfTI("$T1", reorient = FALSE)

res <- TUS_entry(
  target,
  scalp,
  t1img,
  minimal_distance = as.numeric("$MIN_CM"),
  maximal_distance = as.numeric("$MAX_CM"),
  output = "TEXT",
  visual_confirm = FALSE
)

writeNIfTI(res\$MRI_Final_neuronav,
           sub("\\\\.nii\\\\.gz$", "", "$OUT_NEURONAV"),
           gzipped = TRUE)

writeNIfTI(res\$MRI_Final_validation,
           sub("\\\\.nii\\\\.gz$", "", "$OUT_VALID"),
           gzipped = TRUE)

sink("$OUT_REPORT")
cat(res\$report)
sink()

stopifnot(
  inherits(target, "nifti"),
  inherits(res\$MRI_Final_neuronav, "nifti")
)

if (DO_TRAJ) {

  traj_txt <- capture.output(
    TUS_trajectory(
      target     = target,
      transducer = res\$MRI_Final_neuronav
    )
  )

  writeLines(traj_txt, "$OUT_TRAJ")
}
RSCRIPT

  #############################################################
  # DONE flag only if outputs exist
  #############################################################
  if [ -f "$OUT_NEURONAV" ] &&
     [ -f "$OUT_VALID" ] &&
     [ -f "$OUT_REPORT" ] &&
     { [ "$DO_TRAJECTORY" = false ] || [ -f "$OUT_TRAJ" ]; }; then
    touch "$DONE_FLAG"
    echo "ROI completed successfully — DONE flag written."
  else
    echo "WARNING: ROI outputs incomplete — DONE flag NOT written."
  fi
done

echo
echo "=== Step 8 completed for subject $SUBJECT ==="
echo
