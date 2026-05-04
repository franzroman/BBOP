#!/usr/bin/env bash

# ---- BBOP session configuration --------------------------------------------

if [ -z "${BASE_DIR:-}" ]; then
  echo "ERROR: BASE_DIR is not set before sourcing BBOP_setup.sh"
  return 1 2>/dev/null || exit 1
fi

# ---- Core paths -------------------------------------------------------------

export PIPE="$BASE_DIR/Scripts/BBOP_Pipeline"
export TOOLS_DIR="$BASE_DIR/Tools"

# ---- External tools ---------------------------------------------------------

export PETRA2CT_DIR="$TOOLS_DIR/petra-to-ct"
export SPM_DIR="$TOOLS_DIR/spm25"
export NIFTI_TOOLS_DIR="$TOOLS_DIR/matlab_nifti_tools"
export TUS_ENTRY_DIR="$TOOLS_DIR/TUS_entry"