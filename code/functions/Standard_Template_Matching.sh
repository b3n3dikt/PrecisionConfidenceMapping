#!/bin/bash -l

#SBATCH -J 
#SBATCH --ntasks=
#SBATCH --tmp=
#SBATCH --mem=
#SBATCH -t 
#SBATCH -p 
#SBATCH -o 
#SBATCH -e 
#SBATCH -A 



## Inputs changed in wrapper to run below
SUB=${1} # subject ID
SES=${2} # session 
TASK=${3} #- determine if SE or ME and NORDIC or non-NORDIC
FD=${4} # FD for this dataset
NUM=${5} #number of current permutation to be run 
MIN=${6} #maximum minutes for reliability curve - attention: MIN must be smaller than half of the data
S_KERNEL=${7} # e.g. 2.55
DERIVATIVESDIR=${8}
BASEDIR=${9}
DTSERIESEXT=${10}
SURF_ONLY=${11}
intrp_noise=${12}
shuffle_option=${13}
percent_chunk_size=${14}
percent_holdout=${15}
SPLITHALF=${16}
SPLITPCT=${17}
PIPELINE=${18}
TR=${19}
STANDARDTM=${20}



echo " Inputs  ${SUB} ${SES} ${TASK} ${FD} ${NUM} ${MIN} ${S_KERNEL} Derivatives Dir ${DERIVATIVESDIR} Basedir: ${BASEDIR} dtseriesext: ${DTSERIESEXT} ${SURF_ONLY} ${intrp_noise} ${shuffle_option} ${percent_chunk_size} ${percent_holdout} ${SPLITHALF} ${SPLITPCT} ${PIPELINE} ${STANDARDTM} ${TR}"

#############################################################################################
#paths to matlab runtime and wb_command
MRE_DIR='/projects/standard/faird/shared/code/external/utilities/MATLAB_Runtime_R2016b/v91/'
#MRE_DIR='/home/feczk001/shared/code/external/utilities/MATLAB_MCR/v91/'
WB_CMD='/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command'
module load workbench/1.5.0

dtseries_in=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_${DTSERIESEXT}

# Check if TR input is provided and is not empty
if [ ! -z "${20}" ]; then
    TR=${20}
    echo "TR was provided by user so not using dtseries to calculate TR"
else
    echo "TR was not provided by user so using dtseries to calculate TR"

    TR=$(wb_command -file-information ${dtseries_in} -only-step-interval) 
fi

# # Check if MIN2RUN is provided and is not empty
# if [ ! -z "${18}" ]; then
#     PIPELINE=${18}
# else
#     PIPELINE=xcpd
# fi

echo "The sub-${SUB}_ses-${SES}_task-${TASK}_PERM-${NUM} Job started at: $(date)" >> ${BASEDIR}/output_logs/BANC_%A_%a.out
echo "The sub-${SUB}_ses-${SES}_task-${TASK}_PERM-${NUM} Job started at: $(date)" >> ${BASEDIR}/output_logs/BANC_%A_%a.err

if [ ! -d ${BASEDIR} ]; then

    mkdir -p ${BASEDIR}

fi


# Example call sbatch /panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/code/main_run_script_reliability_curve_012723_dense.sh 101 1 restMENORDICrmnoisevols 0.25 1 35 2.55 /panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/derivatives/xcpd_FD2mm/xcp_d /panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/reliability_7T


# HARDCODED INPUTS
#BASEDIR=/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/reliability
#DERIVATIVESDIR=/home/yaco0006/shared/projects/HighField_7T/3T/derivatives/xcpd_FD2mm/xcp_d

#motion_file=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc.hdf5

#############################################################


#start loop for permutations
work_dir=/tmp/sub-${SUB}/ses-${SES}/${TASK}/standard
#work_dir=${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK}/standard

#work_dir=/home/yaco0006/shared/projects/extended_scanning/analyses/TM_splits/sub-${SUB}/ses-${SES}/${TASK}/${NUM}
#work_dir=/tmp/${SUB}/${SES}/${TASK}/${NUM}


pwd; hostname; date

if [ ! -d ${work_dir} ]; then

    mkdir -p ${work_dir}

fi

out_dir=${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK}/standard




if [ ! -d ${out_dir} ]; then

    mkdir -p ${out_dir}

fi


module load workbench; 
module load matlab; 

# transform XCP-D motion file to DCAN motion file

# Run code to do k-means clustering and output ciftis

