# Go to your Scripts folder
cd /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025/Scripts

# Make sure it’s executable
chmod +x BBOP_step8_pipeline_SimNIBS_dyn.sh

# e.g., to run both T1 & T2:
./BBOP_step8_pipeline_SimNIBS_dyn.sh /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 $subject

# or T1-only mode:
./BBOP_step8_pipeline_SimNIBS_dyn.sh /home/franzs95/mnt/cogsci/userdata/juliacrone/2024_BrainzapCreativity/data/TUSMR2025 $subject true
