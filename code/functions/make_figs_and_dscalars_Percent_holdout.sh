#!/bin/bash -l

#SBATCH -J figsPCTholdout
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
percent_holdout=${3}
make_NetConfMaps=${4}

module load workbench; 
module load matlab; 

# transform XCP-D motion file to DCAN motion file

# Run code to do k-means clustering and output ciftis
matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); TM_dscalar_compare_across_permutations('${BASEDIR}', '${dscalarswithassignments1}', '${percent_holdout}', ${make_NetConfMaps} ); exit;"


#/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/TM_dscalar_compare_across_files.m