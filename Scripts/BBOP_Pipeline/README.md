# BBOP Preprocessing Pipeline (v0.5.1) --- README v8

BBOP (BabelBrain and Brainsight‑Oriented Preprocessing) is a modular
preprocessing pipeline designed for **transcranial ultrasound (TUS)
neuronavigation and simulation workflows**.

It integrates MRI preprocessing, SimNIBS head modeling, targeting
preparation, and optional ultrasound‑planning tools into a reproducible
workflow.

------------------------------------------------------------------------

# High‑level overview

## Inputs

Raw MRI data (BIDS‑like or legacy):

• **T1‑weighted MRI** (required)\
• **T2‑weighted / FLAIR MRI** (optional)\
• **PETRA MRI** (optional; used for pseudo‑CT generation)

ROI definitions:

• MNI coordinates\
• MNI masks\
• or both (defined in `BBOP_ROIs.yaml`)

## Outputs

• Canonicalized anatomical MRI volumes\
• SimNIBS CHARM head model (`m2m_<SUBJECT>`)\
• Optional neuronavigation targeting masks\
• Optional PETRA‑derived pseudo‑CT\
• Optional optimal transducer entry estimation (TUS-entry)\
• Optional trajectory files for BabelBrain

------------------------------------------------------------------------

# Required folder structure

BASE_DIR/

Raw-Data/\
Subjects/sub‑XXX/ses‑01/anat/

Analysis/\
Ultrasound/sub‑XXX/

Scripts/\
BBOP_Pipeline/

Tools/

All paths are resolved relative to the environment variable:

BASE_DIR

------------------------------------------------------------------------

# Dependencies

## Core software

• Bash\
• FSL (flirt, fslmaths, fslhd, fslstats)\
• SimNIBS ≥ 4.1 (CHARM)\
• Python ≥ 3.9\
• R ≥ 4.0\
• dcm2niix

Python packages:

• numpy\
• nibabel\
• pyyaml

R packages:

• oro.nifti

## Optional dependencies

Required only for later steps:

• MATLAB\
• SPM (SPM25 recommended)\
• UCL **petra-to-ct** toolbox\
• MATLAB NIfTI toolbox (`load_nii`)\
• **TUS_entry** toolbox

------------------------------------------------------------------------

# Environment setup

Before running the pipeline define:

export BASE_DIR="/path/to/project"

Environment validation:

bash \$BASE_DIR/Scripts/BBOP_Pipeline/BBOP_check_environment.sh

The environment script ensures:

• required tools are available\
• MATLAB dependencies are configured\
• the **petra-to-ct toolbox** is discoverable by the pipeline

------------------------------------------------------------------------

# Running the pipeline

Recommended entry point:

BBOP_pipeline_preproc_RUN-command.sh

Example:

./BBOP_pipeline_preproc_RUN-command.sh\
`<BASE_DIR>`{=html}\
`<SUBJECT>`{=html}\
ROI1 ROI2 ROI3\
--coords --coordmask\
--with-TUSentry --trajectory

Argument structure:

`<BASE_DIR>`{=html} `<SUBJECT>`{=html} \[ROIs...\] \[OPTIONS...\]

------------------------------------------------------------------------

# Pipeline structure

  Step   Description
  ------ ---------------------------
  1      DICOM → NIfTI preparation
  2      Canonical anatomy staging
  3      1 mm isotropic resampling
  4      SimNIBS CHARM head model
  5      ROI targeting
  6      QC
  7      PETRA → pseudo‑CT
  8      TUS-entry optimization

Steps **5--8 are optional** depending on pipeline flags.

------------------------------------------------------------------------

# Detailed step descriptions

## Step 1 --- DICOM → NIfTI preparation

Creates subject analysis directory structure and converts DICOM to NIfTI
using `dcm2niix` if needed.

### v0.5.1 improvement

The pipeline **no longer requires JSON sidecar files** to proceed.

Behavior:

  Condition                     Pipeline behavior
  ----------------------------- -------------------
  No NIfTI present              Hard fail
  NIfTI present, JSON missing   Warning only
  NIfTI + JSON present          Normal execution

This improves compatibility with **legacy datasets and manually
converted NIfTI files**.

Completion flag:

.BBOP_step1_done

------------------------------------------------------------------------

## Step 2 --- Canonical anatomy staging

Detects canonical anatomical volumes in the raw `anat` folder.

Outputs:

`<SUBJECT>`{=html}\_T1.nii\
`<SUBJECT>`{=html}\_T2.nii\
`<SUBJECT>`{=html}*PETRA*`<LABEL>`{=html}.nii

