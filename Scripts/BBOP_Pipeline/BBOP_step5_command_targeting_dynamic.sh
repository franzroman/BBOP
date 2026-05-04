#!/bin/bash

# ===========================================================
# Step 5: Targeting (BabelBrain-style, FSL-based)
#
#  - For each ROI, read MNI coordinates and mask filename from BBOP_ROIs.yaml
#  - Compute / reuse a T1->MNI affine (FLIRT)
#  - Convert MNI coordinates -> subject T1 space (std2imgcoord)
#  - Warp ROI mask from MNI space -> subject T1 space (FLIRT + inverse matrix)
#
# Per-ROI DONE flags (Option A):
#   Writes:  DEST/Babelbrain/<ROI>/input/.BBOP_step5_done
#   Skips ROI if DONE flag exists AND required outputs exist.
# ===========================================================

set -euo pipefail

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--coords] [--maskwarp] [--coordmask] [--all] [--none] [--radius-mm R]"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"
shift 2

# Defaults
DO_COORDS="auto"
DO_MASKWARP="auto"
DO_COORDMASK="off"   # choose "auto" or "off" depending on your preference
RADIUS_MM=1.5

ROIS=()

command -v python3 >/dev/null 2>&1 || { echo "Error: python3 not found in PATH."; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --coords)     DO_COORDS="on" ;;
    --maskwarp)   DO_MASKWARP="on" ;;
    --coordmask)  DO_COORDMASK="on" ;;
    --all)        DO_COORDS="on"; DO_MASKWARP="on"; DO_COORDMASK="on" ;;
    --none)       DO_COORDS="off"; DO_MASKWARP="off"; DO_COORDMASK="off" ;;
    --radius-mm)
      shift
      RADIUS_MM="${1:-}"
      if [ -z "$RADIUS_MM" ]; then
        echo "Error: --radius-mm requires a value"
        exit 1
      fi

      if ! python3 - <<PY
import math
r=float("$RADIUS_MM")
import sys
sys.exit(0 if (r>0 and math.isfinite(r)) else 1)
PY
      then
        echo "Error: --radius-mm must be > 0 (got '$RADIUS_MM')"
        exit 1
      fi
      ;;
    --help|-h)
      echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--coords] [--maskwarp] [--coordmask] [--all] [--none] [--radius-mm R]"
      exit 0
      ;;
    --*)
      echo "Error: Unknown flag: $1"
      exit 1
      ;;
    *)
      ROIS+=("$1")
      ;;
  esac
  shift
done

if [ "${#ROIS[@]}" -eq 0 ]; then
  echo "No ROIs specified. Nothing to do."
  exit 0
fi

if [ "$DO_COORDS" = "off" ] && [ "$DO_MASKWARP" = "off" ] && [ "$DO_COORDMASK" = "off" ]; then
  echo "Targeting disabled by flags (--none). Nothing to do."
  exit 0
fi

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
# Output formatting helper (cosmetic)
###############################################################
section() {
  echo
  echo "------------------------------------------------------------"
  echo "$1"
  echo "------------------------------------------------------------"
}

section "Step 5 — Targeting (subject: ${SUBJECT})"
echo "BBOP version:     $BBOP_VERSION"
echo "BASE_DIR:         $BASE_DIR"
echo "ROIs:             ${ROIS[*]}"
echo "coords:           $DO_COORDS"
echo "maskwarp:         $DO_MASKWARP"
echo "coordmask:        $DO_COORDMASK"
echo "coordmask radius: ${RADIUS_MM} mm"
echo

###############################################################
# Paths
###############################################################
DEST="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"
MR_CACHE="$DEST/MR-cache"
BABELBRAIN_SUBJ_DIR="$DEST/Babelbrain"
YAML_FILE="$BASE_DIR/Raw-Data/Pipeline/BBOP_ROIs.yaml"

# Subject T1 (from step 4 SimNIBS)
T1_IMAGE="$DEST/m2m_${SUBJECT}/T1.nii.gz"

# FSL root and MNI template (as in BabelBrain docs)
FSL_ROOT="${FSLDIR:-${FSL_DIR:-/usr/share/fsl/5.0}}"
MNI_TEMPLATE="$FSL_ROOT/data/standard/MNI152_T1_1mm.nii.gz"

###############################################################
# Basic sanity checks
###############################################################
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
for cmd in flirt std2imgcoord convert_xfm fslmaths fslreorient2std; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: '$cmd' not found in PATH. Is FSL loaded?"
        exit 1
    fi
