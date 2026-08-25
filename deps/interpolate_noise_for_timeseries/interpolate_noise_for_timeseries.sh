#! /bin/sh

### Matlab command and usage
#function [cii_save_name, dropout_indices] = interpolate_noise_for_timeseries(dtseries_file,wb_command,run_locally,outputdir)

#INTERPOLATE_NOISE_FOR_SUBCORTICALS - This function works by finding
#voxels/grayordiantes in thetimseries that are equal to 0 (exactly) and
#injects noise into each frame based on the mean and standard deviation of
#the grayordinates in the same structure.

#R. Hermosillo 10/13/2022
#Inputs are: dtseries file = full path to the dtseriesfile
#wb_command = full path to workbench command.
#run_locally = Set to 1 if your running this on Robert's Desktop computer. Set to 0
#if you're running this on MSI. (This will automatically load the necessary cifti dependencies.)

X="addpath('/projects/standard/faird/shared/code/internal/utilities/interpolate_noise_for_timeseries/'); addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/')); interpolate_noise_for_timeseries('${1}', '${2}', '${3}','${4}')"

#Hermosillo R. 4/19/2019
#this code runs template matching starting from a dtseries.  Several parameters are hardcoded into the corresponding matlab code.


#$1= path to dconn.nii (or pconn) file

###########################################################################################
#matlab_exec=/home/exacloud/lustre1/fnl_lab/code/external/GUIs/MATLAB/R2018a/matlab
#matlab_exec=/home/exacloud/lustre1/fnl_lab/code/external/GUIs/MATLAB/R2016b/matlab
#matlab_exec=/panfs/roc/msisoft/matlab/R2019a/bin/matlab
matlab_exec=/common/software/install/migrated/matlab/R2019a/bin/matlab

RandomHash=`cat /dev/urandom | tr -cd 'a-f0-9' | head -c 16`
Tempmatlabcommand="matlab_command""$RandomHash"".m"

if [ -f "matlab_command""$RandomHash"".m" ]
then
	#echo "matlab_command.m found removing â¦"
	rm -fR "matlab_command""$RandomHash"".m"
fi

#echo ${X} 
echo ${X} > "matlab_command""$RandomHash"".m"
cat "matlab_command""$RandomHash"".m"
${matlab_exec} -nodisplay -nosplash < "matlab_command""$RandomHash"".m"
rm -f "matlab_command""$RandomHash"".m"
