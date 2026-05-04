#!/bin/bash

# ===========================================================
# Step 5: Coregister T2_iso1mm → T1_iso1mm using ANTs
#
# Usage:
#   $0 <BASE_DIR> <SUBJECT>
#
# Inputs (from Step 4):
#   ${SUBJECT}_T1_iso1mm.nii.gz            (required)
#   ${SUBJECT}_T2_iso1mm.nii.gz            (optional)
#
# Outputs:
#   ${SUBJECT}_T2_iso1mm_coreg.nii.gz
#   ${SUBJECT}_T2_to_T1_iso1mm.mat         (FSL-style affine)
#
# Notes:
#   - If no T2 exists (T1-only subject), this step exits cleanly.
# ===========================================================

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
subject="$2"

folder_path="$BASE_DIR/Analysis/Zapping/$subject"
mrcache_path="$folder_path/MR-cache"
DONE_FLAG="$folder_path/.BBOP_step5_done"

# Input files
t1_resampled="$folder_path/${subject}_T1_iso1mm.nii.gz"
t2_resampled="$folder_path/${subject}_T2_iso1mm.nii.gz"

# Outputs
t2_coreg="$folder_path/${subject}_T2_iso1mm_coreg.nii.gz"
transform_matrix="$folder_path/${subject}_T2_to_T1_iso1mm.mat"

echo
echo "=== Step 5: Coregistering T2_iso1mm → T1_iso1mm for subject ${subject} ==="
echo

###############################################################
# Step 0: Early skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Step 5 already marked as completed (flag: $DONE_FLAG)"

    if [ -f "$t2_coreg" ] && [ -f "$transform_matrix" ]; then
        echo "    Found existing outputs:"
        echo "      - Coreg T2: $t2_coreg"
        echo "      - Affine:   $transform_matrix"
        echo "    Skipping Step 5."
        echo
        exit 0
    else
        echo "    Warning: completion flag exists but expected outputs are missing."
        echo "    Re-running Step 5 to regenerate outputs."
        echo
    fi
fi

###############################################################
# Step 1: Validate inputs
###############################################################
if [ ! -f "$t1_resampled" ]; then
    echo "Error: Missing T1_iso1mm: $t1_resampled"
    exit 1
fi

if [ ! -f "$t2_resampled" ]; then
    echo "No T2_iso1mm found — skipping coregistration."
    echo "This is expected for T1-only subjects."
    exit 0
fi

echo "  Fixed (T1):  $t1_resampled"
echo "  Moving (T2): $t2_resampled"
echo

###############################################################
# Step 2: Run ANTs affine registration
###############################################################
export ANTSPATH=/opt/ants/ants-2.3.1/install/bin/
export PATH="$PATH:$ANTSPATH:/opt/ants/ants-2.3.1/ANTs/Scripts/"

cd "$folder_path"

echo "Running antsRegistrationSyN.sh (affine only)…"
antsRegistrationSyN.sh \
    -d 3 \
    -f "$t1_resampled" \
    -m "$t2_resampled" \
    -t a \
    -n 8 \
    -o T2toT1_

###############################################################
# Step 3: Identify ANTs outputs
###############################################################
itk_affine="T2toT1_0GenericAffine.mat"

if [ -f "T2toT1_Warped.nii.gz" ]; then
    warped="T2toT1_Warped.nii.gz"
elif [ -f "T2toT1Warped.nii.gz" ]; then
    warped="T2toT1Warped.nii.gz"
else
    echo "Error: No ANTs warped output found."
    exit 1
fi

###############################################################
# Step 4: Convert ITK affine → FSL affine
###############################################################
echo "Converting ITK affine to FSL format…"

c3d_affine_tool \
  -ref "$t1_resampled" \
  -src "$t2_resampled" \
  -itk "$itk_affine" \
  -ras2fsl \
  -o "$transform_matrix"

if [ ! -f "$transform_matrix" ]; then
    echo "Error: Failed to create FSL affine at $transform_matrix"
    exit 1
fi

echo "Saved affine to: $transform_matrix"

###############################################################
# Step 5: Save final coregistered T2 image
###############################################################
mv "$warped" "$t2_coreg"
echo "Coregistered T2 saved to: $t2_coreg"

###############################################################
# Step 6: Move intermediate files to MR-cache
###############################################################
mkdir -p "$mrcache_path"

for f in \
    T2toT1_0GenericAffine.mat \
    T2toT1_1Warp.nii.gz \
    T2toT1_1InverseWarp.nii.gz \
    T2toT1_InverseWarped.nii.gz; do
    if [ -f "$f" ]; then
        mv "$f" "$mrcache_path/"
    fi
done

# Move original T2_iso1mm into MR-cache (keep only *_coreg next to T1)
if [ -f "$t2_resampled" ]; then
    mv "$t2_resampled" "$mrcache_path/" && \
        echo "Moved original T2_iso1mm → MR-cache"
fi

###############################################################
# Step 7: Mark completion
###############################################################
touch "$DONE_FLAG"

echo
echo "=== Step 5 completed successfully for subject $subject ==="
echo "Completion flag written to: $DONE_FLAG"
echo