done

if [ "$DO_COORDMASK" != "off" ]; then
  if ! python3 - <<'PY' >/dev/null 2>&1
import nibabel, numpy
PY
  then
    echo "Error: coordmask requested but Python packages missing (need nibabel, numpy)."
    echo "Install them or run without --coordmask."
    exit 1
  fi
fi

mkdir -p "$MR_CACHE"

############################################
# Helper: read MNI coords and mask_file from YAML
# Returns:
#   0: field missing (prints nothing)
#   2: ROI missing in YAML
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
    sys.exit(2)

roi_data = data['rois'][roi]
value = roi_data.get(field, None)

if value is None:
    sys.exit(0)

if isinstance(value, (list, tuple)):
    print(" ".join(str(v) for v in value))
else:
    print(str(value))
EOF
}

###############################################################
# Step 5.1: Compute / reuse T1->MNI & MNI->T1 transforms
###############################################################
T1_STD="$MR_CACHE/${SUBJECT}_T1_reoriented.nii.gz"

if [ ! -f "$T1_STD" ]; then
    echo "Reorienting T1 to standard orientation (fslreorient2std)..."
    fslreorient2std "$T1_IMAGE" "$T1_STD"
fi

T1_IMAGE="$T1_STD"
echo "Using Step 5 T1 image: $T1_IMAGE"

section "Step 5.1 — T1 ↔ MNI transforms"

ANAT2MNI_MAT="$MR_CACHE/${SUBJECT}_anat2mni.mat"
MNI2ANAT_MAT="$MR_CACHE/${SUBJECT}_mni2anat.mat"
T1_IN_MNI="$MR_CACHE/${SUBJECT}_T1_in_MNI.nii.gz"

if [ -f "$ANAT2MNI_MAT" ] && [ -f "$MNI2ANAT_MAT" ] && [ -f "$T1_IN_MNI" ]; then
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

###############################################################
# Step 5.2: Process each ROI (with per-ROI DONE flags)
###############################################################
section "Step 5.2 — ROI processing"
echo "Processing ROIs: ${ROIS[*]}"

