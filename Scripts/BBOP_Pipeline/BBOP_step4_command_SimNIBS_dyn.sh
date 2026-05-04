#!/bin/bash
set -euo pipefail

###############################################################
# Step 4: SimNIBS CHARM head model generation
#
# Responsibilities:
#   - Run SimNIBS CHARM using 1 mm isotropic T1 (and optional T2)
#   - Generate m2m_<SUBJECT> folder
#   - Create scalp mask for downstream steps
#
# =============================================================

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [T1_ONLY]"
    exit 1
fi

BASE_DIR="$1"
subject="$2"
shift 2
t1_only=${1:-false}

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
# Step 1: Paths
###############################################################

# --- SimNIBS discovery -------------------------------------------------------
if command -v charm >/dev/null 2>&1; then
  charm_command="$(command -v charm)"
  simnibs_dir="$(cd "$(dirname "$charm_command")/.." && pwd)"
elif [ -n "${SIMNIBS_DIR:-}" ] && [ -x "$SIMNIBS_DIR/bin/charm" ]; then
  simnibs_dir="$SIMNIBS_DIR"
  charm_command="$SIMNIBS_DIR/bin/charm"
else
  echo "ERROR: SimNIBS charm not found."
  echo "Please ensure SimNIBS is installed and 'charm' is in PATH"
  echo "or set SIMNIBS_DIR."
  exit 1
fi

folder_path="$BASE_DIR/Analysis/Ultrasound/$subject"
DONE_FLAG="$folder_path/.BBOP_step4_done"

t1_file="$folder_path/${subject}_T1_iso1mm.nii.gz"
t2_file="$folder_path/${subject}_T2_iso1mm.nii.gz"

mrcache_path="$folder_path/MR-cache"
t1_file_cache="$mrcache_path/${subject}_T1_iso1mm.nii.gz"
t2_file_cache="$mrcache_path/${subject}_T2_iso1mm.nii.gz"

if [ -f "$t1_file" ]; then
  t1_charm_input="$t1_file"
elif [ -f "$t1_file_cache" ]; then
  t1_charm_input="$t1_file_cache"
else
  t1_charm_input=""
fi

if [ -f "$t2_file" ]; then
  t2_charm_input="$t2_file"
elif [ -f "$t2_file_cache" ]; then
  t2_charm_input="$t2_file_cache"
else
  t2_charm_input=""
fi

m2m_dir="$folder_path/m2m_${subject}"

###############################################################
# Header
###############################################################
echo
echo "=== Step 4: SimNIBS CHARM for subject ${subject} ==="
echo "BBOP version: $BBOP_VERSION"
echo "Subject folder: $folder_path"
echo "T1 input:        $t1_charm_input"
if [ -n "$t2_charm_input" ]; then
  echo "T2 input:        $t2_charm_input"
else
  echo "T2 input:        (none)"
fi
echo "Output folder:   $m2m_dir"
echo

###############################################################
# Output formatting helper (keep – not logging system)
###############################################################
section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

###############################################################
# Helper: scalp mask creation
###############################################################
ensure_scalp_mask() {
  local FINAL_TISSUES="$m2m_dir/final_tissues.nii.gz"
  local SCALP_MASK="$m2m_dir/scalp_mask.nii.gz"

  if [ -f "$FINAL_TISSUES" ]; then
    if [ ! -f "$SCALP_MASK" ]; then
      echo "Creating scalp mask from final_tissues (label 5 = scalp): $SCALP_MASK"
      fslmaths "$FINAL_TISSUES" -thr 5 -uthr 5 -bin "$SCALP_MASK"
    else
      echo "Scalp mask exists: $SCALP_MASK"
    fi
  else
    echo "WARNING: final_tissues not found; cannot create scalp mask: $FINAL_TISSUES"
  fi
}

###############################################################
# Step 2: Preflight checks
###############################################################
get_form_codes() {
  if ! command -v fslhd >/dev/null 2>&1; then
    echo "ERROR: fslhd not found in PATH." >&2
    return 2
  fi

  if ! command -v fslmaths >/dev/null 2>&1; then
    echo "WARNING: fslmaths not found in PATH." >&2
  fi

  if [ -z "$t1_charm_input" ] || [ ! -f "$t1_charm_input" ]; then
    echo "ERROR: T1 file missing." >&2
    echo "Checked:" >&2
    echo "  $t1_file" >&2
    echo "  $t1_file_cache" >&2
    return 2
  fi

  local hdr q s
  hdr="$(fslhd "$t1_charm_input")"

  q=$(awk '/^qform_code/ {print $2; exit}' <<< "$hdr")
  s=$(awk '/^sform_code/ {print $2; exit}' <<< "$hdr")
  echo "${q:-0} ${s:-0}"
}

section "BBOP Step 4 — SimNIBS CHARM (subject: ${subject})"
echo "BASE_DIR:   $BASE_DIR"
echo "Folder:     $folder_path"
echo "T1:         $t1_charm_input"
echo "T2:         ${t2_charm_input:-"(none)"}"
echo "Output:     $m2m_dir"
echo "DONE flag:  $DONE_FLAG"
echo

if [ ! -x "$charm_command" ]; then
    echo "ERROR: SimNIBS charm not found:"
    echo "  $charm_command"
    exit 1
fi

