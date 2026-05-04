#!/bin/bash

# BBOP preprocessing pipeline.
# Normally called via BBOP_pipeline_preproc_RUN-command.sh
#
# Usage (advanced):
#   ./BBOP_pipeline_preproc.sh \
#       <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--with-pCT|--without-pCT]


if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] \
        [--coords|--maskwarp|--coordmask|--all|--none] [--radius-mm R] \
        [--with-pCT|--without-pCT] [--with-TUSentry|--without-TUSentry|--trajectory] \
        [--tusentry-dir PATH] [--min-cm X] [--max-cm Y]"

  exit 1
fi

BASE_DIR="$1"
subject="$2"
shift 2

# --- Pipeline version --------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

VERSION_FILE="${SCRIPT_DIR}/BBOP_version.sh"
if [ -f "$VERSION_FILE" ]; then
  source "$VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

export BBOP_VERSION

# Default: do NOT run pCT step inside the pipeline
PCT_MODE="without"

# Default: do NOT run TUS-entry inside the pipeline
TUSENTRY_MODE="without"
TRAJECTORY_MODE="off"

# Pass-through flags for Step 5 targeting
TARGET_FLAGS=()
TUSENTRY_FLAGS=()
ROIS=()

# Parse remaining args
while [ "$#" -gt 0 ]; do
  case "$1" in
    
    # ---- pCT flags ----
    --with-pCT)
      PCT_MODE="with"
      shift
      ;;
    --without-pCT)
      PCT_MODE="without"
      shift
      ;;

    # ---- Targeting flags (forward to Step 5 targeting) ----
    --coords|--maskwarp|--coordmask|--all|--none)
      TARGET_FLAGS+=("$1")
      shift
      ;;
    --radius-mm)
      # needs a value
      TARGET_FLAGS+=("$1")
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: --radius-mm requires a value"
        exit 1
      fi
      TARGET_FLAGS+=("$1")
      shift
      ;;

    # ---- TUS-entry flags ----
    --with-TUSentry)
      TUSENTRY_MODE="with"
      shift
      ;;
    --without-TUSentry)
      TUSENTRY_MODE="without"
      shift
      ;;
    --trajectory)
      TRAJECTORY_MODE="on"
      TUSENTRY_FLAGS+=("--trajectory")
      shift
      ;;

    # ---- TUS-entry passthrough flags (forward to Step 8) ----
    --tusentry-dir|--min-cm|--max-cm)
      key="$1"
      shift
      if [ "$#" -eq 0 ]; then
        echo "Error: $key requires a value"
        exit 1
      fi
      TUSENTRY_FLAGS+=("$key" "$1")
      shift
      ;;

    --help|-h)
      echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] \
        [--coords|--maskwarp|--coordmask|--all|--none] [--radius-mm R] \
        [--with-pCT|--without-pCT] [--with-TUSentry|--without-TUSentry|--trajectory] \
        [--tusentry-dir PATH] [--min-cm X] [--max-cm Y]"

      exit 0
      ;;
      
    --*)
      echo "Error: Unknown flag: $1"
      exit 1
      ;;

    *)
      ROIS+=("$1")
      shift
      ;;
  esac
done

