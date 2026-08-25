#!/bin/sh

#This code is designed to read a dscalar, load it onto a very inflated surface model, and automatically output a png.
#Written by Robert Hermosillo, modified by Eric Feczko

#v5 - added subcortical pictures


#input is dscalar -- FEZ EDITS: change to use shift in order to ensure all arguments will work on all platforms, also added new variable inputs, will convert to parameter file following gregorization
subjectscalar=${1}; shift #full path to subject .dscalar
shortfilename=${1}; shift # short output file name excluding the scene file.
outputfolder=${1}; shift # path to output folder
label=${1}; shift # set to TRUE if continous data, palette is assumed to be Power Colors.  If true, scene file will use RBG colors.
continuous_lower=${1}; shift # lower scale limit for color palette
continuous_upper=${1}; shift # upper scale limit for color palette
PaletteName=${1}; shift # supply the name of the color palette: options are: ROY-BIG-BL, videen_style, Gray_Interp_Positive, Gray_Interp, PSYCH, RBGYR20, RBGYR20P, Orange-Yellow, POS_NEG_ZERO,red-yellow, blue-lightblue, FSL,
			# power_surf, fsl_red, fsl_green, fsl_blue, fsl_yellow, JET256, PSYCH, PSYCH-NO-NONE, ROY-BIG, clear_brain, fidl, raich4_clrmid, raich6_clrmid, HSB8_clrmid, POS_NEG

threshold_image=${1}; shift # set TRUE if you want to exclude data outside/inside thresholds, palette is assumed to be Power Colors.  If true, scene file will use RBG colors.
threshold_lower=${1}; shift # lower threshold for color palette
threshold_upper=${1}; shift # upper threshold for color palette
threshold_inout=${1}; shift # Threshold set "inside" or "outside"
make_quad=${1}; shift # Make DV view.
make_subcorticals=${1}; shift  # creates new images that show PA (parasaggital), CO (coronal), and AX (axial) views.
image_extension=${1}; shift  # provide an image extension (e.g. jpeg, tiff, png, etc).
width_in_cm=${1}; shift # provide the width in cm. 8 cm by default.
dpcm=${1}; shift #dots per centimeter. Use 118 for 300 dpi.
save_scene_file=${1}; shift #Set to TRUE whether or not you want to save the scene file. Helpful for debugging.
wb_command=${1}; shift #path to wb_command, will be overwritten by defaults

#subsequent uses are for advanced usage -- not all variables need to be specified
temp_scene=${1}; shift #the path to the template scene file to use as a default for making a new scene file
temp_scene_sub=${1}; shift # added to version 9.3. the path to the template SUBCORTICAL scene file to use as a default for making a new scene file
left_surface_path=${1}; shift # added to version 9.3. Provide a specified path to the left surface file.
right_surface_path=${1}; shift # added to version 9.3. Provide a specified path to the right surface file.

templatefile=${1}; shift #the first default dscalar file found in a scene -- replaced by the new dscalar file specified by the user
templatefolder=${1}; shift #the path to the directory containing the template file
old_templatefolder=${1}; shift #the path to the directory containing the second template file
old_templatefile=${1}; shift #the second template dscalar file specified in the template scene file
templatescenename=${1}; shift #the default scene name found within the template scene file, will be replaced with the new scene
continuous_upper_default=${1}; shift #the default value for the color palette upper scale limit, will be replaced with the new value
continuous_lower_default=${1}; shift #the default value for the color palette lower scale limit, will be replaced with the new value
threshold_image_default=${1}; shift #the default value whether the thresholding will be visualized, will be replaced with the new value
threshold_lower_default=${1}; shift #the default value for the color palette lower threshold, will be replaced with the new value
threshold_upper_default=${1}; shift #the default value for the color palette upper threshold, will be replaced with the new value
threshold_inout_default=${1}; shift #the default value for the binary in/out threshold, will be replaced with the new value
PaletteName_default=${1}; shift # #the default name for the palette.
continuous_smaller_negative_value=${1}; shift #the default value for the smaller negative on the continuous scale
continuous_smaller_positive_value=${1}; shift #the default value for the smaller positive on the continuous scale
image_extension_default=${1}; shift  # provide an image extension (e.g. jpeg, tiff, png, etc).
save_scene_file_default=${1}; shift #provide a default TRUE/FALSE option for whether of not to save the scene file.
left_surface_path_default=${1}; shift # provide a default path to the left surface file
right_surface_path_deafult=${1}; shift # provide a default path to the right surface file
dpcm_default=118 # pixels per cm that corresponds with 300 dpi.


