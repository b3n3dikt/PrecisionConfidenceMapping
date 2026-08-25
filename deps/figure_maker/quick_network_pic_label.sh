#!/bin/bash

#This code take in a network dscalar and makes a .png of it in the same directory with the same name
input_dlabel=$1

fileroot_name=`basename ${input_dlabel}`
fileroot_name_short=${fileroot_name::-11}
filedir_name=`dirname ${input_dlabel}`
filegroup_owner=`ls -g ${input_dlabel} | awk '{print $3}'`


echo "visualizing " ${input_dlabel}
echo "on..."
echo "surfaces: "
echo "Conte69.L.very_inflated.32k_fs_LR.surf.gii"
echo "Conte69.R.very_inflated.32k_fs_LR.surf.gii"
echo "volume: "
echo "Conte69_AverageT1w.gii"

echo "using file group permissions of..."
echo ${filegroup_owner}

sg ${filegroup_owner} -c "/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.4.sh ${1} ${fileroot_name_short} ${filedir_name} TRUE 1 18 power_surf TRUE 0.1 30 THRESHOLD_TEST_SHOW_INSIDE TRUE TRUE png 8 118 FALSE /projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command /projects/standard/faird/shared/code/internal/utilities/figure_maker/template_veryinflated_label_MSI.scene /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_label_MSI.scene /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"