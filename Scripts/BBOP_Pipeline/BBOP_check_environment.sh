#!/usr/bin/env bash
set -euo pipefail

echo "Checking BBOP environment..."

###############################################################################
# BASE_DIR / setup
###############################################################################
if [ -z "${BASE_DIR:-}" ]; then
  echo "❌ BASE_DIR is not set."
  echo "   Example:"
  echo '   export BASE_DIR="/Volumes/T9_XF/Studies/TUSMR2025_BBOP"'
  exit 1
fi

if [ ! -d "$BASE_DIR" ]; then
  echo "❌ BASE_DIR directory not found: $BASE_DIR"
  exit 1
fi

if [ ! -f "$BASE_DIR/Scripts/BBOP_Pipeline/BBOP_setup.sh" ]; then
  echo "❌ BBOP_setup.sh not found under: $BASE_DIR/Scripts/BBOP_Pipeline"
  exit 1
fi

source "$BASE_DIR/Scripts/BBOP_Pipeline/BBOP_setup.sh"

TOOLS_DIR="$BASE_DIR/Tools"
SPM_DIR="$TOOLS_DIR/spm25"
NIFTI_TOOLS_DIR="$TOOLS_DIR/matlab_nifti_tools"

###############################################################################
# System tools
###############################################################################
for cmd in flirt fslmaths fslhd fslstats; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "❌ Missing FSL command: $cmd"
    exit 1
  }
done
echo "✓ FSL commands OK"

command -v charm >/dev/null 2>&1 || {
  echo "❌ SimNIBS charm not found"
  exit 1
}
echo "✓ SimNIBS charm OK"

command -v python3 >/dev/null 2>&1 || {
  echo "❌ python3 not found"
  exit 1
}
echo "✓ python3 OK"

command -v Rscript >/dev/null 2>&1 || {
  echo "❌ Rscript not found"
  exit 1
}
echo "✓ Rscript OK"

command -v matlab >/dev/null 2>&1 || {
  echo "❌ matlab not found in PATH"
  exit 1
}
echo "✓ matlab OK"

###############################################################################
# File/folder checks
###############################################################################
[ -d "$PIPE" ] || { echo "❌ PIPE directory not found: $PIPE"; exit 1; }
[ -d "$PETRA2CT_DIR" ] || { echo "❌ PETRA2CT_DIR not found: $PETRA2CT_DIR"; exit 1; }
[ -d "$SPM_DIR" ] || { echo "❌ SPM_DIR not found: $SPM_DIR"; exit 1; }
[ -d "$NIFTI_TOOLS_DIR" ] || { echo "❌ NIFTI_TOOLS_DIR not found: $NIFTI_TOOLS_DIR"; exit 1; }

echo "✓ BBOP directories OK"

###############################################################################
# Python packages
###############################################################################
python3 - <<'PY'
import sys
for pkg in ["numpy", "nibabel", "yaml"]:
    try:
        __import__(pkg)
    except ImportError:
        print(f"❌ Missing Python package: {pkg}")
        sys.exit(1)
print("✓ Python packages OK")
PY

###############################################################################
# R packages
###############################################################################
Rscript - <<'RS'
pkgs <- c("oro.nifti")
missing <- pkgs[!sapply(pkgs, requireNamespace, quietly=TRUE)]
if (length(missing) > 0) {
  cat("❌ Missing R packages:", paste(missing, collapse=", "), "\n")
  quit(status=1)
}
cat("✓ R packages OK\n")
RS

###############################################################################
# MATLAB / Step-7 preflight
###############################################################################

MATLAB_CHECK_FILE="$(mktemp /tmp/bbop_matlab_check_XXXXXX.m)"

cat > "$MATLAB_CHECK_FILE" <<MATLAB
restoredefaultpath;

p = strsplit(path, pathsep);
for i = 1:numel(p)
    if contains(p{i}, 'Tools for NIfTI and ANALYZE image')
        try
            rmpath(p{i});
        catch
        end
    end
end

addpath('$SPM_DIR');
addpath(genpath('$NIFTI_TOOLS_DIR'), '-begin');
addpath(genpath('$PETRA2CT_DIR'), '-begin');

req = {'petraToCT.convert','spm','load_nii','load_nii_hdr','bwconncomp','findpeaks'};

for i = 1:numel(req)
    w = which(req{i});
    if isempty(w)
        fprintf(2, '❌ MATLAB dependency not found: %s\\n', req{i});
        exit(1);
    else
        fprintf('✓ MATLAB %s -> %s\\n', req{i}, w);
    end
end

v = ver;
names = {v.Name};

if ~any(strcmp(names, 'Image Processing Toolbox'))
    fprintf(2, '❌ Image Processing Toolbox not installed\\n');
    exit(1);
end

if ~any(strcmp(names, 'Signal Processing Toolbox'))
    fprintf(2, '❌ Signal Processing Toolbox not installed\\n');
    exit(1);
end

fprintf('✓ MATLAB toolboxes OK\\n');
exit;
MATLAB

matlab -batch "run('$MATLAB_CHECK_FILE')"
rm -f "$MATLAB_CHECK_FILE"

echo "✓ Environment looks good."