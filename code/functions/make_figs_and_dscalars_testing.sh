#!/bin/bash -l

#SBATCH -J figsTMsplit
#SBATCH --ntasks=4
#SBATCH --mem=8gb
#SBATCH -t 00:40:00
#SBATCH --mail-type=NONE
#SBATCH -p msismall,ag2tb,ramtough
#SBATCH -o ./output_logs/FigsBANC_%A_%a.out
#SBATCH -e ./output_logs/FigsBANC_%A_%a.err
#SBATCH -A bart

BASEDIR=${1}
dscalarswithassignments1=${2}
dscalarswithassignments2=${3}
ConfMap=${4}
outpath=${5}
network_name=${6}
threshold=${7}
thresholdTarget=${8}
fig_dir=${9}

echo "${BASEDIR} ${dscalarswithassignments1} ${dscalarswithassignments2} ${ConfMap} ${outpath} ${network_name} ${threshold} ${thresholdTarget} ${fig_dir}"
module load workbench/1.5.0
module load matlab

echo "matlab -nodisplay -nosplash -r \"addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', ${ConfMap}, ${threshold}, '${thresholdTarget}', '${fig_dir}'); exit;\""
matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', ${ConfMap}, ${threshold}, '${thresholdTarget}', '${fig_dir}'); exit;"

echo "matlab -nodisplay -nosplash -r \"addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${ConfMap}, '${outpath}'); exit;\""
matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${ConfMap}, '${outpath}'); exit;"


# #!/bin/bash -l

# #SBATCH -J figsTMsplit
# #SBATCH --ntasks=12
# #SBATCH --tmp=10gb
# #SBATCH --mem=64gb
# #SBATCH -t 00:30:00
# #SBATCH --mail-type=NONE
# #SBATCH -p msismall,ag2tb,ramtough
# #SBATCH -o /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/code/wrappers/output_logs/FigsBANC_%A_%a.out
# #SBATCH -e /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/code/wrappers/output_logs/FigsBANC_%A_%a.err
# #SBATCH -A smnelson

# BASEDIR=${1}
# dscalarswithassignments1=${2}
# dscalarswithassignments2=${3}
# make_NetConfMaps=${4}
# outpath=${5}
# network_name=${6}
# threshold=${7}
# thresholdTarget=${8}
# fig_dir=${9}

# module load workbench/1.5.0
# module load matlab

# matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', '${make_NetConfMaps}', ${threshold}, '${thresholdTarget}','${fig_dir}'); exit;"

# # Run code to do k-means clustering and output ciftis
# matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${make_NetConfMaps},'${outpath}'); exit;"



# #!/bin/bash -l

# #SBATCH -J figsTMsplit
# #SBATCH --ntasks=12
# #SBATCH --tmp=10gb
# #SBATCH --mem=64gb
# #SBATCH -t 00:30:00
# #SBATCH --mail-type=NONE
# #SBATCH -p msismall,ag2tb,ramtough
# #SBATCH -o /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/code/wrappers/output_logs/FigsBANC_%A_%a.out
# #SBATCH -e /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/code/wrappers/output_logs/FigsBANC_%A_%a.err
# #SBATCH -A smnelson


# BASEDIR=${1}
# dscalarswithassignments1=${2}
# dscalarswithassignments2=${3}
# make_NetConfMaps=${4}
# outpath=${5}
# network_name=${6}
# threshold=${7}
# thresholdTarget=${8}
# fig_dir=${9}


# module load workbench/1.5.0; 
# module load matlab; 

# # 

# #echo "matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', '${make_NetConfMaps}', ${threshold}, '${thresholdTarget}','${fig_dir}'); exit;""
# matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', '${make_NetConfMaps}', ${threshold}, '${thresholdTarget}','${fig_dir}'); exit;"

# # Run code to do k-means clustering and output ciftis
# matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${make_NetConfMaps},'${outpath}'); exit;"

# #echo "matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${make_NetConfMaps},'${outpath}'); exit;""

# # matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}','${outpath}'); exit;"

# #/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/TM_dscalar_compare_across_files.m