# ---- sanity check: require min/max as a pair if either is provided ----
has_min=false
has_max=false
for ((i=0; i<${#TUSENTRY_FLAGS[@]}; i++)); do
  if [ "${TUSENTRY_FLAGS[$i]}" = "--min-cm" ]; then has_min=true; fi
  if [ "${TUSENTRY_FLAGS[$i]}" = "--max-cm" ]; then has_max=true; fi
done

if { [ "$has_min" = true ] && [ "$has_max" = false ]; } || \
   { [ "$has_max" = true ] && [ "$has_min" = false ]; }; then
  echo "Error: Please provide both --min-cm and --max-cm (or neither)."
  exit 1
fi

# ---- sanity check: trajectory requires TUS-entry ----
if [ "$TRAJECTORY_MODE" = "on" ] && [ "$TUSENTRY_MODE" != "with" ]; then
  echo "Error: --trajectory requires --with-TUSentry."
  exit 1
fi

# ---- sanity check: reject Step 8 passthrough flags unless --with-TUSentry ----
if [ "$TUSENTRY_MODE" != "with" ] && [ "${#TUSENTRY_FLAGS[@]}" -gt 0 ]; then
  echo "Error: TUS-entry flags were provided but TUS-entry mode is off."
  echo "Add --with-TUSentry or remove: ${TUSENTRY_FLAGS[*]}"
  exit 1
fi

echo
echo "=== BBOP preprocessing pipeline ==="
echo "BBOP version:    $BBOP_VERSION"
echo "Subject:         $subject"
echo "BASE_DIR:        $BASE_DIR"
echo "ROIs:            ${ROIS[*]:-(none)}"
echo "Targeting flags: ${TARGET_FLAGS[*]:-(none)}"
echo "pCT mode:        $PCT_MODE"
echo "TUS-entry mode:  $TUSENTRY_MODE"

if [ "$TUSENTRY_MODE" = "with" ]; then
  echo "TUS-entry flags: ${TUSENTRY_FLAGS[*]:-(none)}"
  echo "Trajectory:      $TRAJECTORY_MODE"
fi

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
log_step() {
    local subject="$1"
    local step="$2"
    local status="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$subject,$step,$status,$timestamp" >> "$log_file"
}

# Log all terminal output to subject-specific log file
exec > >(tee -a "$subject_log_file") 2>&1

# Log pipeline version once
log_step "$subject" "pipeline-version" "v${BBOP_VERSION}"

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

    if [ ! -f "$script_path" ]; then
      echo "ERROR: Step script not found: $script_path"
      log_step "$subject" "$step_name" "failed"
      exit 1
    fi

    if [ ! -x "$script_path" ]; then
      echo "Making step script executable: $script_path"
      chmod +x -- "$script_path"
    fi

    # All step scripts take: BASE_DIR SUBJECT [extra args...]
    set +e
    "$script_path" "$BASE_DIR" "$subject" "$@"
    exit_code=$?
    set -e


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
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step1_command_dcm2nii-prep.sh" \
  "${ROIS[@]}"

# Step 2: NIFTI prep (identify T1/T2/PETRA, move DICOM/NIFTI into MR-cache)
run_step "Step 2 nii-prep" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step2_command_nii-prep.sh"

# Step 3: Resample T1/T2 to 1mm isotropic
run_step "Step 3 resample-iso1mm" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step3_command_resample-isotropic.sh"

# Step 4: SimNIBS
run_step "Step 4 SimNIBS" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step4_command_SimNIBS_dyn.sh"

# Step 5: Targeting – MNI->T1 coords + ROI masks (BabelBrain-style, using YAML)
run_step "Step 5 targeting-dynamic" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step5_command_targeting_dynamic.sh" \
  "${ROIS[@]}" "${TARGET_FLAGS[@]}"

# Step 6: QC – T1/T2 difference image in QC folder
run_step "Step 6 T1-T2-QC" \
  "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step6_command_T1-T2_coreg_QC.sh"

# Step 7: PETRA → pCT (optional)
if [ "$PCT_MODE" = "with" ]; then
  run_step "Step 7 pCT" \
    "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step7_command_create-pCT.sh"
else
  echo
  echo "### Skipping Step 7 pCT because pCT mode is '--without-pCT'. ###"
  log_step "$subject" "Step 7 pCT" "skipped"
  echo
fi

# Step 8: TUS-entry (optional; per ROI)
if [ "$TUSENTRY_MODE" = "with" ]; then
  if [ "${#ROIS[@]}" -eq 0 ]; then
    echo
    echo "### Skipping Step 8 (TUS-entry) because no ROIs were provided. ###"
    log_step "$subject" "Step 8 TUS-entry" "skipped"
    echo
  else
    echo "Running Step 8 with flags: ${TUSENTRY_FLAGS[*]:-(none)}"
    run_step "Step 8 TUS-entry" \
      "${BASE_DIR}/Scripts/BBOP_Pipeline/BBOP_step8_command_TUS-entry.sh" \
      "${ROIS[@]}" "${TUSENTRY_FLAGS[@]}"
  fi
else
  echo
  echo "### Skipping Step 8 (TUS-entry) because TUS-entry mode is '--without-TUSentry'. ###"
  log_step "$subject" "Step 8 TUS-entry" "skipped"
  echo
fi

# Final message
log_step "$subject" "preproc-Pipeline" "completed"
echo "BBOP preprocessing pipeline completed successfully for subject $subject."
