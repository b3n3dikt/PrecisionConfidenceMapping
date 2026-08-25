#!/bin/sh

# convert_motion_and_interpolate.sh
# description: runs the xcpd2dcanmotion Matlab script to convert motion data from xcp_d to DCAN "power_2014_FD_only.mat" format, for all HDF5 files in a directory, and interpolates timeseries on the dtseries in the same folder
# usage: convert_motion_and_interpolate.sh <xcp_d func dir>

module load matlab/R2019a

FUNCDIR=$1

matlab -nodisplay -nosplash -r "addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion')); hdf5_files=dir('${FUNCDIR}/*.hdf5'); for i = 1:length(hdf5_files); xcpd2dcanmotion(fullfile(hdf5_files(i).folder, hdf5_files(i).name), hdf5_files(i).folder); end; exit"

for FILE in ${FUNCDIR}/*denoised_bold.dtseries.nii; do
echo "spatially interpolating $FILE"
matlab -nodisplay -nosplash -r "addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/interpolate_noise_for_timeseries')); addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/')); cii_save_name=interpolate_noise_for_timeseries('${FILE}','/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command',0); exit"
done

python /projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion/convert_motion_hdf5_to_tsv.py ${FUNCDIR}
