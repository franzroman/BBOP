cd /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025/Scripts/BBOP_Pipeline
   chmod +x BBOP_pipeline_preproc_RUN-command.sh
   chmod +x BBOP_pipeline_preproc.sh
   ./BBOP_pipeline_preproc_RUN-command.sh \
       /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
       KC-PILOT \
       caudate_da_rh mfg5_internal_v3 \
       --without-pCT


./TUSMR_BBOP_step5_command_T1-T2_coreg_ANTS.sh \
    /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
    KC-PILOT

./TUSMR_BBOP_step6_command_T1-T2_coreg_QC.sh \
    /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
    KC-PILOT

./TUSMR_BBOP_pipeline_preproc_RUN-command.sh \
       /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
       KC-PILOT \
       caudate_da_rh mfg5_internal_v3 \
       --without-pCT
       
./BBOP_step8_pipeline_SimNIBS_dyn.sh \
    /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 \
    KC-PILOT
