# 📘 Getting Started

This guide walks you through your first successful BBOP run, from data setup to output interpretation.

## 🧠 Before You Start

You need:
- A project folder created from BBOP
- At least one subject with a T1 scan
- Basic familiarity with the terminal

Minimal input example:
Raw-Data/Subjects/sub-01/ses-01/anat/sub-01_T1.nii.gz

---

## 🧠 How BBOP Works

BBOP is not a single script—it is a **project environment**.

Each project:
- has its own data
- has its own configuration
- runs independently

You run everything via:

./BBOP sub-XXX

The subject ID must match the folder name under Raw-Data/Subjects/.

---

## 📁 Folder Structure

Key directories:

Raw-Data/
  → input data (your MRI)

Analysis/
  → all outputs (automatically created)

Scripts/
  → pipeline logic (do not modify)

Tools/
  → required toolboxes

BBOP_config.sh
  → your only configuration file

  ---

## 🚀 First Run (Example)

### 1. Add your data

Place your anatomical scans here:

Raw-Data/
└── Subjects/
    └── sub-01/
        └── ses-01/
            └── anat/
                └── sub-01_T1.nii.gz

### 2. Configure BBOP

Edit:

BBOP_config.sh

Define:
- ROIs
- flags (optional)

### 3. Check environment

./BBOP --check

### 4. Run pipeline

./BBOP sub-01

Processing time depends on hardware and enabled modules.  
SimNIBS (Step 4) is typically the longest step.

---

## 🔁 What to Expect

BBOP runs multiple steps:

1. NIfTI preparation
2. Canonical anatomy selection
3. Resampling
4. SimNIBS head model
5. Targeting
6. QC
7. (optional) pseudo-CT
8. (optional) TUS-entry

Already completed steps will be skipped automatically.

---

## 📦 Outputs

All results are stored in:

Analysis/Ultrasound/sub-01/

Important outputs:
- MR-cache/
- m2m_sub-01/
- BabelBrain/
- QC/

---

## ⚠️ Common Issues

### Nothing happens
→ BBOP may be skipping steps because they were already completed  
→ Check the terminal output for "Skipping Step X"

### Missing dependencies
→ Run ./BBOP --check

### Files not detected
→ Ensure filenames contain:
   - T1
   - T2
   - PETRA
   - ZTE

---

## 🔁 Re-running BBOP

BBOP is idempotent:

- completed steps are skipped
- you can safely rerun at any time

To force reprocessing:
delete the subject folder in:

Analysis/Ultrasound/