#!/bin/bash

# Step 3: Resample T1 (required) and T2 (optional) to 1 mm isotropic resolution.
#
# Usage: $0 <BASE_DIR> <SUBJECT>
#
# Inputs (expected from previous steps):
#   BASE_DIR/Analysis/Ultrasound/$SUBJECT/${SUBJECT}_T1.nii     (required)
#   BASE_DIR/Analysis/Ultrasound/$SUBJECT/${SUBJECT}_T2.nii     (optional)
#
# Outputs:
#   BASE_DIR/Analysis/Ultrasound/$SUBJECT/${SUBJECT}_T1_iso1mm.nii.gz
#   BASE_DIR/Analysis/Ultrasound/$SUBJECT/${SUBJECT}_T2_iso1mm.nii.gz   (only if T2 exists)
#
# Notes:
#   - T1 is mandatory for BBOP.
#   - T2 is optional. If missing, T2 resampling and subsequent steps will be skipped gracefully.
#   - Originals (T1 and/or T2) are moved to MR-cache/.

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

folder_path="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"
mrcache_path="$folder_path/MR-cache"

# Original anatomy files
t1_input="$folder_path/${SUBJECT}_T1.nii"
t2_input="$folder_path/${SUBJECT}_T2.nii"

t1_in_cache="$mrcache_path/${SUBJECT}_T1.nii"
t2_in_cache="$mrcache_path/${SUBJECT}_T2.nii"

# Iso1mm files
t1_output="$folder_path/${SUBJECT}_T1_iso1mm.nii.gz"
t2_output="$folder_path/${SUBJECT}_T2_iso1mm.nii.gz"

t1_iso_in_cache="$mrcache_path/${SUBJECT}_T1_iso1mm.nii.gz"
t2_iso_in_cache="$mrcache_path/${SUBJECT}_T2_iso1mm.nii.gz"

DONE_FLAG="$folder_path/.BBOP_step3_done"

# Optional: read pipeline version if available
PIPELINE_VERSION_FILE="$(dirname "$0")/BBOP_version.sh"
if [ -f "$PIPELINE_VERSION_FILE" ]; then
  source "$PIPELINE_VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

echo
echo "=== BBOP Step 3: Isotropic resampling (1 mm) ==="
echo "Subject:        $SUBJECT"
echo "BBOP version:   $BBOP_VERSION"
echo "Subject folder: $folder_path"
echo

###############################################################
# Step 0: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Step 3 already completed earlier (flag found: $DONE_FLAG)"

    if [ -f "$t1_output" ]; then
        echo "    T1_iso1mm exists in subject folder: $t1_output"
    elif [ -f "$t1_iso_in_cache" ]; then
        echo "    T1_iso1mm exists in MR-cache: $t1_iso_in_cache"
    elif [ -f "$t1_in_cache" ]; then
        echo "    Note: T1 original exists in MR-cache: $t1_in_cache (but iso1mm missing)"
    elif [ -f "$t1_input" ]; then
        echo "    Note: T1 original exists in subject folder: $t1_input (but iso1mm missing)"
    else
        echo "    Note: T1 not found in subject folder or MR-cache."
    fi

    if [ -f "$t2_output" ]; then
        echo "    T2_iso1mm exists in subject folder: $t2_output"
    elif [ -f "$t2_iso_in_cache" ]; then
        echo "    T2_iso1mm exists in MR-cache: $t2_iso_in_cache"
    elif [ -f "$t2_in_cache" ]; then
        echo "    Note: T2 original exists in MR-cache: $t2_in_cache (but iso1mm missing)"
    elif [ -f "$t2_input" ]; then
        echo "    Note: T2 original exists in subject folder: $t2_input (but iso1mm missing)"
    else
        echo "    Note: No T2_iso1mm and no T2 original found (T2 may be absent)."
    fi

    # Only skip if the key output exists

    if [ -f "$t1_output" ] || [ -f "$t1_iso_in_cache" ]; then
        echo "    Skipping Step 3."
        echo
        exit 0
    else
        echo "    Warning: completion flag exists but no T1_iso1mm output was found."
        echo "    Checked:"
        echo "      $t1_output"
        echo "      $t1_iso_in_cache"
        echo "    Re-running Step 3 to regenerate outputs."
        echo
    fi
fi


###############################################################
# Step 1: Resample T1 (required)
###############################################################
if [ -f "$t1_input" ]; then
    t1_source="$t1_input"
elif [ -f "$t1_in_cache" ]; then
    t1_source="$t1_in_cache"
else
    echo "ERROR: Required T1 file not found."
    echo "Checked:"
    echo "  $t1_input"
    echo "  $t1_in_cache"
    exit 1
fi

echo "### Resampling T1 (${t1_source}) to 1 mm isotropic ###"
flirt -in "$t1_source" -ref "$t1_source" -applyisoxfm 1.0 -nosearch -out "$t1_output"

if [ ! -f "$t1_output" ]; then
    echo "Error: T1 resampling failed — no output created."
    exit 1
fi
echo "T1 resampled image created: $t1_output"

###############################################################
# Step 2: Resample T2 (optional)
###############################################################
if [ -f "$t2_input" ]; then
    t2_source="$t2_input"
elif [ -f "$t2_in_cache" ]; then
    t2_source="$t2_in_cache"
else
    t2_source=""
fi

if [ -n "$t2_source" ]; then
    echo
    echo "### Resampling T2 (${t2_source}) to 1 mm isotropic ###"
    flirt -in "$t2_source" -ref "$t2_source" -applyisoxfm 1.0 -nosearch -out "$t2_output"
else
    echo
    echo "### No T2 file found — skipping T2 resampling. ###"
fi

if [ -n "$t2_source" ]; then
    if [ ! -f "$t2_output" ]; then
        echo "Warning: T2 resampling failed — continuing without T2."
    else
        echo "T2 resampled image created: $t2_output"
    fi
fi
###############################################################
# Step 3: Move originals to MR-cache
###############################################################
echo
echo "### Moving original files to MR-cache ###"
mkdir -p "$mrcache_path"

# Always move T1
if [ -f "$t1_input" ]; then
    mv "$t1_input" "$mrcache_path/" && echo "Moved original T1 → MR-cache"
fi

# Move T2 only if it exists
if [ -f "$t2_input" ]; then
    mv "$t2_input" "$mrcache_path/" && echo "Moved original T2 → MR-cache"
fi

###############################################################
# Step 4: Mark completion
###############################################################
touch "$DONE_FLAG"

echo
echo "### Step 3 completed for subject ${SUBJECT}. ###"
echo "Completion flag written to: $DONE_FLAG"
echo