### v0.5.1 improvement --- expanded T1 detection

T1 detection patterns were expanded to support inconsistent legacy
naming.

Supported aliases now include:

• `mprage`\
• `mp2rage`\
• `t1w`\
• `_T1`\
• `_T1w`\
• `T1*`\
• `*_T1_*`

Example supported filenames:

T1_a.nii\
T1_P003_T0.nii.gz

Completion flag:

.BBOP_step2_done

------------------------------------------------------------------------

## Step 3 --- Isotropic resampling

Resamples anatomical volumes to **1 mm isotropic resolution** using FSL
`flirt`.

Outputs:

`<SUBJECT>`{=html}\_T1_iso1mm.nii.gz\
`<SUBJECT>`{=html}\_T2_iso1mm.nii.gz

Completion flag:

.BBOP_step3_done

------------------------------------------------------------------------

## Step 4 --- SimNIBS CHARM head model

Runs **SimNIBS CHARM** using the isotropic T1 (and optional T2) image.

Outputs:

m2m\_`<SUBJECT>`{=html}/

Additional output:

scalp_mask.nii.gz

Completion flag:

.BBOP_step4_done

------------------------------------------------------------------------

## Step 5 --- Targeting (BabelBrain‑style)

Prepares ROI targeting information for **BabelBrain-style simulation
workflows**.

Input configuration:

Raw-Data/Pipeline/BBOP_ROIs.yaml

Completion flags are written **per ROI**:

Babelbrain/`<ROI>`{=html}/input/.BBOP_step5_done

------------------------------------------------------------------------

## Step 6 --- QC (T1/T2 coregistration check)

Generates a **difference image between T1 and the coregistered T2** to
verify that registration performed by SimNIBS succeeded.

If no coregistered T2 exists the step **skips automatically**.

Outputs:

QC/`<SUBJECT>`{=html}\_T2reg_float.nii.gz\
QC/`<SUBJECT>`{=html}\_T1-T2_difference.nii.gz\
QC/`<SUBJECT>`{=html}\_QC_summary.txt

Completion flag:

.BBOP_step6_done

------------------------------------------------------------------------

## Step 7 --- PETRA → pseudo‑CT

Converts a **PETRA MRI** into a **pseudo‑CT (pCT)** using the **UCL
petra‑to‑ct toolbox**.

Runs only if:

--with-pCT

PETRA selection priority:

1.  `<SUBJECT>_PETRA_NORM`\
2.  `<SUBJECT>_PETRA`\
3.  `<SUBJECT>_PETRA_ND`

Outputs:

`<SUBJECT>`{=html}\_pCT.nii or `<SUBJECT>`{=html}\_pCT.nii.gz

Intermediate toolbox output:

Analysis/Ultrasound/`<SUBJECT>`{=html}/PetraToCT/

MATLAB log:

PetraToCT/matlab_step7\_`<SUBJECT>`{=html}.log

Completion flag:

.BBOP_step7_done

------------------------------------------------------------------------

## Step 8 --- TUS-entry (transducer placement optimization)

Determines an **optimal ultrasound transducer entry point** for each ROI
using the **TUS_entry toolbox**.

### Distance constraints

Default search range:

0.5 -- 8.0 cm

Override with:

--min-cm\
--max-cm

### Outputs per ROI

`<SUBJECT>`{=html}\_`<ROI>`{=html}*TUSentry_neuronav.nii.gz\
`<SUBJECT>`{=html}*`<ROI>`{=html}*TUSentry_validation.nii.gz\
`<SUBJECT>`{=html}*`<ROI>`{=html}\_TUSentry_report.txt

Optional trajectory export:

`<SUBJECT>`{=html}\_`<ROI>`{=html}\_TUSentry_trajectory.txt

Enabled via:

--trajectory

Completion flag:

.BBOP_step8_TUSentry_done

------------------------------------------------------------------------

# Quick Start

Edit variables inside:

BBOP_quickstart.sh

Set:

• BASE_DIR\
• SUB\
• ROIS

Run:

bash BBOP_quickstart.sh

------------------------------------------------------------------------

# Developer Utilities

See:

BBOP_pipeline_cheatsheet.md

This file contains manual commands and examples for debugging **Steps
1--8**.

------------------------------------------------------------------------

# Logging

Pipeline logs are written to:

BASE_DIR/Analysis/Pipeline-Log/

------------------------------------------------------------------------

# Intended audience

Researchers working with:

• transcranial ultrasound stimulation\
• neuronavigation planning\
• acoustic simulations

------------------------------------------------------------------------

# Contact

Developed within the **TUSMR2025** project.
