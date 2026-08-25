
BASEDIR=/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/Template_Matching/T2fmriPrep10percent/
FIGDIR=${BASEDIR}/figures/AllPerms

# Initial value of n
n=1
thresh=0.8

outall="${FIGDIR}/concat_all_half1_thresh-${thresh}.dscalar.nii"

wb_command -cifti-math "X * 0" ${outall} -var X ${FIGDIR}/Probability_Maps_100_perm_TM_Split_half-1_SCAN_network_probability.dscalar.nii

# Loop through files matching the given pattern
for file in ${FIGDIR}/Probability_Maps_100_perm_TM_Split_half-1_*_network_probability.dscalar.nii; do
  echo "Processing file: $file with multiplier: $n"
  
  base=${file%.dscalar.nii}
  # Append the threshold value and the .dscalar.nii extension to create the output filename
  outfile="${base}_thresholded-${thresh}.dscalar.nii"
  

  wb_command -cifti-math "X > ${thresh}" ${outfile} -var X ${file}
  wb_command -cifti-math "X * ${n}" ${outfile} -var X ${outfile}
  wb_command -cifti-math "X + Y" ${outall} -var X ${outfile} -var Y ${outall}

  # Increase n by 1
  n=$((n + 1))
done





Copy code
#!/bin/bash
n=1
# Loop through files matching the given pattern
for file in ${FIGDIR}/Probability_Maps_100_perm_TM_Split_half-1_*_network_probability.dscalar.nii; do
  n=$(n+1)
  echo "Processing file: $file"
  base=${file%.dscalar.nii}
  # Append the threshold value and the .dscalar.nii extension to create the output filename
  outfile="${base}_thresholded-${thresh}.dscalar.nii"
  wb_command -cifti-math "X > ${thresh}" ${outfile} -var X ${file} 
  wb_command -cifti-math "X * ${n}" ${outfile} -var X ${outfile} 


done