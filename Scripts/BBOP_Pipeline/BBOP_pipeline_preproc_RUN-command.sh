#!/bin/bash
set -euo pipefail

# Wrapper to run the BBOP preprocessing pipeline.
#
# Usage:
#   ./BBOP_pipeline_preproc_RUN-command.sh \
#     <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] \
#     [--coords|--maskwarp|--coordmask|--all|--none] [--radius-mm R] \
#     [--with-pCT|--without-pCT] \
#     [--with-TUSentry|--without-TUSentry|--trajectory] \
#     [--tusentry-dir PATH] [--min-cm X] [--max-cm Y]

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] \
[--coords|--maskwarp|--coordmask|--all|--none] [--radius-mm R] \
[--with-pCT|--without-pCT] [--with-TUSentry|--without-TUSentry|--trajectory] \
[--tusentry-dir PATH] [--min-cm X] [--max-cm Y]"
  exit 1
fi

BASE_DIR="$1"
subject="$2"
shift 2

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pipeline_script="${SCRIPT_DIR}/BBOP_pipeline_preproc.sh"

# Optional: show pipeline version
VERSION_FILE="${SCRIPT_DIR}/BBOP_version.sh"
if [ -f "$VERSION_FILE" ]; then
  source "$VERSION_FILE"
fi

echo "Running BBOP preprocessing pipeline..."
echo "  BASE_DIR: $BASE_DIR"
echo "  SUBJECT:  $subject"
[ -n "${BBOP_VERSION:-}" ] && echo "  BBOP version: $BBOP_VERSION"
echo "  ARGS:     $*"
echo

chmod +x "$pipeline_script"

"$pipeline_script" "$BASE_DIR" "$subject" "$@"

echo "Preprocessing completed successfully for subject $subject."
