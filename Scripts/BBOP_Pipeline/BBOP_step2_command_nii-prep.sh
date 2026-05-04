#!/usr/bin/env bash
set -euo pipefail

# ===========================================================
# Step 2: Select and stage canonical anatomy for analysis
#
# Responsibilities:
#   - Identify T1, T2 (FLAIR), PETRA, and ZTE variants from RAW anat folder
#   - Copy them into Analysis subject root as:
#         SUBJECT_T1.nii
#         SUBJECT_T2.nii                 (if exists)
#         SUBJECT_PETRA_<LABEL>.nii      (if exists; e.g. ND, NORM, DIS3D)
#         SUBJECT_ZTE_<LABEL>.nii        (if exists; e.g. DIS3D, GENERIC)
#   - Create completion flag
#
# Notes:
#   - Identification is heuristic and primarily filename-based.
#   - JSON sidecars are optional, but if present they are used to classify
#     PETRA variants more intelligently.
#   - Matching is case-insensitive and supports multiple aliases.
# ===========================================================

###############################################################
# Step 0: Parse arguments
###############################################################
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT>"
    exit 1
fi

BASE_DIR="$1"
SUBJECT="$2"

RAW_ANAT="$BASE_DIR/Raw-Data/Subjects/$SUBJECT/ses-01/anat"
DEST="$BASE_DIR/Analysis/Ultrasound/$SUBJECT"
DONE_FLAG="$DEST/.BBOP_step2_done"

# Optional: read pipeline version if available
PIPELINE_VERSION_FILE="$(dirname "$0")/BBOP_version.sh"
if [ -f "$PIPELINE_VERSION_FILE" ]; then
  source "$PIPELINE_VERSION_FILE"
else
  BBOP_VERSION="unknown"
fi

echo
echo "=== BBOP Step 2: Canonical anatomy selection ==="
echo "Subject:        $SUBJECT"
echo "BBOP version:   $BBOP_VERSION"
echo "RAW anat:       $RAW_ANAT"
echo "DEST:           $DEST"
echo

###############################################################
# Step 1: Skip if already completed
###############################################################
if [ -f "$DONE_FLAG" ]; then
    echo ">>> Detected completion flag for Step 2:"
    echo "    $DONE_FLAG"
    echo ">>> Assuming T1/T2/PETRA already staged."
    echo
    exit 0
fi

###############################################################
# Step 2: Sanity checks
###############################################################
if [ ! -d "$RAW_ANAT" ]; then
    echo "Error: RAW anat folder does not exist:"
    echo "  $RAW_ANAT"
    exit 1
fi

if [ ! -d "$DEST" ]; then
    echo "Error: Analysis subject folder does not exist:"
    echo "  $DEST"
    exit 1
fi

###############################################################
# Step 3: Identify canonical NIFTIs in RAW
###############################################################
echo "Identifying canonical anatomy in RAW..."

# Helper: return unique matches from a list of patterns
find_matches() {
    local search_dir="$1"
    shift
    local pattern
    for pattern in "$@"; do
        find "$search_dir" -maxdepth 1 -type f -iname "$pattern"
    done | sort -u
}

# Helper: warn if multiple candidates exist
warn_multiple_matches() {
    local label="$1"
    local matches="$2"
    local count
    count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')
    if [ "$count" -gt 1 ]; then
        echo "Warning: Multiple ${label} candidates found in RAW anat. Using first match after sort order:"
        printf '%s\n' "$matches" | sed '/^$/d; s/^/  - /'
    fi
}

# Helper: copy .nii or .nii.gz to canonical .nii destination
copy_as_nii() {
    local src="$1"
    local dst="$2"
    if [[ "$src" == *.nii.gz ]]; then
        gunzip -c "$src" > "$dst"
    else
        cp "$src" "$dst"
    fi
}

# Helper: map a NIfTI file to a likely JSON sidecar path
json_for_nifti() {
    local nifti="$1"
    if [[ "$nifti" == *.nii.gz ]]; then
        printf '%s\n' "${nifti%.nii.gz}.json"
    elif [[ "$nifti" == *.nii ]]; then
        printf '%s\n' "${nifti%.nii}.json"
    else
        printf '%s\n' ""
    fi
}

