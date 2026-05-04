#!/bin/bash

# BBOP preprocessing pipeline (steps 1–7).
# Normally called via BBOP_pipeline_preproc_RUN-command.sh
#
# Usage (advanced):
#   ./BBOP_pipeline_preproc.sh \
#       <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--with-pCT|--without-pCT]


if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--with-pCT|--without-pCT]"
  exit 1
fi

BASE_DIR="$1"
subject="$2"
shift 2

# Default: do NOT run pCT step inside the pipeline
PCT_MODE="without"

# Collect ROI labels from positional args (anything that is not a --flag)
ROIS=()
for arg in "$@"; do
  case "$arg" in
    --with-pCT)
      PCT_MODE="with"
      ;;
    --without-pCT)
      PCT_MODE="without"
      ;;
    *)
      # treat as ROI label
      ROIS+=("$arg")
      ;;
  esac
done

echo
echo "=== BBOP preprocessing pipeline ==="
echo "Subject:   $subject"
echo "BASE_DIR:  $BASE_DIR"
echo "ROIs:      ${ROIS[*]:-(none)}"
echo "pCT mode:  $PCT_MODE"
echo

# --- Logging setup -----------------------------------------------------------

# Central log CSV
log_file="${BASE_DIR}/Analysis/Pipeline-Log/BBOP_Pipeline_Log.csv"
log_dir="${BASE_DIR}/Analysis/Pipeline-Log/Log-Files"

mkdir -p "$log_dir"

# Create central CSV with header if missing
if [ ! -f "$log_file" ]; then
  echo "subject,step,status,timestamp" > "$log_file"
fi

# Subject-specific log file
date_str=$(date '+%Y-%m-%d_%H-%M-%S')
subject_log_file="${log_dir}/BBOP_${subject}_LogFile_${date_str}.txt"

# Log all terminal output to subject-specific log file
exec > >(tee -a "$subject_log_file") 2>&1

log_step() {
    local subject="$1"
    local step="$2"
    local status="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$subject,$step,$status,$timestamp" >> "$log_file"
}

# Helper to run a step script
run_step() {
    local step_name="$1"
    local script_path="$2"
    shift 2

    echo
    echo "### Starting ${step_name} ###"
    echo

    local t_start t_end duration
    t_start=$(date +%s)

    log_step "$subject" "$step_name" "started"

    if [ ! -x "$script_path" ]; then
      echo "Making step script executable: $script_path"
      chmod +x "$script_path"
    fi

    # All step scripts take: BASE_DIR SUBJECT [extra args...]
    "$script_path" "$BASE_DIR" "$subject" "$@"
    local exit_code=$?

    t_end=$(date +%s)
    duration=$(( t_end - t_start ))

    if [ $exit_code -eq 0 ]; then
        log_step "$subject" "$step_name" "completed"
        echo
        echo "### ${step_name} completed successfully in ${duration}s. ###"
        echo
    else
        log_step "$subject" "$step_name" "failed"
        echo
        echo "### ${step_name} failed with exit code $exit_code after ${duration}s. ###"
        echo
        exit 1
    fi
}

# --- Run preprocessing steps -------------------------------------------------

# Step 1: DICOM → NIFTI, folder setup, Babelbrain ROI folders
run_step "Step 1 dcm2nii-prep" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step1_command_dcm2nii-prep.sh" \
  "${ROIS[@]}"

# Step 2: NIFTI prep (identify T1/T2/PETRA, move DICOM/NIFTI into MR-cache)
run_step "Step 2 nii-prep" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step2_command_nii-prep.sh"

# Step 3: Targeting – MNI->T1 coords + ROI masks (BabelBrain-style, using YAML)
run_step "Step 3 targeting-dynamic" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step3_command_targeting_dynamic.sh" \
  "${ROIS[@]}"

# Step 4: Resample T1/T2 to 1mm isotropic
run_step "Step 4 resample-iso1mm" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step4_command_resample-isotropic.sh"

# Step 5: Coregister T2_iso1mm → T1_iso1mm (ANTS) + save FSL affine
run_step "Step 5 T1-T2-coreg" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step5_command_T1-T2_coreg_ANTS.sh"

# Step 6: QC – T1/T2 difference image in QC folder
run_step "Step 6 T1-T2-QC" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step6_command_T1-T2_coreg_QC.sh"

# Step 7: PETRA → pCT (optional)
if [ "$PCT_MODE" = "with" ]; then
  run_step "Step 7 pCT" \
    "${BASE_DIR}/Scripts/BBOP_Pipeline/preprocessing/BBOP_step7_command_create-pCT.sh"
else
  echo
  echo "### Skipping Step 7 (pCT) because pCT mode is '--without-pCT'. ###"
  log_step "$subject" "Step 7 pCT" "skipped"
  echo
fi

# Final message
log_step "$subject" "preproc-Pipeline" "completed"
echo "BBOP preprocessing pipeline completed successfully for subject $subject."
