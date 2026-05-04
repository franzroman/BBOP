#!/bin/bash

# ===========================================================
# Step 6: QC — T1/T2 difference image after coregistration
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT>
#
# Inputs:
#   T1.nii.gz                (required)
#   T2_reg.nii.gz          (optional)
#
# Outputs:
#   QC/${SUBJECT}_T2reg_float.nii.gz
#   QC/${SUBJECT}_T1-T2_difference.nii.gz
#   QC/${SUBJECT}_QC_summary.txt
#
# Notes:
#   - If no T2_coreg exists → step skips cleanly.
#   - Idempotent: if outputs + completion flag exist, it will skip.
# ===========================================================

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

# Check required FSL tools are available
for cmd in fslmaths fslhd fslstats; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "Error: '$cmd' not found in PATH. Is FSL loaded?"
        exit 1
    }
done

BASE_DIR="$1"
subject="$2"

folder_path="$BASE_DIR/Analysis/Ultrasound/$subject/m2m_$subject"
DONE_FLAG="$BASE_DIR/Analysis/Ultrasound/$subject/.BBOP_step6_done"

t1_file="$folder_path/T1.nii.gz"
t2_coreg="$folder_path/T2_reg.nii.gz"

qc_dir="$BASE_DIR/Analysis/Ultrasound/$subject/QC"
mkdir -p "$qc_dir"

t2_float="$qc_dir/${subject}_T2reg_float.nii.gz"
temp_diff="$qc_dir/temp_${subject}_T1-T2_difference.nii.gz"
final_diff="$qc_dir/${subject}_T1-T2_difference.nii.gz"
qc_log="$qc_dir/${subject}_QC_summary.txt"

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
echo "=== Step 6: QC — T1/T2 difference for subject ${subject} ==="
echo "BBOP version: $BBOP_VERSION"
echo "QC directory: $qc_dir"
echo "T2 float:     $t2_float"
echo "Temp diff:    $temp_diff"
echo "Final diff:   $final_diff"
echo "QC log:       $qc_log"
echo

###############################################################
# Step 0: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Step 6 already marked as completed (flag: $DONE_FLAG)"

    if [ -f "$t2_float" ] && [ -f "$final_diff" ] && [ -f "$qc_log" ]; then
        echo "    Found existing QC outputs:"
        echo "      - T2 FLOAT: $t2_float"
        echo "      - Difference: $final_diff"
        echo "      - QC log:     $qc_log"
        echo "    Skipping Step 6."
        echo
        exit 0
    else
        echo "    Warning: completion flag exists but expected QC outputs are missing."
        echo "    Re-running Step 6 to regenerate outputs."
        echo
    fi
fi

###############################################################
# Step 1: Check inputs
###############################################################
if [ ! -f "$t1_file" ]; then
    echo "Error: Missing T1: $t1_file"
    exit 1
fi

if [ ! -f "$t2_coreg" ]; then
    echo "No coregistered T2 found — skipping QC step."
    echo "Expected: $t2_coreg"
    touch "$DONE_FLAG"
    echo
    exit 0
fi

echo "Using:"
echo "  T1:        $t1_file"
echo "  T2_coreg:  $t2_coreg"
echo

###############################################################
# Step 2: Convert T2_coreg to FLOAT
###############################################################
echo "Converting T2 coreg → FLOAT…"

fslmaths "$t2_coreg" -mul 1.0 "$t2_float"

if [ ! -f "$t2_float" ]; then
    echo "Error: Failed to create FLOAT T2 at $t2_float"
    exit 1
fi

###############################################################
# Step 3: Create temporary difference image
###############################################################
echo
echo "Computing temporary T1 – T2 difference…"
fslmaths "$t1_file" -sub "$t2_float" "$temp_diff"

if [ ! -f "$temp_diff" ]; then
    echo "Error: Failed to create temporary difference image at $temp_diff"
    exit 1
fi

###############################################################
# Step 4: Log header info for QC
###############################################################
echo "Writing QC header info…"

{
  echo "===== QC summary for $subject ====="
  echo "Generated: $(date)"
  echo
  echo "Inputs:"
  echo "  m2m folder: $folder_path"
  echo "  T1:         $t1_file"
  echo "  T2_reg:     $t2_coreg"
  echo
  echo "Outputs:"
  echo "  T2_float:   $t2_float"
  echo "  Diff:       $final_diff"
  echo
  echo "===== fslhd(temp diff) ====="
  fslhd "$temp_diff"
} > "$qc_log"

echo >> "$qc_log"
echo "===== fslstats summary =====" >> "$qc_log"

echo >> "$qc_log"
echo "T1 stats:" >> "$qc_log"
fslstats "$t1_file" -R -M -S >> "$qc_log"

echo >> "$qc_log"
echo "T2_reg stats:" >> "$qc_log"
fslstats "$t2_float" -R -M -S >> "$qc_log"

echo >> "$qc_log"
echo "T1-T2 difference stats:" >> "$qc_log"
fslstats "$temp_diff" -R -M -S >> "$qc_log"

if [ ! -f "$qc_log" ]; then
    echo "Error: Failed to write QC log at $qc_log"
    exit 1
fi

###############################################################
# Step 5: Finalize difference image
###############################################################
mv -f "$temp_diff" "$final_diff"

echo
echo "Final QC difference saved to:"
echo "  $final_diff"
echo "QC summary written to:"
echo "  $qc_log"

###############################################################
# Step 6: Mark completion
###############################################################
touch "$DONE_FLAG"
echo "Completion flag written to: $DONE_FLAG"

echo
echo "=== Step 6 completed for subject $subject ==="
echo