# Helper: classify PETRA variant using filename first, then optional JSON sidecar
classify_petra_variant() {
    local nifti="$1"
    local lower_base json_file image_type_lower

    lower_base=$(basename "$nifti" | tr '[:upper:]' '[:lower:]')

    # --- Filename cues ---
    if [[ "$lower_base" == *postacq*dis3d*corr* ]] || [[ "$lower_base" == *dis3d* ]]; then
        printf '%s\n' "DIS3D"
        return
    fi

    if [[ "$lower_base" == *norm* ]] || [[ "$lower_base" == *fm* ]] || [[ "$lower_base" == *fil* ]]; then
        printf '%s\n' "NORM"
        return
    fi

    if [[ "$lower_base" == *nd* ]]; then
        printf '%s\n' "ND"
        return
    fi

    # --- JSON cues (optional) ---
    json_file=$(json_for_nifti "$nifti")

    if [ -n "$json_file" ] && [ -f "$json_file" ]; then
        image_type_lower=$(tr '[:upper:]' '[:lower:]' < "$json_file")

        if printf '%s\n' "$image_type_lower" | grep -Eq 'dis3d'; then
            printf '%s\n' "DIS3D"
            return
        fi

        if printf '%s\n' "$image_type_lower" | grep -Eq 'norm|fm|fil'; then
            printf '%s\n' "NORM"
            return
        fi

        if printf '%s\n' "$image_type_lower" | grep -Eq '(^|[^[:alnum:]_])nd([^[:alnum:]_]|$)'; then
            printf '%s\n' "ND"
            return
        fi
    fi

    # --- fallback ---
    printf '%s\n' "GENERIC"
}

# T1: prefer specific aliases; avoid generic "*t1*" because it can catch PETRA files
T1_PATTERNS=(
    "*mprage*.nii" "*mprage*.nii.gz"
    "*mp2rage*.nii" "*mp2rage*.nii.gz"
    "*t1w*.nii" "*t1w*.nii.gz"
    "*_T1.nii" "*_T1.nii.gz"
    "*_T1w.nii" "*_T1w.nii.gz"
    "T1*.nii" "T1*.nii.gz"
    "*_T1_*.nii" "*_T1_*.nii.gz"
    "*_T1-*.nii" "*_T1-*.nii.gz"
)
T1_MATCHES=$(find_matches "$RAW_ANAT" "${T1_PATTERNS[@]}" || true)
warn_multiple_matches "T1" "$T1_MATCHES"
T1FILE=$(printf '%s\n' "$T1_MATCHES" | sed '/^$/d' | head -n 1)

# T2/FLAIR: prefer explicit T2-FLAIR patterns first
T2_PATTERNS=(
    "*t2*flair*.nii" "*t2*flair*.nii.gz"
    "*flair*.nii" "*flair*.nii.gz"
    "*t2w*.nii" "*t2w*.nii.gz"
)
T2_MATCHES=$(find_matches "$RAW_ANAT" "${T2_PATTERNS[@]}" || true)
warn_multiple_matches "T2/FLAIR" "$T2_MATCHES"
T2FILE=$(printf '%s\n' "$T2_MATCHES" | sed '/^$/d' | head -n 1)

