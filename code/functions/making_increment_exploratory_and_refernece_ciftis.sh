
start_time=$(date +%s)

#SUB=${1}
SUB=1004101
#MIN=${2}
SES=combined
TASK=restMENORDICrmnoisevols
FD=0.2
intrp_noise=1 # If you have not run the spatially interpolated code on these data change flag to 1 
DTSERIESEXT=space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii
#DTSERIESEXT=space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii 
DERIVATIVESDIR=/home/smnelson/shared/projects/subPop/derivatives/fmri_prep/sub-${SUB}/xcp_d/
PCMwrapper=/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/code/wrappers/run_Precision_Confidence-Mapping_wrapper_reliability_curves.sh


BASEDIR=/home/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves/sub-${SUB}/ses-${SES}/
dtseries_in=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_${DTSERIESEXT}
ls ${dtseries_in}
# Get the TR and total number of TRs using wb_command
TR=$(wb_command -file-information ${dtseries_in} -only-step-interval)
surf_L=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_space-fsLR_den-32k_hemi-L_desc-hcp_midthickness.surf.gii
surf_R=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/anat/sub-${SUB}_ses-${SES}_space-fsLR_den-32k_hemi-R_desc-hcp_midthickness.surf.gii

# Define the motion_file variable
#motion_file="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc.hdf5"
motion_file="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat"

motion_out=$(dirname "$motion_file")

# Check if intrp_noise is set to 1
if [ "${intrp_noise}" == "1" ]; then
    # Construct the dtseries_in path using the current DTSERIESEXT
    dtseries_in="${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_${DTSERIESEXT}"
    WB_CMD="/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command"
    runLocally=0

    # Call the MATLAB function directly
    matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'); addpath('/projects/standard/faird/shared/code/internal/utilities/interpolate_noise_for_timeseries/'); infile='${dtseries_in}'; WB_CMD='${WB_CMD}'; runLocally=${runLocally}; interpolate_noise_for_timeseries(infile, WB_CMD, runLocally); exit;"

    # Set intrp_noise to 0 to avoid running it again
    intrp_noise=0

    # Extract the base name without the .dtseries.nii extension
    base_name="${DTSERIESEXT%.dtseries.nii}"
    # Append _spatially_interpolated to the base name
    DTSERIESEXT="${base_name}_spatially_interpolated.dtseries.nii"
    dtseries_in=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_${DTSERIESEXT}
    
fi
echo "This is dtseries ${dtseries_in} and DTSERIESEXT is ${DTSERIESEXT}"
ls ${dtseries_in}
#Calculating Half Data Mins
totalTRs=$(wb_command -file-information ${dtseries_in} -only-number-of-maps)
# Calculate the total time in seconds
total_time_seconds=$(echo "$TR * $totalTRs" | bc)
# Convert the total time to minutes
total_time_minutes=$(echo "scale=2; $total_time_seconds / 60" | bc)
# Calculate half the minutes
half_minutes=$(echo "scale=0; $total_time_minutes / 2" | bc)
# Calculate 10% of half minutes rounded down
#ten_percent_of_half=$(echo "$half_minutes * 0.15" | bc)
percent2round=0.15
n_percent_of_half=$(echo "$half_minutes * ${percent2round}" | bc)
rounded_n_percent_of_half=$(echo "scale=0; $n_percent_of_half / 1" | bc)
MIN=$(echo "$half_minutes - $rounded_n_percent_of_half" | bc)
echo "Half of the data is ${half_minutes} so using a buffer of ${percent2round} to round the half down to account for motion. Change percent2round if needed"
echo "Final Cut off for half the data are defined at: ${MIN} here"


# Check if the motion_file ends with .hdf5
if [[ "$motion_file" == *.hdf5 ]]; then
    # Run MATLAB script
    matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion/'); xcpd2dcanmotion('${motion_file}', '${motion_out}'); exit;"

    # Change the motion_file to use a different suffix
    # Remove the .hdf5 extension and append _power_2014_FD_only.mat
    motion_file="${motion_file%.hdf5}_power_2014_FD_only.mat"
fi

# Continue with the script...
echo "New motion file path: ${motion_file}"



#motion_file=${DERIVATIVESDIR}/sub-${SUB}/ses-${SES}/func/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat


#Making initial incremental Data 
startmins=5
increment=5
endmins=${MIN}
keep_from='start'
for minutes in $(seq $startmins $increment $endmins); do
    echo "Processing permutation: ${minutes}"
    mkdir -p ${BASEDIR}/ExpData-${minutes}m/
    funcout=${BASEDIR}/ExpData-${minutes}m/sub-${SUB}/ses-${SES}/func
    mkdir -p ${funcout}
    anatout=${BASEDIR}/ExpData-${minutes}m/sub-${SUB}/ses-${SES}/anat
    mkdir -p ${anatout}
    cp ${surf_L} ${anatout}
    cp ${surf_R} ${anatout}
    matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); extract_minutes_dtseries_and_motion('${dtseries_in}', '${motion_file}', '${funcout}', '${TR}', '${minutes}', '${keep_from}'); exit;"
    newBASEDIR=${BASEDIR}/ExpData-${minutes}m
    newDTSERIESEXT=truncated_bold.dtseries.nii
    newTASK=${TASK}-${minutes}minutes

    sbatch ${PCMwrapper} ${SUB} ${SES} ${newTASK} ${newBASEDIR} ${newBASEDIR} ${newDTSERIESEXT} ${intrp_noise}

done



# Place your commands here

end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Total execution time for exploratory increment: ${duration} seconds"

#Making ground truth reference data of the second half of the data 

minutes=${MIN}
keep_from='end'
echo "Processing permutation: ${minutes}"
mkdir -p ${BASEDIR}/RefData-${minutes}m/
funcout=${BASEDIR}/RefData-${minutes}m/sub-${SUB}/ses-${SES}/func
mkdir -p ${funcout}
anatout=${BASEDIR}/RefData-${minutes}m/sub-${SUB}/ses-${SES}/anat
mkdir -p ${anatout}
cp ${surf_L} ${anatout}
cp ${surf_R} ${anatout}

matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); extract_minutes_dtseries_and_motion('${dtseries_in}', '${motion_file}', '${funcout}', '${TR}', '${minutes}', '${keep_from}'); exit;"
newBASEDIR=${BASEDIR}/RefData-${minutes}m
newDTSERIESEXT=truncated_bold.dtseries.nii
newTASK=${TASK}-${minutes}minutes

sbatch ${PCMwrapper} ${SUB} ${SES} ${newTASK} ${newBASEDIR} ${newBASEDIR} ${newDTSERIESEXT} ${intrp_noise}




end_time=$(date +%s)
duration=$((end_time - start_time))
echo "Total execution time for all: ${duration} seconds"