#FEZ EDITS: set defaults for important variables to ensure backwards compatability
wb_command=${wb_command:-"/home/exacloud/lustre1/fnl_lab/code/external/utilities/workbench-1.2.3-HCP/bin_rh_linux64/wb_command"}
image_extension_default="png"
width_in_cm_default="8"
outputfilename=${outputfolder}/${shortfilename}.scene
shortscenename=${shortfilename}"_scene"
image_file_name=${outputfolder}/${shortfilename}.${image_extension}
continuous_smaller_negative_value=${continuous_smaller_negative_value:-"-33.333000"}
continuous_smaller_positive_value=${continuous_smaller_positive_value:-"11.111000"}


pix_width=`expr $width_in_cm \* $dpcm` #calculate the pixel width based on the size in cm x the dpcm
pix_height_dec=`echo "var=$pix_width*0.5481;var" | bc` # calculate the height based on a prefined ratio.
pix_height=`echo "($pix_height_dec+0.5)/1" | bc` # round value to nearest pixel.




if [ -z "$dpcm" ]; then 
dpcm=${dpcm_default};
fi


if [ "${label}" = FALSE ]; then 
	#Reference Scene file:
	#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_very_inflated_continous.scene
	#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_scene.scene
	#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_DV.scene
	#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_quad_scaled.scene
	#temp_scene=${temp_scene:-"/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_quad_scaled_v3_legend_fixed.scene"}
	temp_scene=${temp_scene:-"/projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene"}
	templatefile=${templatefile:-"ABCD_10min_GRP1_singlenet_percentage_n2988_Aud_network_percentage.dscalar.nii"}
	templatefolder=${templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/"}
	old_templatefolder=${old_templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/n1800_old/"}
	old_templatefile=${old_templatefile:-"ABCD_10min_GRP1_overlap_percentage_n1800_Aud_network_percentage.dscalar.nii"}
	templatescenename=${templatescenename:-"MSC01_template_scene"}
	
	#Scale values	

	continuous_pos_default=${continuous_pos_default:-"true</DisplayPositiveData>"}
	continuous_zero_default=${continuous_zero_default:-"false</DisplayZeroData>"}
	continuous_neg_default=${continuous_neg_default:-"false</DisplayNegativeData>"}

	#threshold_image_default=${threshold_image_default:-"THRESHOLD_TYPE_OFF"}
	threshold_image_default=${threshold_image_default:-"THRESHOLD_TYPE_NORMAL"}
	threshold_lower_default=${threshold_lower_default:-"55.555000"}
	threshold_upper_default=${threshold_upper_default:-"66.666000"}
	threshold_inout_default=${threshold_inout_default:-"THRESHOLD_TEST_SHOW_OUTSIDE"}
	PaletteName_default=${PaletteName_default:-"ROY-BIG-BL"}

	left_surface_path=${left_surface_path:-"/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii"}
	right_surface_path=${right_surface_path:-"/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"}

else
	echo "Using label file options."
	#Reference Scene file:
	temp_scene=${temp_scene:-"/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/template_veryinflated_label.scene"}
	templatefile=${templatefile:-"placeholder.dlabel.nii"}
	templatefolder=${templatefolder:-"/place_holder_path/"}
	templatescenename=${templatescenename:-"placeholder_template_scene"}
	old_templatefolder=${old_templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/n1800_old/"}
	old_templatefile=${old_templatefile:-"ABCD_10min_GRP1_overlap_percentage_n1800_Aud_network_percentage.dscalar.nii"}

	left_surface_path=${left_surface_path:-"/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii"}
	right_surface_path=${right_surface_path:-"/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"}


fi

echo "WB_command is: "
echo ${wb_command}
echo "temp_scene is:"
echo ${temp_scene}
echo "temp_scene_sub is:"
echo ${temp_scene_sub}


echo "left_surface_path:"
echo ${left_surface_path}

echo "right_surface_path:"
echo ${right_surface_path}



#START
subjectfilename=$(basename "${subjectscalar}")
subjectfoldername=$(dirname "${subjectscalar}")/


echo 'cp ' $temp_scene "$outputfilename"
        cp  $temp_scene "$outputfilename"

#for i in `seq 0 5`;
#       do
            #replace templated pathnames and filenames in scene
            #sed -i "s!${templates[$i]}_PATH!${paths[$i]}!g" $temp_scene
            #filename=$(basename "${paths[$i]}")
            #sed -i "s!${templates[$i]}_NAME!${filename}!g" $temp_scene
#        done

#replace templated pathnames and filenames in scene
#sed -i "s/${template_file/${subjectscalar}/g" ${outputfilename}
	

## FIX here for multiple file names present in template file. EF EDIT: START WITH OLD TEMPLATE SINCE IT WILL CAUSE ERRORS
#if [ "${label}" = FALSE ]; then 
	echo "Replacing instances of: ${old_templatefolder} with ${subjectfoldername}"
	kathy19=${old_templatefolder}
	kathy20=${subjectfoldername}
	sed -i "s,${kathy19},${kathy20},g" "$outputfilename"

	echo "Replacing instances of: ${old_templatefile} with ${subjectfilename}"
	kathy21=${old_templatefile}
	kathy22=${subjectfilename}
	sed -i "s,${kathy21},${kathy22},g" "$outputfilename"
#fi


echo "Replacing instances of: ${templatefolder} with ${subjectfoldername}"
kathy=${templatefolder}
kathy2=${subjectfoldername}
#sed -i "s!${templatefolder}_PATH!${subjectfoldername}!g" $outputfilename
sed -i "s,${kathy},${kathy2},g" "$outputfilename"


echo "Replacing instances of: ${templatefile} with ${subjectfilename}"
kathy3=${templatefile}
kathy4=${subjectfilename}
sed -i "s,${kathy3},${kathy4},g" "$outputfilename"



echo "Modifying scene name instances of: ${templatescenename} with ${shortscenename}"
kathy5=${templatescenename//\//\\/}
kathy6=${shortscenename//\//\\/}
sed -i 's,'"${kathy5}"','"${kathy6}"',g' "$outputfilename"



if [ "${label}" = FALSE ]; then #scale
	#if (( $continuous_lower_default < 0 )); then 
	if (( $(echo "$continuous_lower >= 0"| bc -l) )) && (( $(echo "$continuous_upper > 0"| bc -l) )); then  #-lt = "less than". If the lower or upper limit both positive, turn on zero and turn off negative in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with true</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="true</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with true</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="true</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with false</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="false</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename"
			continuous_lower_default=${continuous_lower_default:-"11.111000"}
			continuous_upper_default=${continuous_upper_default:-"44.444000"}

	fi

	if (( $(echo "$continuous_lower < 0"| bc -l) )) && (( $(echo "$continuous_upper > 0"| bc -l) )); then  #-lt = "less than". If the lower is negative and the upper is positive, turn on everything in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with true</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="true</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with true</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="true</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with true</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="true</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename"
			
			echo "Replace scene smallest negative value: " ${continuous_smaller_negative_value} "with 0"
			kathy_smallnega=${continuous_smaller_negative_value}
			kathy_smallnegb="0"
			sed -i 's,'"${kathy_smallnega}"','"${kathy_smallnegb}"',g' "$outputfilename"

			echo "Replace scene smallest positive value: " ${continuous_smaller_positive_value} "with 0"
			kathy_smallposa=${continuous_smaller_positive_value}
			kathy_smallposb="0"
			sed -i 's,'"${kathy_smallposa}"','"${kathy_smallposb}"',g' "$outputfilename"

			continuous_lower_default=${continuous_lower_default:-"-22.222000"}
			continuous_upper_default=${continuous_upper_default:-"44.444000"}
	fi

	if (( $(echo "$continuous_lower < 0"| bc -l) )) && (( $(echo "$continuous_upper <= 0"| bc -l) )); then  #-lt = "less than". If the lower and upper limit are negative, turn off positive+zero in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with false</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="false</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with false</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="false</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with true</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="true</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename"
			continuous_lower_default=${continuous_lower_default:-"-22.222000"}
			continuous_upper_default=${continuous_upper_default:-"-33.333000"}
	fi

	echo "Replace scene lower scale value: ${continuous_lower_default} with ${continuous_lower}"
	kathy7=${continuous_lower_default}
	kathy8=${continuous_lower}
	sed -i "s,"${kathy7}","${kathy8}",g" "$outputfilename"
	#sed -i 's,'"${continuous_lower_default}"','"${continuous_lower}"',g' "$outputfilename"

	echo "Replace scene upper scale value: ${continuous_upper_default} with ${continuous_upper}"
	kathy9=${continuous_upper_default}
	kathy10=${continuous_upper}
	sed -i "s,"${kathy9}","${kathy10}",g" "$outputfilename"

	#check supplied scale values to see if negative values should be shown.
	echo "checking range for display values in scene file"

		#if [ -z ${var+x} ]; then 
		if [ -z "$PaletteName" ]; then 
		echo "PaletteName is unset.  Using ROY-BIG-BL"; 


		else 
		echo "PaletteName name specified is '$PaletteName'"; 

		echo "Replacing scene Palette value: ${PaletteName_default} with "${PaletteName}"" 
		kathy23=${PaletteName_default//\//\\/}
		kathy24=${PaletteName//\//\\/}
		sed -i 's,'"${kathy23}"','"${kathy24}"',g' "$outputfilename"
		fi

	if [ "${threshold_image}" = TRUE ]; then #threshold
		echo "threshold setting is: " ${threshold_image}
		echo "Replace scene Threshold value: ${threshold_image_default} with "THRESHOLD_TYPE_NORMAL"" 
		kathy11=${threshold_image_default//\//\\/}
		kathy12=THRESHOLD_TYPE_NORMAL
		sed -i 's,'"${kathy11}"','"${kathy12}"',g' "$outputfilename"

		echo "Replace scene Threshold value: ${threshold_lower_default} with ${threshold_lower}" 
		kathy13=${threshold_lower_default//\//\\/}
		kathy14=${threshold_lower//\//\\/}
		sed -i 's,'"${kathy13}"','"${kathy14}"',g' "$outputfilename"

		echo "Replace scene Threshold value: ${threshold_upper_default} with ${threshold_upper}" 
		kathy15=${threshold_upper_default//\//\\/}
		kathy16=${threshold_upper//\//\\/}
		sed -i 's,'"${kathy15}"','"${kathy16}"',g' "$outputfilename"
	
		echo "Replace scene Threshold value: ${threshold_inout_default} with ${threshold_inout}" 
		kathy17=${threshold_inout_default//\//\\/}
		kathy18=${threshold_inout//\//\\/}
		sed -i 's,'"${kathy17}"','"${kathy18}"',g' "$outputfilename"
	else

	echo "threshold setting is: " ${threshold_image}
		echo "Replace scene Threshold value: ${threshold_image_default} with "THRESHOLD_TYPE_OFF"" 
		kathy11_threshoff=${threshold_image_default//\//\\/}
		kathy12_threshoff=THRESHOLD_TYPE_OFF
		sed -i 's,'"${kathy11_threshoff}"','"${kathy12_threshoff}"',g' "$outputfilename"

	fi

fi


echo "WB_command is: "
echo ${wb_command}
echo "temp_scene is:"
echo ${temp_scene}
echo "temp_scene_sub is:"
echo ${temp_scene_sub}


echo "left_surface_path:"
echo ${left_surface_path}

echo "right_surface_path:"
echo ${right_surface_path}




#Create and image
#        out=$1
#       scenenum=$2
#       temp_scene=${ProcessedFiles}/image_template_temp.scene
#        echo "Calling wb_command as follows:"
#        echo "      ${wb_command} -show-scene ${temp_scene} ${scenenum} ${out} 900 800 > /dev/null 2>&1"
#        ${wb_command} -show-scene ${temp_scene} ${scenenum} ${out} 900 800 > /dev/null 2>&1

	if [ "${make_quad}" = TRUE ]; then #make DV
		echo "Generating Dorsal-Ventral pics"
        	echo "Calling wb_command as follows:"
        	echo "      ${wb_command} -show-scene ${outputfilename} ${shortscenename} ${image_file_name} ${pix_width} ${pix_height} "
        	${wb_command} -show-scene ${outputfilename} ${shortscenename} ${image_file_name} ${pix_width} ${pix_height}

	else
        	echo "Calling wb_command as follows:"
        	echo "      ${wb_command} -show-scene ${outputfilename} ${shortscenename} ${image_file_name} 944 710 "
        	${wb_command} -show-scene ${outputfilename} ${shortscenename} ${image_file_name} 944 710
fi

if [ "${save_scene_file}" = FALSE ]; then #save scene file?
rm -f ${outputfilename} #remove scene file when done.
fi


if [ "${make_subcorticals}" = TRUE ]; then 
	outputfilename_sub=${outputfolder}/${shortfilename}_sub.scene

	shortscenename_PA=${shortfilename}"_scene_PA"
	shortscenename_AX=${shortfilename}"_scene_AX"
	shortscenename_CO=${shortfilename}"_scene_CO"

	image_file_name_PA=${outputfolder}/${shortfilename}_PA.${image_extension}
	image_file_name_AX=${outputfolder}/${shortfilename}_AX.${image_extension}
	image_file_name_CO=${outputfolder}/${shortfilename}_CO.${image_extension}

	pix_width_sub=`expr $width_in_cm \* $dpcm` #calculate the pixel width based on the size in cm x the dpcm
	pix_height_dec_sub=`echo "var=$pix_width_sub*0.4881;var" | bc` # calculate the height based on a prefined ratio.
	pix_height_sub=`echo "($pix_height_dec_sub+0.5)/1" | bc` # round value to nearest pixel.


	if [ "${label}" = FALSE ]; then
    echo "Label is set to FALSE in subcortical section."
		#Reference Scene file:
		#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_very_inflated_continous.scene
		#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_scene.scene
		#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_DV.scene
		#temp_scene=/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_quad_scaled.scene
		temp_scene_sub=${temp_scene_sub:-"/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_scene_subcort.scene"}
		templatefile=${templatefile:-"ABCD_10min_GRP1_singlenet_percentage_n2988_Aud_network_percentage.dscalar.nii"}
		templatefolder=${templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/"}
		old_templatefolder=${old_templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/n1800_old/"}
		old_templatefile=${old_templatefile:-"ABCD_10min_GRP1_overlap_percentage_n1800_Aud_network_percentage.dscalar.nii"}

		templatescenename_PA=${templatescenename_PA:-"MSC01_template_scene_PA"}
		templatescenename_AX=${templatescenename_AX:-"MSC01_template_scene_AX"}
		templatescenename_CO=${templatescenename_CO:-"MSC01_template_scene_CO"}
	
		#Scale values	
		continuous_lower_default=${continuous_lower_default:-"-22.222000"}
		continuous_upper_default=${continuous_upper_default:-"44.444000"}

		continuous_pos_default=${continuous_pos_default:-"true</DisplayPositiveData>"}
		continuous_zero_default=${continuous_zero_default:-"false</DisplayZeroData>"}
		continuous_neg_default=${continuous_neg_default:-"false</DisplayNegativeData>"}
	
		threshold_image_default_sub=${threshold_image_default_sub:-"THRESHOLD_TYPE_NORMAL"}
		threshold_lower_default=${threshold_lower_default:-"55.555000"}
		threshold_upper_default=${threshold_upper_default:-"66.666000"}
		threshold_inout_default=${threshold_inout_default:-"THRESHOLD_TEST_SHOW_OUTSIDE"}
	
	else
		#Reference Scene file:
		#echo "Subcortical images are not yet supported for categorical (non-continuous) data."
		echo "Label is set to TRUE in subcortical section."
		temp_scene_sub=${temp_scene_sub:-"/home/exacloud/lustre1/fnl_lab/code/internal/utilities/make_dscalar_pics/MSC01_template_scene_subcort_label_MSI.scene"}
		#templatefile=${templatefile:-"example.dlabel.nii"}
		templatefile_sub=${templatefile_sub:-"example_VIS_DAN_only.dlabel.nii"}
		echo ${templatefile_sub}
		#templatefolder=${templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/"}
		templatefolder_sub=${templatefolder_sub:-"/home/exacloud/lustre1/fnl_lab/projects/ABCD_net_template_matching/best10_ABCDsubs/VIS_DAN_only_labels/"}
		echo ${templatefolder_sub}
		old_templatefolder=${old_templatefolder:-"/home/exacloud/lustre1/fnl_lab/code/internal/analyses/compare_matrices/ABCD_percentage_maps/n1800_old/"}
		old_templatefile=${old_templatefile:-"ABCD_10min_GRP1_overlap_percentage_n1800_Aud_network_percentage.dscalar.nii"}

		templatescenename_PA=${templatescenename_PA:-"MSC01_template_scene_PA"}
		templatescenename_AX=${templatescenename_AX:-"MSC01_template_scene_AX"}
		templatescenename_CO=${templatescenename_CO:-"MSC01_template_scene_CO"}

		#Scale values	
		continuous_lower_default=${continuous_lower_default:-"-22.222000"}
		continuous_upper_default=${continuous_upper_default:-"44.444000"}

		continuous_pos_default=${continuous_pos_default:-"true</DisplayPositiveData>"}
		continuous_zero_default=${continuous_zero_default:-"false</DisplayZeroData>"}
		continuous_neg_default=${continuous_neg_default:-"false</DisplayNegativeData>"}
	
		threshold_image_default_sub=${threshold_image_default_sub:-"THRESHOLD_TYPE_NORMAL"}
		threshold_lower_default=${threshold_lower_default:-"55.555000"}
		threshold_upper_default=${threshold_upper_default:-"66.666000"}
		threshold_inout_default=${threshold_inout_default:-"THRESHOLD_TEST_SHOW_OUTSIDE"}

	fi



	#START
	subjectfilename=$(basename "${subjectscalar}")
	subjectfoldername=$(dirname "${subjectscalar}")/
	
	
	echo 'cp ' $temp_scene_sub "$outputfilename_sub"
	        cp  $temp_scene_sub "$outputfilename_sub"

	#for i in `seq 0 5`;
	#       do
        	    #replace templated pathnames and filenames in scene
        	    #sed -i "s!${templates[$i]}_PATH!${paths[$i]}!g" $temp_scene_sub
        	    #filename=$(basename "${paths[$i]}")
        	    #sed -i "s!${templates[$i]}_NAME!${filename}!g" $temp_scene_sub
	#        done
	
	#replace templated pathnames and filenames in scene
	#sed -i "s/${template_file/${subjectscalar}/g" ${outputfilename_sub}
	
	## FIX here for multiple file names present in template file. EF EDIT: START WITH OLD TEMPLATE SINCE IT WILL CAUSE ERRORS
	echo "Replacing instances of: ${old_templatefolder} with ${subjectfoldername}"
	kathy19=${old_templatefolder}
	kathy20=${subjectfoldername}
	sed -i "s,${kathy19},${kathy20},g" "$outputfilename_sub"

	echo "Replacing instances of: ${old_templatefile} with ${subjectfilename}"
	kathy21=${old_templatefile}
	kathy22=${subjectfilename}
	sed -i "s,${kathy21},${kathy22},g" "$outputfilename_sub"

	echo "Replacing instances of: ${templatefolder_sub} with ${subjectfoldername}"
	kathy=${templatefolder_sub}
	kathy2=${subjectfoldername}
	#sed -i "s!${templatefolder_sub}_PATH!${subjectfoldername}!g" $outputfilename_sub
	sed -i "s,${kathy},${kathy2},g" "$outputfilename_sub"
	
	
	echo "Replacing instances of: ${templatefile_sub} with ${subjectfilename}"
	kathy3=${templatefile_sub}
	kathy4=${subjectfilename}
	sed -i "s,${kathy3},${kathy4},g" "$outputfilename_sub"
	
	
	
	
	echo "Modifying scene name instances of: ${templatescenename_PA} with ${shortscenename_PA}"
	kathy5_PA=${templatescenename_PA//\//\\/}
	kathy6_PA=${shortscenename_PA//\//\\/}
	sed -i 's,'"${kathy5_PA}"','"${kathy6_PA}"',g' "$outputfilename_sub"
	
	echo "Modifying scene name instances of: ${templatescenename_AX} with ${shortscenename_AX}"
	kathy5_AX=${templatescenename_AX//\//\\/}
	kathy6_AX=${shortscenename_AX//\//\\/}
	sed -i 's,'"${kathy5_AX}"','"${kathy6_AX}"',g' "$outputfilename_sub"
	
	echo "Modifying scene name instances of: ${templatescenename_CO} with ${shortscenename_CO}"
	kathy5_CO=${templatescenename_CO//\//\\/}
	kathy6_CO=${shortscenename_CO//\//\\/}
	sed -i 's,'"${kathy5_CO}"','"${kathy6_CO}"',g' "$outputfilename_sub"
	
	
if [ "${label}" = FALSE ]; then #scale
	#if (( $continuous_lower_default < 0 )); then 
	if (( $(echo "$continuous_lower >= 0"| bc -l) )) && (( $(echo "$continuous_upper > 0"| bc -l) )); then  #-lt = "less than". If the lower or upper limit both positive, turn on zero and turn off negative in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with true</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="true</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename_sub"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with true</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="true</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename_sub"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with false</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="false</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename_sub"
			continuous_lower_default=${continuous_lower_default:-"11.111000"}
			continuous_upper_default=${continuous_upper_default:-"44.444000"}

	fi

	if (( $(echo "$continuous_lower < 0"| bc -l) )) && (( $(echo "$continuous_upper > 0"| bc -l) )); then  #-lt = "less than". If the lower is negative and the upper is positive, turn on everything in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with true</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="true</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename_sub"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with true</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="true</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename_sub"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with true</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="true</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename_sub"
			
			echo "Replace scene smallest negative value: " ${continuous_smaller_negative_value} "with 0"
			kathy_smallnega=${continuous_smaller_negative_value}
			kathy_smallnegb="0"
			sed -i 's,'"${kathy_smallnega}"','"${kathy_smallnegb}"',g' "$outputfilename_sub"

			echo "Replace scene smallest positive value: " ${continuous_smaller_positive_value} "with 0"
			kathy_smallposa=${continuous_smaller_positive_value}
			kathy_smallposb="0"
			sed -i 's,'"${kathy_smallposa}"','"${kathy_smallposb}"',g' "$outputfilename_sub"

			continuous_lower_default=${continuous_lower_default:-"-22.222000"}
			continuous_upper_default=${continuous_upper_default:-"44.444000"}
	fi

	if (( $(echo "$continuous_lower < 0"| bc -l) )) && (( $(echo "$continuous_upper <= 0"| bc -l) )); then  #-lt = "less than". If the lower and upper limit are negative, turn off positive+zero in scale.
			echo "Replace scene positive display setting: " ${continuous_pos_default} "with false</DisplayPositiveData>"
			kathy_posa=${continuous_pos_default}
			kathy_posb="false</DisplayPositiveData>"
			sed -i 's,'"${kathy_posa}"','"${kathy_posb}"',g' "$outputfilename_sub"

			echo "Replace scene zero display setting: " ${continuous_zero_default} "with false</DisplayZeroData>"
			kathy_zeroa=${continuous_zero_default}
			kathy_zerob="false</DisplayZeroData>"
			sed -i 's,'"${kathy_zeroa}"','"${kathy_zerob}"',g' "$outputfilename_sub"

			echo "Replace scene negative display setting: " ${continuous_neg_default} "with true</DisplayNegativeData>"
			kathy_nega=${continuous_neg_default}
			kathy_negb="true</DisplayNegativeData>"
			sed -i 's,'"${kathy_nega}"','"${kathy_negb}"',g' "$outputfilename_sub"
			continuous_lower_default=${continuous_lower_default:-"-22.222000"}
			continuous_upper_default=${continuous_upper_default:-"-33.333000"}
	fi
	echo "Replace scene lower scale value: ${continuous_lower_default} with ${continuous_lower}"
	kathy7=${continuous_lower_default}
	kathy8=${continuous_lower}
	sed -i "s,"${kathy7}","${kathy8}",g" "$outputfilename_sub"
	#sed -i 's,'"${continuous_lower_default}"','"${continuous_lower}"',g' "$outputfilename_sub"

	echo "Replace scene upper scale value: ${continuous_upper_default} with ${continuous_upper}"
	kathy9=${continuous_upper_default}
	kathy10=${continuous_upper}
	sed -i "s,"${kathy9}","${kathy10}",g" "$outputfilename_sub"

	#check supplied scale values to see if negative values should be shown.
	echo "checking range for display values in scene file"
	
	
	if [ "${threshold_image}" = TRUE ]; then #threshold
		echo "threshold setting is: " ${threshold_image}
		echo "Replace scene Threshold value: ${threshold_image_default_sub} with "THRESHOLD_TYPE_NORMAL"" 
		kathy11=${threshold_image_default_sub//\//\\/}
		kathy12=THRESHOLD_TYPE_NORMAL
		sed -i 's,'"${kathy11}"','"${kathy12}"',g' "$outputfilename_sub"
	
		echo "Replace scene Threshold value: ${threshold_lower_default} with ${threshold_lower}" 
		kathy13=${threshold_lower_default//\//\\/}
		kathy14=${threshold_lower//\//\\/}
		sed -i 's,'"${kathy13}"','"${kathy14}"',g' "$outputfilename_sub"
	
		echo "Replace scene Threshold value: ${threshold_upper_default} with ${threshold_upper}" 
		kathy15=${threshold_upper_default//\//\\/}
		kathy16=${threshold_upper//\//\\/}
		sed -i 's,'"${kathy15}"','"${kathy16}"',g' "$outputfilename_sub"
		
		echo "Replace scene Threshold value: ${threshold_inout_default} with ${threshold_inout}" 
		kathy17=${threshold_inout_default//\//\\/}
		kathy18=${threshold_inout//\//\\/}
		sed -i 's,'"${kathy17}"','"${kathy18}"',g' "$outputfilename_sub"
	else
		echo "threshold setting is: " ${threshold_image}
		echo "Replace scene Threshold value: ${threshold_image_default_sub} with "THRESHOLD_TYPE_OFF"" 
		kathy11b=${threshold_image_default_sub//\//\\/}
		kathy12b=THRESHOLD_TYPE_OFF
		sed -i 's,'"${kathy11b}"','"${kathy12b}"',g' "$outputfilename_sub"
	fi
	
		#if [ -z ${var+x} ]; then 
	if [ -z "$PaletteName" ]; then 
	echo "PaletteName is unset.  Using ROY-BIG-BL"; 


	else 
	echo "PaletteName name specified is '$PaletteName'"; 

	echo "Replacing scene Palette value: ${PaletteName_default} with "${PaletteName}"" 
	kathy23=${PaletteName_default//\//\\/}
	kathy24=${PaletteName//\//\\/}
	sed -i 's,'"${kathy23}"','"${kathy24}"',g' "$outputfilename_sub"
	fi

fi # label 	
	# Make the pictures
	
			echo "Generating Subcortical pics"
	        	echo "Calling wb_command as follows:"
	        	echo "      ${wb_command} -show-scene ${outputfilename_sub} ${shortscenename} ${image_file_name_PA} ${pix_width_sub} ${pix_height_sub} "
	        	${wb_command} -show-scene ${outputfilename_sub} ${shortscenename_PA} ${image_file_name_PA} ${pix_width_sub} ${pix_height_sub}
	
	        	echo "Calling wb_command as follows:"
	        	echo "      ${wb_command} -show-scene ${outputfilename_sub} ${shortscenename} ${image_file_name_AX} ${pix_width_sub} ${pix_height_sub} "
	        	${wb_command} -show-scene ${outputfilename_sub} ${shortscenename_AX} ${image_file_name_AX} ${pix_width_sub} ${pix_height_sub}
	
	        	echo "Calling wb_command as follows:"
	        	echo "      ${wb_command} -show-scene ${outputfilename_sub} ${shortscenename} ${image_file_name_CO} ${pix_width_sub} ${pix_height_sub} "
	        	${wb_command} -show-scene ${outputfilename_sub} ${shortscenename_CO} ${image_file_name_CO} ${pix_width_sub} ${pix_height_sub}


if [ "${save_scene_file}" = FALSE ]; then #save scene file?
rm -f ${outputfilename_sub} #remove scene file when done.
fi

fi # make subcorticals