if [ -z "$t1_charm_input" ] || [ ! -f "$t1_charm_input" ]; then
    echo "ERROR: T1_iso1mm not found."
    echo "Checked:"
    echo "  $t1_file"
    echo "  $t1_file_cache"
    exit 1
fi

###############################################################
# Decide mode
###############################################################
if [ "$t1_only" = true ]; then
    mode="T1_ONLY (forced)"
elif [ -n "$t2_charm_input" ]; then
    mode="T1+T2 (auto)"
else
    mode="T1_ONLY (auto: no T2)"
fi
echo "Mode:       $mode"

expected_ok=true
if [[ "$mode" == "T1+T2 (auto)" ]] && [ -d "$m2m_dir" ]; then
    [ -f "$m2m_dir/T2_reg.nii.gz" ] || expected_ok=false
fi

###############################################################
# Skip logic
###############################################################
section "Skip logic"

if [ -f "$DONE_FLAG" ]; then
    echo "DONE flag present."
    if [ -d "$m2m_dir" ] && [ -f "$m2m_dir/T1.nii.gz" ] && [ "$expected_ok" = true ]; then
        echo "Outputs complete — skipping."
        ensure_scalp_mask
        exit 0
    fi
    echo "WARNING: DONE flag but outputs incomplete — rerunning."
fi

if [ -d "$m2m_dir" ] && [ -f "$m2m_dir/T1.nii.gz" ] && [ "$expected_ok" = true ]; then
    echo "Outputs already exist — creating DONE flag."
    touch "$DONE_FLAG"
    ensure_scalp_mask
    exit 0
fi

###############################################################
# Geometry + overwrite policy
###############################################################
section "Geometry checks"

read -r qform_code sform_code < <(get_form_codes)

echo "qform_code=$qform_code  sform_code=$sform_code"

if [ "$qform_code" -eq 0 ] && [ "$sform_code" -eq 0 ]; then
  echo "ERROR: both qform and sform are 0 — cannot run SimNIBS."
  exit 1
fi

force_flag="--forceqform"
if [ "$qform_code" -eq 0 ] && [ "$sform_code" -gt 0 ]; then
  force_flag="--forcesform"
fi

forcerun_flag=""
if [ -d "$m2m_dir" ]; then
  forcerun_flag="--forcerun"
fi

echo "CHARM flags: $forcerun_flag $force_flag"

###############################################################
# Environment
###############################################################
section "Environment setup"
export SIMNIBS_HOME="$simnibs_dir"
export PATH="$(dirname "$charm_command"):$PATH"
export QT_QPA_PLATFORM=offscreen
export MPLBACKEND=Agg

# SimNIBS / OpenBLAS stability safeguard
# Prevents OpenBLAS oversubscription crashes observed with SimNIBS 4.6 on macOS.
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"
export MKL_NUM_THREADS="${MKL_NUM_THREADS:-1}"
export VECLIB_MAXIMUM_THREADS="${VECLIB_MAXIMUM_THREADS:-1}"
export NUMEXPR_NUM_THREADS="${NUMEXPR_NUM_THREADS:-1}"

echo "Thread limits:"
echo "  OPENBLAS_NUM_THREADS=$OPENBLAS_NUM_THREADS"
echo "  OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo "  MKL_NUM_THREADS=$MKL_NUM_THREADS"
echo "  VECLIB_MAXIMUM_THREADS=$VECLIB_MAXIMUM_THREADS"
echo "  NUMEXPR_NUM_THREADS=$NUMEXPR_NUM_THREADS"

###############################################################
# Run CHARM
###############################################################
section "Run CHARM"

cd "$folder_path" || exit 1

if [[ "$mode" == T1_ONLY* ]]; then
    echo "$charm_command $forcerun_flag $force_flag \"$subject\" \"$t1_charm_input\""
    $charm_command $forcerun_flag $force_flag "$subject" "$t1_charm_input"
else
    echo "$charm_command $forcerun_flag $force_flag \"$subject\" \"$t1_charm_input\" \"$t2_charm_input\""
    $charm_command $forcerun_flag $force_flag "$subject" "$t1_charm_input" "$t2_charm_input"
fi

###############################################################
# Validate + finalize
###############################################################
section "Validate outputs"

if [ ! -d "$m2m_dir" ] || [ ! -f "$m2m_dir/T1.nii.gz" ]; then
    echo "ERROR: Expected outputs missing in $m2m_dir"
    exit 1
fi

if [[ "$mode" == "T1+T2 (auto)" ]] && [ ! -f "$m2m_dir/T2_reg.nii.gz" ]; then
    echo "ERROR: T2_reg missing."
    exit 1
fi

ensure_scalp_mask

###############################################################
# Finalize MR-cache: move used iso1mm inputs (post-success)
###############################################################
section "Finalize MR-cache (used iso1mm inputs)"

mkdir -p "$mrcache_path"

for f in \
  "$folder_path/${subject}_T1_iso1mm.nii.gz" \
  "$folder_path/${subject}_T2_iso1mm.nii.gz"
do
  if [ -f "$f" ]; then
    echo "Caching iso1mm input: $(basename "$f") → $mrcache_path"
    mv "$f" "$mrcache_path/"
  fi
done

touch "$DONE_FLAG"

echo
echo "DONE: Step 4 completed for $subject"
echo "Outputs: $m2m_dir"
echo "Flag:    $DONE_FLAG"
echo
