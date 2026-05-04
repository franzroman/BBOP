#!/bin/bash

# Wrapper to run the BBOP preprocessing pipeline.
#
# Usage:
#   ./BBOP_pipeline_preproc_RUN-command.sh \
#       <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--with-pCT|--without-pCT]
#
# Example (HPC, no pCT step):
#
#   cd /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025/Scripts/BBOP_Pipeline/preprocessing
#
#   chmod +x BBOP_pipeline_preproc_RUN-command.sh
#   chmod +x BBOP_pipeline_preproc.sh
#
#   ./BBOP_pipeline_preproc_RUN-command.sh \
#       /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
#       KC-PILOT \
#       caudate_da_rh mfg5_internal_v3 \
#       --without-pCT

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <BASE_DIR> <SUBJECT> [ROI1 ROI2 ...] [--with-pCT|--without-pCT]"
    exit 1
fi

BASE_DIR="$1"
subject="$2"
shift 2

# Directory of this wrapper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pipeline_script="${SCRIPT_DIR}/BBOP_pipeline_preproc.sh"

echo "Running BBOP preprocessing pipeline..."
echo "  BASE_DIR: $BASE_DIR"
echo "  SUBJECT:  $subject"
echo

chmod +x "$pipeline_script"

# Call pipeline with:
#   BASE_DIR  SUBJECT  remaining args (ROIs + flags)
"$pipeline_script" "$BASE_DIR" "$subject" "$@"

if [ $? -eq 0 ]; then
    echo "Preprocessing completed successfully for subject $subject."
else
    echo "Preprocessing pipeline failed for subject $subject."
    exit 1
fi
