#!/usr/bin/env bash

BASE_DIR="/Volumes/T9_XF/Studies/BASE_DIR_BBOP"
SUB="sub-ErnieExtended"
ROIS=(caudate_da_rh mfg5_internal_v3)

source "$BASE_DIR/Scripts/BBOP_Pipeline/BBOP_setup.sh"
source ~/bbop-venv/bin/activate

cd "$PIPE"
chmod +x *.sh

./BBOP_pipeline_preproc_RUN-command.sh \
  "$BASE_DIR" \
  "$SUB" \
  "${ROIS[@]}" \
  --without-pCT \
  --coords --coordmask \
  --with-TUSentry \
  --trajectory