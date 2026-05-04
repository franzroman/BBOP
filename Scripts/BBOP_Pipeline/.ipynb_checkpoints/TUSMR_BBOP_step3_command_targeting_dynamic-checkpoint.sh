#!/bin/bash

# Step 3: Targeting (BabelBrain-style, FSL-based)
#
#  - For each ROI, read MNI coordinates and mask filename from BBOP_ROIs.yaml
#  - Compute / reuse a T1->MNI affine (FLIRT)
#  - Convert MNI coordinates -> subject T1 space (std2imgcoord)
#  - Warp ROI mask from MNI space -> subject T1 space (FLIRT + inverse matrix)
#
# Usage:
#   TUSMR_BBOP_step3_command_targeting_dynamic.sh \
#       <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]
#
# Example:
#   ./TUSMR_BBOP_step3_command_targeting_dynamic.sh \
#       /path/to/TUSMR2025 KC-PILOT \
#       caudate_da_rh mfg5_internal_v3

set -euo pipefail

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...]"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"
shift 2
ROIS=( "$@" )

if [ "${#ROIS[@]}" -eq 0 ]; then
    echo "No ROIs specified. Nothing to do."
    exit 0
fi

# Paths
DEST="$BASE_DIR/Analysis/Zapping/$SUBJECT"
MR_CACHE="$DEST/MR-cache"
BABELBRAIN_SUBJ_DIR="$DEST/Babelbrain"
YAML_FILE="$BASE_DIR/Raw-Data/Pipeline/BBOP_ROIs.yaml"

# Subject T1 (from step 2)
T1_IMAGE="$DEST/${SUBJECT}_T1.nii"

# FSL root and MNI template (as in BabelBrain docs)
FSL_ROOT="${FSLDIR:-${FSL_DIR:-/usr/share/fsl/5.0}}"
MNI_TEMPLATE="$FSL_ROOT/data/standard/MNI152_T1_1mm.nii.gz"

# Basic sanity checks
if [ ! -f "$T1_IMAGE" ]; then
    echo "Error: Subject T1 image not found at: $T1_IMAGE"
    exit 1
fi

if [ ! -f "$YAML_FILE" ]; then
    echo "Error: ROI YAML file not found at: $YAML_FILE"
    exit 1
fi

if [ ! -f "$MNI_TEMPLATE" ]; then
    echo "Error: MNI template not found at: $MNI_TEMPLATE"
    echo "Please adjust MNI_TEMPLATE in this script."
    exit 1
fi

# Check FSL tools
for cmd in flirt std2imgcoord convert_xfm; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' not found in PATH. Is FSL loaded?"
        exit 1
    fi
done

mkdir -p "$MR_CACHE"

############################################
# Helper: read MNI coords and mask_file from YAML
############################################
get_roi_field() {
    local roi="$1"
    local field="$2"

    python3 - "$YAML_FILE" "$roi" "$field" << 'EOF'
import sys
import yaml

if len(sys.argv) < 4:
    sys.exit(1)

yaml_path, roi, field = sys.argv[1:4]

with open(yaml_path, 'r') as f:
    data = yaml.safe_load(f)

if 'rois' not in data or roi not in data['rois']:
    # ROI not present
    sys.exit(2)

roi_data = data['rois'][roi]
value = roi_data.get(field, None)

# Field not present -> exit 0, no output
if value is None:
    sys.exit(0)

# Print value as plain string or space-separated list
if isinstance(value, (list, tuple)):
    print(" ".join(str(v) for v in value))
else:
    print(str(value))
EOF
}

############################################
# Step 1: Compute / reuse T1->MNI & MNI->T1 transforms
############################################

ANAT2MNI_MAT="$MR_CACHE/${SUBJECT}_anat2mni.mat"
MNI2ANAT_MAT="$MR_CACHE/${SUBJECT}_mni2anat.mat"
T1_IN_MNI="$MR_CACHE/${SUBJECT}_T1_in_MNI.nii.gz"

if [ -f "$ANAT2MNI_MAT" ] && [ -f "$MNI2ANAT_MAT" ]; then
    echo "Reusing existing T1<->MNI transforms in $MR_CACHE"
else
    echo "Computing T1->MNI affine with FLIRT (BabelBrain-style)..."
    flirt -in "$T1_IMAGE" \
          -ref "$MNI_TEMPLATE" \
          -omat "$ANAT2MNI_MAT" \
          -out "$T1_IN_MNI"

    if [ ! -f "$ANAT2MNI_MAT" ]; then
        echo "Error: Failed to create T1->MNI matrix ($ANAT2MNI_MAT)."
        exit 1
    fi

    echo "Inverting affine to get MNI->T1 matrix..."
    convert_xfm -inverse "$ANAT2MNI_MAT" -omat "$MNI2ANAT_MAT"

    if [ ! -f "$MNI2ANAT_MAT" ]; then
        echo "Error: Failed to create MNI->T1 matrix ($MNI2ANAT_MAT)."
        exit 1
    fi
