# BBOP Preprocessing Pipeline (v0.6.1 – Extended)

BBOP (**BabelBrain and Brainsight-Oriented Preprocessing**) is a modular, reproducible preprocessing pipeline designed for **transcranial ultrasound (TUS)** workflows.

It integrates MRI preprocessing, head modeling, ROI targeting, and optional acoustic planning into a single, structured environment.

---

# 🚀 Quick Start

```bash
git clone <repo> MyStudy_BBOP
cd MyStudy_BBOP
nano BBOP_config.sh
./BBOP sub-XXX
```

**That is the entire user workflow.**

---

# ⚠️ What changed in v0.6.1

## New execution model

Old (deprecated):
```bash
BASE_DIR=...
SUB=...
./BBOP_pipeline_preproc_RUN-command.sh ...
```

New:
```bash
./BBOP sub-XXX
```

### Key improvements
- No manual BASE_DIR handling
- Config-driven workflow
- Project-local execution
- Reduced user error surface

---

# 🧠 Conceptual Design

BBOP is not just a script.

It is a **self-contained project environment**:

```
MyStudy_BBOP/
├── BBOP                ← launcher
├── BBOP_config.sh      ← user configuration
├── Raw-Data/
├── Analysis/
├── Scripts/
└── Tools/
```

Each project:
- owns its data
- owns its config
- runs independently

No global installation required (except dependencies).

---

# 🔬 Pipeline Overview

## Inputs
- T1 MRI (required)
- T2 MRI (optional)
- PETRA MRI (optional)
- ZTE MRI (optional)
- ROI definitions (YAML)

## Outputs
- Preprocessed MRI
- SimNIBS head model
- ROI masks and coordinates
- QC metrics
- Optional pseudo-CT
- Optional TUS-entry optimization

---

# 🔁 Processing Flow

```
Raw MRI
   ↓
DICOM → NIfTI
   ↓
Canonical anatomy
   ↓
Resampling (1 mm)
   ↓
SimNIBS head model
   ↓
Targeting (ROIs)
   ↓
QC (T1–T2)
   ↓
[pCT optional]
   ↓
[TUS-entry optional]
```

---

# 🔬 Detailed Steps

## Step 1 — DICOM → NIfTI
- Converts raw data
- Initializes subject structure

## Step 2 — Canonical anatomy
- Identifies T1/T2/PETRA/ZTE
- Standardizes filenames

## Step 3 — Resampling
- 1 mm isotropic resolution
- T1 required, T2 optional

## Step 4 — SimNIBS (CHARM)
- Generates subject-specific head model
- Produces `m2m_<SUBJECT>`

## Step 5 — Targeting
- MNI → subject coordinate transform
- ROI mask warping
- Optional coordinate-based masks

## Step 6 — QC
- T1–T2 difference image
- Statistical summaries

## Step 7 — pseudo-CT (optional)
- PETRA → CT conversion via MATLAB

## Step 8 — TUS-entry (optional)
- Optimal transducer placement
- Optional trajectory computation

---

# ⚙️ Configuration (BBOP_config.sh)

This is the **only file users must edit**.

---

## ROIs

```bash
ROIS=(caudate_da_rh mfg5_internal_v3)
```

Must match entries in:

```
Raw-Data/Pipeline/BBOP_ROIs.yaml
```

---

## Targeting flags (Step 5)

| Flag | Description |
|------|------------|
| --coords | Convert coordinates |
| --maskwarp | Warp masks |
| --coordmask | Generate spherical masks |
| --all | Enable all |
| --none | Disable targeting |
| --radius-mm R | Sphere radius |

---

## pCT flags (Step 7)

| Flag | Description |
|------|------------|
| --with-pCT | Enable pCT |
| --without-pCT | Disable pCT |

---

## TUS-entry flags (Step 8)

| Flag | Description |
|------|------------|
| --with-TUSentry | Enable |
| --without-TUSentry | Disable |
| --trajectory | Export trajectory |
| --min-cm X | Minimum distance |
| --max-cm Y | Maximum distance |
| --tusentry-dir PATH | Custom toolbox |

---

# 🧩 Dependencies

## Required
- Bash
- FSL
- SimNIBS 4.6
- Python (numpy, nibabel, yaml)
- R (oro.nifti)

## Optional
- MATLAB
- SPM
- petra-to-ct toolbox
- TUS_entry toolbox

---

# 🧪 Environment Check

```bash
./Scripts/BBOP_Pipeline/BBOP_check_environment.sh
```

Validates all dependencies.

---

# 🔁 Reproducibility Features

- Step-wise completion flags
- Idempotent execution
- Automatic skipping of completed steps
- Safe reruns

---

# 🧰 Debugging

Use:

```
BBOP_pipeline_cheatsheet.md
```

for manual step execution and troubleshooting.

---

# 🧠 Design Principles

- Minimal user friction
- Maximum reproducibility
- Clear modular structure
- Graceful failure handling

---

# 📦 Version

BBOP v0.6.1


---

# 📁 Example Subject (ErnieExtended)

A minimal example subject is included for testing and demonstration:

```
Raw-Data/Subjects/ErnieExtended/ses-01/anat/
    ErnieExtended_T1.nii.gz
```

## Purpose

- Allow immediate testing after cloning  
- Validate pipeline structure and execution  
- Demonstrate behavior with minimal input  

## Notes

- This is a **T1-only dataset**  
- Not intended for full simulation workflows  
- Optional steps (T2-based QC, pCT) will be skipped  

## Relation to SimNIBS “Ernie Extended”

This example is conceptually aligned with the *Ernie Extended* dataset:

- MRI/CT-derived head model  
- Commonly used for simulation validation  

References:
- https://pubmed.ncbi.nlm.nih.gov/40800500/  
- https://simnibs.github.io/simnibs/build/html/dataset.html  

## Important Clarification

The public SimNIBS dataset mainly contains **derived head models** (e.g., `m2m_ernie`),  
not the raw anatomical inputs required for full preprocessing.

Therefore, the included T1 serves as a **minimal structural example**, not a full reconstruction dataset.


---

# 🧠 Additional Supported Modalities (ZTE)

BBOP now also detects and stages **ZTE (Zero Echo Time) scans** during Step 2.

## Detection

ZTE files are identified using filename patterns:

```
*zte*.nii
*zte*.nii.gz
```

## Output

Detected ZTE scans are staged as:

```
${SUBJECT}_ZTE_<LABEL>.nii
```

Example:

```
sub-03Elly_ZTE_GENERIC.nii
```

## Behavior

- Supports multiple ZTE files per subject  
- Uses the same variant classification logic as PETRA  
- Handles naming collisions automatically  
- Fully optional — pipeline proceeds if no ZTE is present  

## Implication

ZTE support extends BBOP beyond PETRA-only skull imaging and prepares the pipeline for:

- ZTE-based pseudo-CT workflows  
- Improved compatibility with external datasets  
- Future modality-agnostic preprocessing
