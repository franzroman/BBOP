# BBOP Pipeline Cheat Sheet

**Purpose**  
Manual execution of individual BBOP pipeline steps for **debugging and development**.

**Important**
- This file is **not used by the pipeline itself**.
- It is intended for **manual testing or troubleshooting**.
- The canonical way to run the pipeline is via the wrapper:

```
BBOP_pipeline_preproc_RUN-command.sh
```

Pipeline compatibility: **BBOP v0.4.x+ / v0.5.x**

---

## Session Setup

```bash
# Base directory
BASE_DIR="/Volumes/T9_XF/Studies/BASE_DIR_BBOP"

# Subject
SUB=sub-ID

# ROIs
ROIS=(ROI01 ROI02)

# Load BBOP configuration
source "$BASE_DIR/Scripts/BBOP_Pipeline/BBOP_setup.sh"

# Activate Python environment
source ~/bbop-venv/bin/activate

# Enter pipeline directory
cd "$PIPE"
chmod +x *.sh
```

---

# Whole Pipeline (Recommended)

```bash
./BBOP_pipeline_preproc_RUN-command.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"   --without-pCT   --coords --coordmask   --with-TUSentry
```

### Example with distance override

```bash
./BBOP_pipeline_preproc_RUN-command.sh   "$BASE_DIR"   "$SUB"   caudate_da_rh mfg5_internal_v3   --without-pCT   --all   --with-TUSentry   --min-cm 0.5 --max-cm 3.0
```

---

# Individual Pipeline Steps (Debugging Only)

These commands execute steps **individually** and may bypass safety checks in the wrapper pipeline.

---

## Step 1 — dcm2nii-prep

```bash
./BBOP_step1_command_dcm2nii-prep.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"
```

---

## Step 2 — nii-prep

```bash
./BBOP_step2_command_nii-prep.sh   "$BASE_DIR"   "$SUB"
```

---

## Step 3 — resample-iso1mm

```bash
./BBOP_step3_command_resample-isotropic.sh   "$BASE_DIR"   "$SUB"
```

---

## Step 4 — SimNIBS

```bash
./BBOP_step4_command_SimNIBS_dyn.sh   "$BASE_DIR"   "$SUB"
```

---

## Step 5 — targeting-dynamic

```bash
./BBOP_step5_command_targeting_dynamic.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"   --all
```

### Example targeting

```bash
./BBOP_step5_command_targeting_dynamic.sh   "$BASE_DIR"   "$SUB"   caudate_da_rh mfg5_internal_v3   --all
```

### Example coordmask with explicit radius

```bash
./BBOP_step5_command_targeting_dynamic.sh   "$BASE_DIR"   "$SUB"   mfg5_internal_v3   --coordmask --radius-mm 4
```

---

## Step 6 — T1/T2 QC

```bash
./BBOP_step6_command_T1-T2_coreg_QC.sh   "$BASE_DIR"   "$SUB"
```

---

## Step 7 — PETRA → pseudo-CT

```bash
./BBOP_step7_command_create-pCT.sh   "$BASE_DIR"   "$SUB"
```

---

## Step 8 — TUS-entry

```bash
./BBOP_step8_command_TUS-entry.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"   --trajectory
```

### Example with distance override

```bash
./BBOP_step8_command_TUS-entry.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"   --min-cm 0.5 --max-cm 3.0
```

### Example with explicit toolbox path

```bash
./BBOP_step8_command_TUS-entry.sh   "$BASE_DIR"   "$SUB"   "${ROIS[@]}"   --tusentry-dir /home/franzs95/tools/TUS_entry
```

---

# Notes

- The **recommended workflow** is to run the pipeline through the wrapper.
- Individual step execution should only be used for **debugging or development**.