# PETRA: keep all PETRA-like candidates for variant-wise staging
PETRA_PATTERNS=(
    "*petra*.nii" "*petra*.nii.gz"
)
PETRA_MATCHES=$(find_matches "$RAW_ANAT" "${PETRA_PATTERNS[@]}" || true)
PETRA_COUNT=$(printf '%s\n' "$PETRA_MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')
if [ "$PETRA_COUNT" -gt 1 ]; then
    echo "Info: Multiple PETRA candidates found. Attempting variant-wise classification and staging:"
    printf '%s\n' "$PETRA_MATCHES" | sed '/^$/d; s/^/  - /'
fi

# ZTE: keep all ZTE-like candidates for variant-wise staging
ZTE_PATTERNS=(
    "*zte*.nii" "*zte*.nii.gz"
)
ZTE_MATCHES=$(find_matches "$RAW_ANAT" "${ZTE_PATTERNS[@]}" || true)
ZTE_COUNT=$(printf '%s\n' "$ZTE_MATCHES" | sed '/^$/d' | wc -l | tr -d ' ')

if [ "$ZTE_COUNT" -gt 1 ]; then
    echo "Info: Multiple ZTE candidates found. Attempting variant-wise classification and staging:"
    printf '%s\n' "$ZTE_MATCHES" | sed '/^$/d; s/^/  - /'
fi

###############################################################
# Step 4: Copy to Analysis subject root
###############################################################

# ---------- T1 (required) ----------
if [ -z "${T1FILE:-}" ]; then
    echo "ERROR: No T1-like NIFTI found in RAW anat."
    echo "Searched for aliases such as mprage, mp2rage, t1w, _T1, and _T1w."
    exit 1
fi

echo "Using T1: $T1FILE"
copy_as_nii "$T1FILE" "$DEST/${SUBJECT}_T1.nii"

# ---------- T2 (optional) ----------
if [ -n "${T2FILE:-}" ]; then
    echo "Using T2: $T2FILE"
    copy_as_nii "$T2FILE" "$DEST/${SUBJECT}_T2.nii"
else
    echo "Warning: No T2 (FLAIR) found — proceeding without T2."
fi

# ---------- PETRA variants (optional) ----------
if [ "$PETRA_COUNT" -gt 0 ]; then
    echo "Processing PETRA candidates..."
    echo "Detected PETRA variants:"

    USED_PETRA_LABELS=""

    while IFS= read -r petra_file; do
        [ -z "$petra_file" ] && continue

        label=$(classify_petra_variant "$petra_file")
        base_label="$label"
        suffix=2
        dest_file="$DEST/${SUBJECT}_PETRA_${label}.nii"

        while [ -e "$dest_file" ] || printf '%s\n' "$USED_PETRA_LABELS" | grep -Fxq "$label"; do
            if [ "$suffix" -eq 2 ]; then
                echo "Warning: PETRA label collision for '$base_label'."
                echo "  Existing output label: $label"
                echo "  New file:              $petra_file"
            fi
            label="${base_label}_${suffix}"
            dest_file="$DEST/${SUBJECT}_PETRA_${label}.nii"
            suffix=$((suffix + 1))
        done

        USED_PETRA_LABELS=$(printf '%s\n%s' "$USED_PETRA_LABELS" "$label" | sed '/^$/d')

        echo "  $label -> $(basename "$petra_file")"
        echo "Using PETRA [$label]: $petra_file"
        copy_as_nii "$petra_file" "$dest_file"
    done <<< "$PETRA_MATCHES"
else
    echo "Warning: No PETRA found — proceeding without PETRA."
fi

# ---------- ZTE variants (optional) ----------
if [ "$ZTE_COUNT" -gt 0 ]; then
    echo "Processing ZTE candidates..."
    echo "Detected ZTE variants:"

    USED_ZTE_LABELS=""

    while IFS= read -r zte_file; do
        [ -z "$zte_file" ] && continue

        label=$(classify_petra_variant "$zte_file")
        base_label="$label"
        suffix=2
        dest_file="$DEST/${SUBJECT}_ZTE_${label}.nii"

        while [ -e "$dest_file" ] || printf '%s\n' "$USED_ZTE_LABELS" | grep -Fxq "$label"; do
            if [ "$suffix" -eq 2 ]; then
                echo "Warning: ZTE label collision for '$base_label'."
                echo "  Existing output label: $label"
                echo "  New file:              $zte_file"
            fi
            label="${base_label}_${suffix}"
            dest_file="$DEST/${SUBJECT}_ZTE_${label}.nii"
            suffix=$((suffix + 1))
        done

        USED_ZTE_LABELS=$(printf '%s\n%s' "$USED_ZTE_LABELS" "$label" | sed '/^$/d')

        echo "  $label -> $(basename "$zte_file")"
        echo "Using ZTE [$label]: $zte_file"
        copy_as_nii "$zte_file" "$dest_file"
    done <<< "$ZTE_MATCHES"
else
    echo "Warning: No ZTE found — proceeding without ZTE."
fi

###############################################################
# Step 5: Final sanity check
###############################################################
if [ ! -f "$DEST/${SUBJECT}_T1.nii" ]; then
    echo "ERROR: Canonical T1 not present after copy."
    exit 1
fi

###############################################################
# Step 6: Mark completion
###############################################################
touch "$DONE_FLAG"
echo
echo "Created completion flag: $DONE_FLAG"
echo "=== Step 2 completed successfully for subject $SUBJECT ==="
echo
