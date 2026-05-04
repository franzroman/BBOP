#!/bin/bash

# ===========================================================
# Step 8: SimNIBS CHARM Simulation (headless, BBOP-style)
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT> [T1_ONLY]
#
# Examples:
#   # Auto mode (use T1+T2 if T2_coreg exists, else T1-only)
#   ./BBOP_step8_pipeline_SimNIBS_dyn.sh \
#       /path/to/TUSMR2025 \
#       KC-PILOT
#
#   # Force T1-only mode (e.g. no reliable T2)
#   ./BBOP_step8_pipeline_SimNIBS_dyn.sh \
#       /path/to/TUSMR2025 \
#       KC-PILOT \
#       true
#
# Notes:
#   - Uses the same logic as the old pipeline (forceqform / forcesform retry),
#     but with the new iso1mm filenames and without activate_simnibs.
# ===========================================================

set -euo pipefail

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

date_str=$(date '+%Y-%m-%d_%H-%M-%S')

###############################################################
# Step 1: Paths & logging
###############################################################

# Central log
log_root="$BASE_DIR/Analysis/Pipeline-Log"
log_file="$log_root/BBOP_Pipeline_Log.csv"
log_dir="$log_root/Log-Files"
mkdir -p "$log_root" "$log_dir"

# Subject log (for this SimNIBS run)
subject_log_file="$log_dir/BBOP_${subject}_SimNIBS_Log_${date_str}.txt"

# SimNIBS
simnibs_dir="/home/franzs95/SimNIBS-4.1"
charm_command="$simnibs_dir/bin/charm"

# Subject folder & images (new iso1mm naming)
folder_path="$BASE_DIR/Analysis/Zapping/$subject"
t1_file="$folder_path/${subject}_T1_iso1mm.nii.gz"
t2_file="$folder_path/${subject}_T2_iso1mm_coreg.nii.gz"
output_directory="$folder_path"

mkdir -p "$output_directory"

# Start logging *everything* to the subject log
exec > >(tee -a "$subject_log_file") 2>&1

###############################################################
# Helper: append to central CSV log
###############################################################
log_step() {
    local subj="$1"
    local step="$2"
    local status="$3"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # ensure header exists
    if [ ! -f "$log_file" ]; then
        echo "subject,step,status,timestamp" > "$log_file"
    fi

    echo "$subj,$step,$status,$ts" >> "$log_file"
}

###############################################################
# Step 2: Sanity checks
###############################################################

echo
echo "=== Step 8: SimNIBS CHARM Simulation for ${subject} ==="
echo "BASE_DIR:      $BASE_DIR"
echo "Folder path:   $folder_path"
echo "T1 file:       $t1_file"
echo "T2 coreg file: $t2_file (optional)"
echo

if [ ! -x "$charm_command" ]; then
    echo "Error: SimNIBS 'charm' binary not found or not executable:"
    echo "  $charm_command"
    exit 1
fi

if [ ! -f "$t1_file" ]; then
    echo "Error: T1_iso1mm not found:"
    echo "  $t1_file"
    echo "Make sure Steps 1–4 completed correctly."
    exit 1
fi

# Decide mode:
#   - If t1_only=true  -> force T1-only
#   - Else if T2_coreg exists -> T1+T2
#   - Else -> T1-only auto
mode=""
if [ "$t1_only" = true ]; then
    mode="T1_ONLY (forced)"
elif [ -f "$t2_file" ]; then
    mode="T1+T2 (auto)"
else
    mode="T1_ONLY (auto: no T2_coreg found)"
fi

echo "SimNIBS mode: $mode"
echo

###############################################################
# Step 3: Minimal headless SimNIBS environment
###############################################################

export SIMNIBS_HOME="$simnibs_dir"
export PATH="$simnibs_dir/bin:$PATH"

# Avoid GUI / X display issues
export QT_QPA_PLATFORM=offscreen
export MPLBACKEND=Agg

###############################################################
# Step 4: Run CHARM (forceqform/forcesform logic)
###############################################################

log_step "$subject" "Step 8 SimNIBS" "started"

cd "$output_directory" || { echo "Cannot cd to $output_directory"; exit 1; }

echo "Running CHARM for subject $subject..."
echo

if [[ "$mode" == T1_ONLY* ]]; then
    echo "T1-only mode."
    echo "Command:"
    echo "  $charm_command --forceqform \"$subject\" \"$t1_file\""
    echo

    $charm_command --forceqform "$subject" "$t1_file" || {
        echo "First attempt failed – retrying with --forcesform..."
        $charm_command --forcesform "$subject" "$t1_file" || {
            log_step "$subject" "Step 8 SimNIBS" "failed"
            echo "Both CHARM attempts (T1-only) failed. Check inputs and SimNIBS logs."
            exit 1
        }
    }

else
    echo "Using both T1 and T2."
    echo "Command:"
    echo "  $charm_command --forceqform \"$subject\" \"$t1_file\" \"$t2_file\""
    echo

    $charm_command --forceqform "$subject" "$t1_file" "$t2_file" || {
        echo "First attempt failed – retrying with --forcesform..."
        $charm_command --forcesform "$subject" "$t1_file" "$t2_file" || {
            log_step "$subject" "Step 8 SimNIBS" "failed"
            echo "Both CHARM attempts (T1+T2) failed. Check inputs and SimNIBS logs."
            exit 1
        }
    }
fi

###############################################################
# Step 5: Final logging
###############################################################

log_step "$subject" "Step 8 SimNIBS" "completed"
log_step "$subject" "Sim Pipeline" "completed"

echo
echo "=== Step 8 completed successfully for subject $subject ==="
echo "SimNIBS outputs should be in: $folder_path/m2m_${subject}"
echo
