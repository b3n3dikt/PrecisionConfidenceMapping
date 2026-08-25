#!/bin/sh

# run_xcpd2dcanmotion_on_func_dir.sh
# description: runs the xcpd2dcanmotion Matlab script to convert motion data from xcp_d to DCAN "power_2014_FD_only.mat" format, for all HDF5 files in a directory
# usage: run_xcpd2dcanmotion_on_func_dir.sh <xcp_d func dir>

module load matlab/R2019a

FUNCDIR=$1

#matlab -nodisplay -nosplash -r "addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion')); hdf5_files=dir('${FUNCDIR}/*.hdf5'); for i = 1:length(hdf5_files); xcpd2dcanmotion(fullfile(hdf5_files(i).folder, hdf5_files(i).name), hdf5_files(i).folder); end; exit"
matlab -nodisplay -nosplash -r "addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/xcpd2dcanmotion')); hdf5_files=dir('${FUNCDIR}/*.hdf5'); for i = 1:length(hdf5_files); xcpd2dcanmotion(fullfile(hdf5_files(i).folder, hdf5_files(i).name), hdf5_files(i).folder); end; exit"