fi

############################################
# Step 2: Process each ROI (with per-ROI skipping)
############################################

echo "Processing ROIs: ${ROIS[*]}"

for ROI in "${ROIS[@]}"; do
    echo
    echo "=== ROI: $ROI ==="

    ROI_DIR="$BABELBRAIN_SUBJ_DIR/$ROI"
    ROI_INPUT_DIR="$ROI_DIR/input"
    mkdir -p "$ROI_INPUT_DIR"

    T1_COORDS_FILE="$ROI_INPUT_DIR/${SUBJECT}_${ROI}_T1coords.txt"
    MASK_OUT="$ROI_INPUT_DIR/${SUBJECT}_${ROI}_mask_T1space.nii.gz"

    ########################
    # 2a) Coordinates
    ########################
    if [ -f "$T1_COORDS_FILE" ]; then
        echo "  - T1 coords file already exists for ROI '$ROI':"
        echo "    $T1_COORDS_FILE"
        echo "    Skipping coordinate transform for this ROI."
    else
        echo "  - Reading MNI coordinates from YAML..."
        MNI_COORDS_RAW="$(get_roi_field "$ROI" "mni_coords" || true)"

        if [ -z "$MNI_COORDS_RAW" ]; then
            echo "    Warning: No mni_coords defined for ROI '$ROI' in YAML. Skipping coordinate transform."
        else
            # Expect: "x y z"
            read -r MNI_X MNI_Y MNI_Z <<< "$MNI_COORDS_RAW"
            echo "    MNI coords: $MNI_X $MNI_Y $MNI_Z"

            # Input file (MNI coords) and output file (T1 coords)
            POINTS_IN="$MR_CACHE/${SUBJECT}_${ROI}_mni_coords.txt"
            POINTS_OUT="$MR_CACHE/${SUBJECT}_${ROI}_t1_coords.txt"

            echo "$MNI_X $MNI_Y $MNI_Z" > "$POINTS_IN"

            echo "  - Transforming MNI coords to T1 space with std2imgcoord..."
            std2imgcoord \
                -img "$T1_IMAGE" \
                -std "$MNI_TEMPLATE" \
                -xfm "$ANAT2MNI_MAT" \
                "$POINTS_IN" > "$POINTS_OUT"

            # POINTS_OUT should contain "x y z" in T1 space
            read -r T1_X T1_Y T1_Z < "$POINTS_OUT"
            echo "    T1 coords: $T1_X $T1_Y $T1_Z"

            echo "$T1_X $T1_Y $T1_Z" > "$T1_COORDS_FILE"
            echo "    Saved T1 coordinates to $T1_COORDS_FILE"

            # Optional cleanup
            rm -f "$POINTS_IN" "$POINTS_OUT"
        fi
    fi

    ########################
    # 2b) Masks
    ########################
    if [ -f "$MASK_OUT" ]; then
        echo "  - Subject-space mask already exists for ROI '$ROI':"
        echo "    $MASK_OUT"
        echo "    Skipping mask warp for this ROI."
    else
        echo "  - Checking for ROI mask in YAML..."
        MASK_FILE_NAME="$(get_roi_field "$ROI" "mask_file" || true)"

        if [ -z "$MASK_FILE_NAME" ]; then
            echo "    No mask_file defined for ROI '$ROI' (coords-only ROI). Skipping mask warp."
        else
            MASK_SRC="$BASE_DIR/Raw-Data/Pipeline/Masks/$MASK_FILE_NAME"

            if [ ! -f "$MASK_SRC" ]; then
                echo "    Warning: mask_file '$MASK_FILE_NAME' not found at $MASK_SRC. Skipping mask warp."
            else
                echo "    Found mask: $MASK_SRC"
                echo "  - Warping ROI mask from MNI -> T1 with FLIRT..."
                flirt -in "$MASK_SRC" \
                      -ref "$T1_IMAGE" \
                      -applyxfm -init "$MNI2ANAT_MAT" \
                      -out "$MASK_OUT" \
                      -interp nearestneighbour

                echo "    Saved subject-space mask to $MASK_OUT"
            fi
        fi
    fi

done

echo
echo "Targeting step (FSL/BabelBrain-style) completed successfully for subject $SUBJECT."
echo