for ROI in "${ROIS[@]}"; do
    section "ROI: $ROI"

    ROI_DIR="$BABELBRAIN_SUBJ_DIR/$ROI"
    ROI_INPUT_DIR="$ROI_DIR/input"
    mkdir -p "$ROI_INPUT_DIR"

    ROI_DONE_FLAG="$ROI_INPUT_DIR/.BBOP_step5_done"

    T1_COORDS_FILE="$ROI_INPUT_DIR/${SUBJECT}_${ROI}_T1coords.txt"
    MASK_OUT="$ROI_INPUT_DIR/${SUBJECT}_${ROI}_mask_T1space.nii.gz"
    COORDMASK_OUT="$ROI_INPUT_DIR/${SUBJECT}_${ROI}_mask_fromcoords_T1space.nii.gz"

    MNI_COORDS_RAW=""
    MASK_FILE_NAME=""

    set +e
    MNI_COORDS_RAW="$(get_roi_field "$ROI" "mni_coords" 2>/dev/null)"
    rc_coords=$?
    MASK_FILE_NAME="$(get_roi_field "$ROI" "mask_file" 2>/dev/null)"
    rc_mask=$?
    set -e

    if [ "$rc_coords" -eq 2 ] && [ "$rc_mask" -eq 2 ]; then
        echo "  Warning: ROI '$ROI' not found in YAML ($YAML_FILE). Skipping ROI."
        continue
    fi

    coords_expected=false
    mask_expected=false
    if [ -n "$MNI_COORDS_RAW" ]; then coords_expected=true; fi
    if [ -n "$MASK_FILE_NAME" ]; then mask_expected=true; fi

    coords_should_run=false
    mask_should_run=false
    coordmask_should_run=false

    # coords
    if [ "$DO_COORDS" = "on" ] || { [ "$DO_COORDS" = "auto" ] && [ "$coords_expected" = true ]; }; then
      coords_should_run=true
    fi

    # mask warp
    if [ "$DO_MASKWARP" = "on" ] || { [ "$DO_MASKWARP" = "auto" ] && [ "$mask_expected" = true ]; }; then
      mask_should_run=true
    fi

    # coordmask eligibility: needs coords either in YAML OR already computed
    coords_available=false
    if [ "$coords_expected" = true ] || [ -f "$T1_COORDS_FILE" ]; then
      coords_available=true
    fi

    coordmask_should_run=false
    if [ "$DO_COORDMASK" = "on" ] || { [ "$DO_COORDMASK" = "auto" ] && [ "$coords_expected" = true ]; }; then
      if [ "$coords_available" = true ]; then
        coordmask_should_run=true
      else
        echo "  - coordmask requested but no coords available (no mni_coords in YAML and no existing T1 coords file). Skipping coordmask."
        coordmask_should_run=false
      fi
    fi

    if [ "$coordmask_should_run" = true ] && [ ! -f "$T1_COORDS_FILE" ]; then
      coords_should_run=true
    fi

    # DONE flag logic
    if [ -f "$ROI_DONE_FLAG" ]; then
        coords_ok=true
        mask_ok=true
        coordmask_ok=true

        if [ "$coords_should_run" = true ] && [ ! -f "$T1_COORDS_FILE" ]; then coords_ok=false; fi
        if [ "$mask_should_run" = true ] && [ ! -f "$MASK_OUT" ]; then mask_ok=false; fi
        if [ "$coordmask_should_run" = true ] && [ ! -f "$COORDMASK_OUT" ]; then coordmask_ok=false; fi

        if [ "$coords_ok" = true ] && [ "$mask_ok" = true ] && [ "$coordmask_ok" = true ]; then
            echo "  >>> ROI already completed (flag: $ROI_DONE_FLAG) and expected outputs exist."
            echo "      Skipping ROI."
            continue
        else
            echo "  >>> ROI DONE flag exists but expected outputs are missing."
            echo "      Re-running ROI."
        fi
    fi

    ########################
    # Coordinates
    ########################
    section "ROI $ROI — Coordinates"

    if [ "$coords_should_run" != true ]; then
        echo "  - Skipping coords (disabled by flags or missing in YAML)."
    else
        if [ -f "$T1_COORDS_FILE" ]; then
            echo "  - T1 coords file already exists:"
            echo "    $T1_COORDS_FILE"
            echo "    Skipping coordinate transform."
        else
            if [ "$coords_expected" = false ]; then
                echo "  - No mni_coords defined in YAML (coords not expected)."
            else
                read -r MNI_X MNI_Y MNI_Z <<< "$MNI_COORDS_RAW"
                echo "  - MNI coords: $MNI_X $MNI_Y $MNI_Z"

                POINTS_IN="$MR_CACHE/${SUBJECT}_${ROI}_mni_coords.txt"
                POINTS_OUT="$MR_CACHE/${SUBJECT}_${ROI}_t1_coords.txt"

                echo "$MNI_X $MNI_Y $MNI_Z" > "$POINTS_IN"

                echo "  - Transforming MNI coords to T1 space with std2imgcoord..."
                std2imgcoord \
                    -std "$MNI_TEMPLATE" \
                    -img "$T1_IMAGE" \
                    -xfm "$ANAT2MNI_MAT" \
                    -mm \
                    "$POINTS_IN" > "$POINTS_OUT"
                read -r T1_X T1_Y T1_Z < "$POINTS_OUT"
                echo "    T1 coords: $T1_X $T1_Y $T1_Z"

                echo "$T1_X $T1_Y $T1_Z" > "$T1_COORDS_FILE"
                echo "    Saved: $T1_COORDS_FILE"

                rm -f "$POINTS_IN" "$POINTS_OUT"
            fi
        fi
    fi

    ########################
    # Masks
    ########################
    section "ROI $ROI — Mask warp"

    if [ "$mask_should_run" != true ]; then
        echo "  - Skipping mask warping (disabled by flags or missing in YAML)."
    else
        if [ -f "$MASK_OUT" ]; then
            echo "  - Subject-space mask already exists:"
            echo "    $MASK_OUT"
            echo "    Skipping mask warp."
        else
            if [ "$mask_expected" = false ]; then
                echo "  - No mask_file defined in YAML (mask not expected)."
            else
                MASK_SRC="$BASE_DIR/Raw-Data/Pipeline/Masks/$MASK_FILE_NAME"

                if [ ! -f "$MASK_SRC" ]; then
                    echo "    Warning: mask_file '$MASK_FILE_NAME' not found at:"
                    echo "      $MASK_SRC"
                    echo "    Skipping mask warp."
                else
                    echo "  - Warping ROI mask from MNI -> T1 with FLIRT..."
                    flirt -in "$MASK_SRC" \
                          -ref "$T1_IMAGE" \
                          -applyxfm -init "$MNI2ANAT_MAT" \
                          -out "$MASK_OUT" \
                          -interp nearestneighbour

                    if [ -f "$MASK_OUT" ]; then
                        echo "    Saved: $MASK_OUT"
                    else
                        echo "    Warning: mask warp did not produce output: $MASK_OUT"
                    fi
                fi
            fi
        fi
    fi

    ########################
    # Coordmask
    ########################
    section "ROI $ROI — Coordmask"

    if [ "$coordmask_should_run" != true ]; then
        echo "  - Skipping coordmask (disabled by flags or missing coords)."
    else
        if [ -f "$COORDMASK_OUT" ]; then
            echo "  - Coordinate-derived mask already exists:"
            echo "    $COORDMASK_OUT"
            echo "    Skipping coordmask generation."
        else
            if [ ! -f "$T1_COORDS_FILE" ]; then
                echo "  - Cannot create coordmask: missing T1 coords file:"
                echo "    $T1_COORDS_FILE"
                echo "    (Enable --coords or provide mni_coords in YAML.)"
            else
                read -r T1_X T1_Y T1_Z < "$T1_COORDS_FILE"
                echo "  - Creating coordmask sphere (r=${RADIUS_MM}mm) at T1 coords: $T1_X $T1_Y $T1_Z"

                python3 - "$T1_IMAGE" "$COORDMASK_OUT" "$T1_X" "$T1_Y" "$T1_Z" "$RADIUS_MM" << 'PY'