# Run code to do k-means clustering and output ciftis
echo "this is PIPELINE ${PIPELINE}"
if [ "${PIPELINE}" == "abcd" ]; then
    echo "PIPELINE = ${PIPELINE}"
    motion_files=(${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat)
    if [ "${#motion_files[@]}" -eq 1 ]; then
        cp "${motion_files[0]}" "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat"
    else
        echo "Error: Expected one motion file, found ${#motion_files[@]}"
        exit 1
    fi
    
    surf_L=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_hemi-L_space-MNI_mesh-fsLR32k_midthickness.surf.gii
    surf_R=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_hemi-R_space-MNI_mesh-fsLR32k_midthickness.surf.gii
else 
    echo "DID not pick up PIPELINE as abcd PIPELINE = ${PIPELINE}"
fi

if [ "${PIPELINE}" == "xcpd" ]; then
    echo "PIPELINE = ${PIPELINE}"

    # Define potential file paths
    motion_file_mat="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat"
    motion_file_hdf5="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc.hdf5"

    # Check if the .mat file already exists
    if [ -f "${motion_file_mat}" ]; then
        echo "Using existing Power FD motion file: ${motion_file_mat}"
        motion_file="${motion_file_mat}"
        cp ${motion_file} ${work_dir}/
    elif [ -f "${motion_file_hdf5}" ]; then
        echo "Processing HDF5 to create motion file: ${motion_file_hdf5}"
        # If the .mat file does not exist but the .hdf5 does, process it with MATLAB
        motion_file="${motion_file_hdf5}"
        matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion/'); xcpd2dcanmotion('${motion_file}', '${work_dir}'); exit;"
        # Assume MATLAB script outputs the .mat file, redefine motion_file to the new .mat
        motion_file="${motion_file_mat}"
    else
        echo "No valid motion file found."
    fi
    echo "done with motion identification"
    # Define surface files
    surf_L="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_space-fsLR_den-32k_hemi-L_desc-hcp_midthickness.surf.gii"
    surf_R="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_space-fsLR_den-32k_hemi-R_desc-hcp_midthickness.surf.gii"

else
    echo "DID not pick up PIPELINE as xcpd. PIPELINE = ${PIPELINE}"
fi


#To DO: make output dir temporary directory
echo "done with motion identification"

echo "chosing template" >> "${BASEDIR}/output_logs/outinfo.txt"

if [ ${SURF_ONLY} == 0 ]; then
  TEMPLATE_PATH='/projects/standard/faird/shared/code/internal/analytics/compare_matrices_copy_to_merge_from/support_files/seedmaps_ABCD164template_SMOOTHED_dtseries_all_networksZscored.mat'
  SURF_ONLY_LABEL='subcort_included'
  TEMPLATE=abcd
elif [ ${SURF_ONLY} == 1 ]; then
  TEMPLATE_PATH='/projects/standard/faird/shared/code/internal/analytics/compare_matrices_copy_to_merge_from/support_files/ABCD_surface_template/seedmaps_ABCD_surface_dtseries_all_networksZscored.mat'
  SURF_ONLY_LABEL='surfonly'
  TEMPLATE=abcd
elif [ ${SURF_ONLY} == 2 ]; then
  TEMPLATE_PATH='/projects/standard/rando149/shared/projects/ABCD_template_maker/seedmaps_from_template2.0/ABCD_scan_seedmap/seedmaps_subs_withsmoothed_dtseries_n141_all_networksZscored.mat'
  SURF_ONLY_LABEL='SCAN_network'
  TEMPLATE=abcd-SCAN
  echo "template is ${TEMPLATE_PATH}"
fi



#if [[ ${STANDARDTM} == 1 ]]; then
    
    echo "Running Percent split PCM" >> "${BASEDIR}/output_logs/outinfo.txt"

    # Define the path to the mask file
    #MASK_PATH="${work_dir}/masks_holdout/sub-${SUB}_ses-${SES}_mask_holdout_*min.txt"

    # # Find the mask file using wildcard expansion
    # files_found=($(ls ${MASK_PATH}))
    # if [[ "${#files_found[@]}" -eq "1" ]]; then
    #     echo "One mask file found: ${files_found[0]}" >> "${BASEDIR}/output_logs/outinfo.txt"
    #     MASK_PATH=${files_found[0]}
    # else
    #     echo "Error: Expected one mask file, found ${#files_found[@]}" >> "${BASEDIR}/output_logs/outinfo.txt"
    #     echo "Files found:" >> "${BASEDIR}/output_logs/outinfo.txt"
    #     printf '%s\n' "${files_found[@]}"
    #     exit 1
    # fi

    # Set output directories
    OUTDIR="${work_dir}/Standard_Template_Matching/${TEMPLATE}_template/${SURF_ONLY_LABEL}"
    mkdir -p "${OUTDIR}"
    OUTSAVE="${out_dir}/Standard_Template_Matching/${TEMPLATE}_template/${SURF_ONLY_LABEL}"
    mkdir -p "${OUTSAVE}"

    # Execute the mapping wrapper
    /projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/twins_mapping_wrapper_washu_nordic.sh \
        ${TR} \
        ${FD} \
        "${dtseries_in}" \
        "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat" \
        ${surf_L} \
        ${surf_R} \
        "sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_holdout_perm-${NUM}" \
        "${OUTDIR}" \
        ${TEMPLATE_PATH} \
        ${SURF_ONLY} 0 \
        "${OUTDIR}" \
        "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
        "none"

    # Clean up and copy results
    rm -rf "${work_dir}/Standard_Template_Matching/${TEMPLATE}_template/${SURF_ONLY_LABEL}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries_SMOOTHED_2.25.dtseries.nii"
    cp "${OUTDIR}"/*.dscalar.nii "${OUTSAVE}/"
    cp "${OUTDIR}"/*.mat "${OUTSAVE}/"
    ls "${OUTDIR}"/*recolored.dscalar.nii >> "${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Standard_Template_Matching.conc"
    ls "${OUTDIR}"/*recolored.dscalar.nii >> "${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Standard_Template_Matching_dscalar_list_All.conc"
#else

   # echo "Not running split percent" >> "${BASEDIR}/output_logs/outinfo.txt"
#fi



# if [ ${SPLITPCT} == 1 ]; then

#     echo "Running Percent split PCM"
#     ### run Template matchin on first half

#     #MASK_PATH=${work_dir}/masks_holdout/sub-${SUB}_ses-${SES}_mask_holdout_*min.txt
#     files_found=($(ls ${MASK_PATH}))
#     if [ "${#files_found[@]}" -eq "1" ]; then
#         echo "One mask file found: ${files_found[0]}"
#         MASK_PATH=${files_found[0]}
#     else
#         echo "Error: Expected one mask file, found ${#files_found[@]}"
#         exit 1
#     fi

#     OUTDIR=${work_dir}/Percent_holdout-${percent_holdout}/${TEMPLATE}_template/${SURF_ONLY_LABEL}
#     mkdir -p ${OUTDIR}
#     OUTSAVE=${out_dir}/Percent_holdout-${percent_holdout}/${TEMPLATE}_template/${SURF_ONLY_LABEL}
#     mkdir -p ${OUTSAVE}

#     /projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/twins_mapping_wrapper_washu_nordic.sh \
#     ${TR} \
#     ${FD} \
#     ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii \
#     ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat \
#     ${surf_L} \
#     ${surf_R} \
#     sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_holdout_perm-${NUM} \
#     ${OUTDIR} \
#     ${TEMPLATE_PATH} \
#     ${SURF_ONLY} 0 \
#     ${OUTDIR} \
#     ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii \
#     ${MASK_PATH}

#     rm -rf ${work_dir}/Percent_holdout-${percent_holdout}/${TEMPLATE}_template/${SURF_ONLY_LABEL}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries_SMOOTHED_2.25.dtseries.nii
#     cp ${OUTDIR}/*.dscalar.nii ${OUTSAVE}/
#     ls ${OUTDIR}/*recolored.dscalar.nii >> ${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Percent_holdout_percent-${percent_holdout}.conc
#     ls ${OUTDIR}/*recolored.dscalar.nii >> ${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Percent_holdout_TM_dscalar_list_All.conc

#     ### run Template matchin on full shuffled dataset

#     # MASK_PATH=${work_dir}/masks_holdout/sub-${SUB}_ses-${SES}_mask_groundtruth_${TotalGoodMins}min.txt 

#     # OUTDIR=${work_dir}/Percent_holdout-${percent_holdout}_groundtruth/${TEMPLATE}_template/${SURF_ONLY_LABEL}
#     # mkdir -p ${OUTDIR}
#     # OUTSAVE=${out_dir}/Percent_holdout-${percent_holdout}_groundtruth/${TEMPLATE}_template/${SURF_ONLY_LABEL}
#     # mkdir -p ${OUTSAVE}

#     # /projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/twins_mapping_wrapper_washu_nordic.sh \
#     # ${TR} \
#     # ${FD} \
#     # ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii \
#     # ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat \
#     # ${surf_L} \
#     # ${surf_R} \
#     # sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_half2_perm-${NUM} \
#     # ${OUTDIR} \
#     # ${TEMPLATE_PATH} \
#     # ${SURF_ONLY} 0 \
#     # ${OUTDIR} \
#     # ${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii \
#     # ${MASK_PATH}

#     # rm -rf ${work_dir}/Half2/${TEMPLATE}_template/${SURF_ONLY_LABEL}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries_SMOOTHED_2.25.dtseries.nii

#     # cp ${OUTDIR}/*.dscalar.nii ${OUTSAVE}/
#     # ls ${OUTDIR}/*recolored.dscalar.nii >> ${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Percent_holdout_Ground_truth.conc
#     # ls ${OUTDIR}/*recolored.dscalar.nii >> ${BASEDIR}/sub-${SUB}_ses-${SES}_task-${TASK}_Percent_holdout_TM_dscalar_list_All.conc
    
# fi


echo "The sub-${SUB}_ses-${SES}_task-${TASK}_PERM-${NUM} Job ended at: $(date)" >> ${BASEDIR}/output_logs/BANC_%A_%a.out
echo "The sub-${SUB}_ses-${SES}_task-${TASK}_PERM-${NUM} Job ended at: $(date)" >> ${BASEDIR}/output_logs/BANC_%A_%a.err

#twins_mapping_wrapper_washu_nordic(dt_or_ptseries_conc_file,motion_file,left_surface_file, right_surface_file, output_file_name, cifti_output_folder,template_path,surface_only,already_surface_only,output_directory, dtseries_conc,additional_mask, run_infomap_too)
## run template matching on Half 2











