#!/bin/bash -l

#SBATCH -J figsTMsplit
#SBATCH --ntasks=12
#SBATCH --tmp=10gb
#SBATCH --mem=64gb
#SBATCH -t 1:00:00
#SBATCH --mail-type=ALL
#SBATCH -p msismall
#SBATCH -o 
#SBATCH -e 
#SBATCH -A


BASEDIR=${1}
dscalarswithassignments1=${2}
dscalarswithassignments2=${3}
make_NetConfMaps=${4}
outpath=${5}

module load "${WORKBENCH_MODULE}"
module load "${MATLAB_MODULE}"

# 

# Run code to do k-means clustering and output ciftis
matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_files('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', ${make_NetConfMaps},'${outpath}'); exit;"

matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}','${outpath}'); exit;"

#/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/TM_dscalar_compare_across_files.m