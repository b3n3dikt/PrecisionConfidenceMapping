#!/bin/bash

#This code take in a network dscalar and makes a .png of it in the same directory with the same name
input_dscalar=$1
labelfile=${2:-TRUE}
lowerthresh=${3:-0}
upperthresh=${4:-1}
colormap=${5:-power_surf}

#input_dscalar=$1
#lowerthresh=${2:-0}
#upperthresh=${3:-1}
#colormap=${4:-power_surf}
fileroot_name=`basename ${input_dscalar}`
fileroot_name_short=${fileroot_name::-12}
filedir_name=`dirname ${input_dscalar}`
filegroup_owner=`ls -g ${input_dscalar} | awk '{print $3}'`
echo "label ${labelfile} lower ${lowerthresh} upper ${upperthresh} colormap ${colormap} fileroot_name ${fileroot_name} fileroot_name_short ${fileroot_name_short} filedir_name ${filedir_name} filegroup_owner ${filegroup_owner}"

echo "visualizing " ${input_dscalar}
echo "on..."
echo "surfaces: "
echo "Conte69.L.very_inflated.32k_fs_LR.surf.gii"
echo "Conte69.R.very_inflated.32k_fs_LR.surf.gii"
echo "volume: "
echo "Conte69_AverageT1w.gii"

echo "using file group permissions of..."
echo ${filegroup_owner}

sg ${faird} -c "/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.4.sh ${1} ${fileroot_name_short} ${filedir_name} ${labelfile} ${lowerthresh} ${upperthresh} ${colormap} TRUE 0.1 30 THRESHOLD_TEST_SHOW_INSIDE TRUE TRUE png 8 118 FALSE /projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_scalar_MSI.scene /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"




#input is dscalar -- FEZ EDITS: change to use shift in order to ensure all arguments will work on all platforms, also added new variable inputs, will convert to parameter file following gregorization
subjectscalar=${1}; shift #full path to subject .dscalar
shortfilename=${1}; shift # short output file name excluding the scene file.
outputfolder=${1}; shift # path to output folder
label=${1}; shift # set to TRUE if continous data, palette is assumed to be Power Colors.  If true, scene file will use RBG colors.
continuous_lower=${1}; shift # lower scale limit for color palette
continuous_upper=${1}; shift # upper scale limit for color palette
PaletteName=${1}; shift # supply the name of the color palette: options are: ROY-BIG-BL, videen_style, Gray_Interp_Positive, Gray_Interp, PSYCH, RBGYR20, RBGYR20P, Orange-Yellow, POS_NEG_ZERO,red-yellow, 
