#!/usr/bin/env bash

# =============================================================================
# BBOP project configuration
# =============================================================================
# Edit this file once for your project.
# Then run subjects with:
#
#   ./BBOP sub-001
#
# Do NOT define the subject here. The subject is passed from the terminal.
# =============================================================================


# ---- Project name -----------------------------------------------------------

BBOP_PROJECT_NAME="MyStudy_BBOP"


# ---- ROIs -------------------------------------------------------------------
# These names must match entries in your BBOP target YAML file.

ROIS=(
  caudate_da_rh
  mfg5_internal_v3
)


# ---- Targeting options ------------------------------------------------------
# Choose what Step 5 - Targeting should generate.
#
# --coords      Convert target coordinates into subject/T1 space.
# --maskwarp    Warp ROI masks into subject/T1 space.
# --coordmask   Create spherical coordinate masks around target coordinates.
# --all         Run all available targeting outputs.
# --none        Skip targeting outputs.
# --radius-mm R Radius for --coordmask, e.g. --radius-mm 4.

TARGET_FLAGS=(
  --coords
  --coordmask
)


# ---- pCT options ------------------------------------------------------------
# Choose ONE:
#
# --without-pCT  Skip pseudo-CT creation.
# --with-pCT     Run PETRA-to-pseudo-CT step.

PCT_FLAGS=(
  --without-pCT
)


# ---- TUS-entry options ------------------------------------------------------
# Choose ONE:
#
# --without-TUSentry  Skip TUS-entry optimization.
# --with-TUSentry     Run TUS-entry optimization.
#
# Optional:
# --trajectory        Export trajectory information. Requires --with-TUSentry.
# --min-cm X          Minimum entry distance, e.g. --min-cm 0.5.
# --max-cm Y          Maximum entry distance, e.g. --max-cm 8.0.
# --tusentry-dir PATH Override default TUS-entry toolbox path.

TUSENTRY_FLAGS=(
  --with-TUSentry
  --trajectory
)


# ---- Python environment -----------------------------------------------------

BBOP_VENV="$HOME/bbop-venv/bin/activate"


# ---- Final combined flags ---------------------------------------------------
# Usually do not edit this section.

BBOP_FLAGS=(
  "${TARGET_FLAGS[@]}"
  "${PCT_FLAGS[@]}"
  "${TUSENTRY_FLAGS[@]}"
)