import sys
import numpy as np
import nibabel as nib

ref_path, out_path, x, y, z, r = sys.argv[1:]
x, y, z, r = float(x), float(y), float(z), float(r)

img = nib.load(ref_path)
aff = img.affine
shape = img.shape[:3]

ijk = np.linalg.inv(aff).dot([x, y, z, 1.0])[:3]
i0, j0, k0 = ijk

voxel_sizes = np.sqrt((aff[:3, :3] ** 2).sum(axis=0))
rx, ry, rz = r / voxel_sizes

i_min = max(int(np.floor(i0 - rx)), 0)
i_max = min(int(np.ceil (i0 + rx)), shape[0]-1)
j_min = max(int(np.floor(j0 - ry)), 0)
j_max = min(int(np.ceil (j0 + ry)), shape[1]-1)
k_min = max(int(np.floor(k0 - rz)), 0)
k_max = min(int(np.ceil (k0 + rz)), shape[2]-1)

mask = np.zeros(shape, dtype=np.uint8)

ii, jj, kk = np.mgrid[i_min:i_max+1, j_min:j_max+1, k_min:k_max+1]
dist2 = ((ii - i0) / rx) ** 2 + ((jj - j0) / ry) ** 2 + ((kk - k0) / rz) ** 2
mask[ii, jj, kk] = (dist2 <= 1.0).astype(np.uint8)

out = nib.Nifti1Image(mask, aff, img.header)
out.set_data_dtype(np.uint8)
nib.save(out, out_path)
PY

                tmp_bin="${COORDMASK_OUT%.nii.gz}_tmpbin.nii.gz"
                fslmaths "$COORDMASK_OUT" -bin "$tmp_bin"
                mv "$tmp_bin" "$COORDMASK_OUT"

                echo "    Saved: $COORDMASK_OUT"
            fi
        fi
    fi

    # --- Mark ROI done only if required outputs exist ------------------------
    coords_ok=true
    mask_ok=true
    coordmask_ok=true

    if [ "$coords_should_run" = true ] && [ ! -f "$T1_COORDS_FILE" ]; then coords_ok=false; fi
    if [ "$mask_should_run" = true ] && [ ! -f "$MASK_OUT" ]; then mask_ok=false; fi
    if [ "$coordmask_should_run" = true ] && [ ! -f "$COORDMASK_OUT" ]; then coordmask_ok=false; fi

    if [ "$coords_ok" = true ] && [ "$mask_ok" = true ] && [ "$coordmask_ok" = true ]; then
        touch "$ROI_DONE_FLAG"
        echo "  >>> ROI completion flag written: $ROI_DONE_FLAG"
    else
        echo "  >>> ROI NOT marked done (missing expected outputs)."
    fi

done

echo
echo "Targeting step (FSL/BabelBrain-style) completed successfully for subject $SUBJECT."
echo
