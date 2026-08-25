#!/bin/bash

#timeseries=/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_Gordonsub.ptseries.nii # matlab thinks this name is too long.
#timeseries=/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-rest_SpaInt_Gordon.ptseries.nii
timeseries=/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii

FD=0.2;
bagged_mask_dir='/home/znahas/shared/projects/PCS/dconns/sub-PCS0001/bagged_ses-01_with_bad_runs_excluded_smoothed2.55_fMRIprep_T2bold_norun02/bags'
outdir='/home/znahas/shared/projects/PCS/dconns/sub-PCS0001/bagged_ses-01_with_bad_runs_excluded_smoothed2.55_fMRIprep_T2bold_norun02/' # don't forget trailing slash
linked_timeseries_dir=$outdir/'linked_timeseries'
conc_dir=$outdir/'conc_files'
log_dir=$outdir/'log_files'
TR=1.761
L_surface=/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/anat/sub-PCS0001_ses-01_space-fsLR_den-32k_hemi-L_desc-hcp_midthickness.surf.gii
R_surface=/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/anat/sub-PCS0001_ses-01_space-fsLR_den-32k_hemi-R_desc-hcp_midthickness.surf.gii
FD_threshold=0.2;
smoothing_kernel=2.55;
bit8=0;
remove_outliers=0;
#additional_mask_conc='/home/znahas/shared/projects/PCS/code/total_3619f_remove_1473_to_2525_and_run02.txt'; # Do not use an additional mask here.  Those frames have already been excluded.
additional_mask_conc='none';
make_dconn_conc=0;
use_continous_minutes=0;
bagged_mask_root_name='sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_desc-dcan_qc_power_2014_FD_only.mat_0.2FD_from_minTP_040min_60bagmin_scaledweightsbag'
CIFTI_CONN_TEMPLATE_SCRIPT=/projects/standard/faird/shared/code/internal/utilities/cifti_connectivity/src/cifti_conn_template_for_wrapper.sh 
minutes_limit='none'
WB_command=/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command
memory_limit_value=64
keep_conn_matrices=0
add_but_donot_divide=1
pordconn='dconn'
pordtseries='dtseries'

#SLURM parameters
SRUNTIME=48:00:00
num_jobs=10 #10
dconns_per_job=50; #50
MEM_PER_CPU=32GB
PARTITIONS=msismall,msilarge
CPUSPERTASK=4
JOBNAME=CiftiBAG

# START
timeseries_rootnameA=`basename ${timeseries}`
timeseries_dirname=`dirname ${timeseries}`
filename="${timeseries_rootnameA%%.*}"  # the two percent signs will remove both extensions (i.e. .dtseries.nii)
timeseries_ext="${timeseries#*.}"
#ln -s /home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_Gordonsub.ptseries.nii 
bag_num=1

mkdir -p ${linked_timeseries_dir};
mkdir -p ${conc_dir};
mkdir -p ${log_dir};
mkdir -p ${bagged_mask_dir} # should already exist

#for (( j=1 ; j<=$num_jobs ; j++ )); 
for j in 4 ; 

do

echo 'building conc files for job' ${j};
dconn_output_filename=${outdir}/$filename'_'job${j}.${pordconn}.nii

    for (( i=1 ; i<=$dconns_per_job ; i++ )); 
    do
    
      jminusone=$(expr $j - 1 );
      bag_num=$(expr $jminusone \* $dconns_per_job  + $i )
      
      #echo ${i}
      #ln -s $timeseries $outdir/$filename'_'
      #echo ${timeseries} 
      echo $bag_num
      bag_num03=$(printf "%03d\n" $bag_num) #keep numbers to 3 digits.   

      ln -s $timeseries $linked_timeseries_dir/$filename'_'bagnum$bag_num03'.'$timeseries_ext
      echo $linked_timeseries_dir/$filename'_'bagnum$bag_num03'.'$timeseries_ext >> ${conc_dir}/bagged_timeseries_conc${j}.conc
      echo ${bagged_mask_dir}/${bagged_mask_root_name}$bag_num03'.txt' >>${conc_dir}/bagged_motion_conc${j}.conc
    
      echo $L_surface >> ${conc_dir}/L_surf_conc${j}.conc
      echo $R_surface >> ${conc_dir}/R_surf_conc${j}.conc

      #bag_num=$(expr $bag_num + 1)  

    done
 
  # cifti conn template variable order reference:
  #cifti_conn_matrix_for_wrapper_continous(wb_command(1), dt_or_ptseries_conc_file(2), series(3), motion_file(4), FD_threshold(5), TR(6), minutes_limit(7), smoothing_kernel(8), left_surface_file(9), right_surface_file(10), bit8(11), remove_outliers(12), additional_mask_conc(13), make_dconn_conc(14), output_directory(15), dtseries_conc(16), use_continous_minutes(17), memory_limit_value(18), keep_conn_matrices (19), dconn_output_filename (20), add_but_donot_divide (21))

 sbatch --time=${SRUNTIME} --mem-per-cpu=${MEM_PER_CPU} --cpus-per-task=${CPUSPERTASK} --partition=${PARTITIONS} --job-name=${JOBNAME} -e ${log_dir}/${filename}_$j.err -o ${log_dir}/${filename}_$j.out ${CIFTI_CONN_TEMPLATE_SCRIPT} ${WB_command} ${conc_dir}/bagged_timeseries_conc${j}.conc ${pordtseries} ${conc_dir}/bagged_motion_conc${j}.conc ${FD_threshold} ${TR} ${minutes_limit} ${smoothing_kernel} ${conc_dir}/L_surf_conc${j}.conc ${conc_dir}/R_surf_conc${j}.conc ${bit8} ${remove_outliers} ${additional_mask_conc} ${make_dconn_conc} ${outdir} ${conc_dir}/bagged_timeseries_conc${j}.conc ${use_continous_minutes} ${memory_limit_value} ${keep_conn_matrices} ${dconn_output_filename} ${add_but_donot_divide} &  

 
done
#wait # wait to for jobs to finish

date
echo "Done submitting jobs."








