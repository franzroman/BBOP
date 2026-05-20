# BBOP Preprocessing Pipeline (v0.6.3 – Extended)

**DOI:** [10.5281/zenodo.20308891](https://doi.org/10.5281/zenodo.20308891)

---

BBOP (**BabelBrain and Brainsight-Oriented Preprocessing**) is a modular, reproducible preprocessing pipeline designed for **transcranial ultrasound (TUS)** workflows.

It integrates MRI preprocessing, head modeling, ROI targeting, and optional acoustic planning into a single, structured environment.

---

# 🚀 Quick Start

```bash
git clone https://github.com/franzroman/BBOP.git MyStudy_BBOP
cd MyStudy_BBOP
nano BBOP_config.sh
./BBOP --check
./BBOP sub-XXX
```

- Replace `MyStudy_BBOP` with your project/study name.

- 💡 Run `./BBOP --check` to verify your environment before processing data.

- Replace "sub-XXX" with your subject ID (e.g., sub-01).

- Edit `BBOP_config.sh`. This can be done with any text editor (e.g., VS Code).

**That is the entire user workflow.**

---

## 📘 Full Walkthrough

For a detailed step-by-step guide, see:

[BBOP Walkthrough](docs/getting_started.md)

## ⏱ Runtime

The following runtimes are representative example runs and may vary substantially across systems and datasets.

### Example Runtime 1 — NIfTI input (T1 + T2)

Subject: `sub-Chen01-7T`  
Input: T1 and T2 (NIfTI)  
System: Apple Mac M4 Pro (48 GB RAM)

| Step | Description              | Runtime |
|------|--------------------------|--------|
| 1    | DICOM → NIfTI prep       | ~0 s   |
| 2    | Canonical anatomy        | ~0 s   |
| 3    | Resampling (1 mm)        | ~4 s   |
| 4    | SimNIBS (CHARM)          | ~29 min |
| 5    | Targeting                | ~11 s  |
| 6    | QC                       | ~2 s   |
| 7    | pCT (optional)           | skipped |
| 8    | TUS-entry                | ~2 min 45 s |

**Total runtime:** ~32 minutes  

---

### Example Runtime 2 — DICOM input (T1 + T2 + PETRA)

Subject: `sub-KC_PILOT`  
Input: T1, T2, and PETRA (DICOM)

| Step | Description              | Runtime |
|------|--------------------------|--------|
| 1    | DICOM → NIfTI prep       | ~0 s   |
| 2    | Canonical anatomy        | ~1 s   |
| 3    | Resampling (1 mm)        | ~2 s   |
| 4    | SimNIBS (CHARM)          | ~35 min |
| 5    | Targeting                | ~14 s  |
| 6    | QC                       | ~3 s   |
| 7    | pCT (optional)           | skipped |
| 8    | TUS-entry                | ~12 min 50 s |

**Total runtime:** ~48 minutes  

---

> 💡 SimNIBS (Step 4) is the main computational bottleneck.

> ⚠️ Runtime varies depending on hardware, input modality (NIfTI vs DICOM), and enabled modules.

---

# ⚠️ What changed in v0.6.3

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

![BBOP Flowchart](BBOP_flowchart.svg)

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

BBOP v0.6.3


---

# 📁 Example Datasets

BBOP includes representative example datasets for testing and demonstration purposes.

## Included Data

The example subjects are selected to reflect common use cases in TUS preprocessing workflows:

- **T1 + T2 dataset**  
  → enables multimodal head model generation and QC
  → from Chen et al. (2023): https://doi.org/10.1038/s41597-023-02400-y 

- **Preprocessed head model dataset (SimNIBS)**  
  → demonstrates compatibility with existing simulation environments
  → from Lepping et al. (2016): https://doi.org/10.1177/0305735615604509 via SimNIBS Group Dataset

These datasets are minimally adapted to match the BBOP directory structure and naming conventions.

---

## Purpose

The example datasets are provided to:

- Allow immediate testing after cloning  
- Validate pipeline structure and execution  
- Demonstrate behavior across different data scenarios  
- Facilitate reproducible onboarding  

---

## Notes

- Datasets represent **different levels of preprocessing completeness**  
- Not all optional steps (e.g., pCT, TUS-entry) will run for all datasets  
- Some datasets may already contain derived outputs (e.g., head models)  

---

## Relation to External Datasets

The included examples are derived from publicly available datasets used to evaluate BBOP:

- Multimodal MRI dataset (T1 + T2, 3T / 7T)  
- SimNIBS dataset with precomputed head models  

These datasets were selected to demonstrate BBOP’s robustness across:

1. Minimal structural input (T1-only)  
2. Multimodal MRI preprocessing  
3. Integration with preprocessed simulation environments  

---

## Important Clarification

The example datasets are intended for:

- **testing and demonstration**
- **workflow validation**

They are **not intended as full experimental datasets** for TUS simulations.

Users should provide their own study-specific data for actual experiments.

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

---

# Acknowledgements and Contributions

The trajectory file export functionality of Step 8 is an extension of the TUS_entry toolbox developed by Cyril Atkinson-Clement.