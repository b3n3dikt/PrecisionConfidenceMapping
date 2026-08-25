function shuffle_identified_runs_xcpd_dtseries(SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile,BASEDIR,intrp_noise)


addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

%SUB='AC'
%SES='combined'
%FD=0.2
%TASK='crossMENORDICrmnoisevols'
%TR=1.761;
%MAXMIN=25;
%permnum=2;

% 
% SUB='101'
% SES='1'
% TASK='restMENORDICrmnoisevols'
% FD=0.2;
% TR=1.761;
% MAXMIN=25;
% permnum=1;
% %MIN=25
% %S_KERNEL=2.55
% infolder=['/home/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/' SUB '/'  SES '/' TASK '/' num2str(permnum) ]
% infile='/home/yaco0006/shared/projects/HighField_7T/derivatives/xcpd_FD2mm/xcp_d//sub-101/ses-1/func/sub-101_ses-1_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii'
% 
% DERIVATIVESDIR='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/derivatives/xcpd_FD2mm/xcp_d/'
% BASEDIR='/home/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/'
% DTSERIESEXT='space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii'
% SURF_ONLY=2
%infolder=['/home/yaco0006/shared/projects/extended_scanning/analyses/TM_splits/workdir/' SUB '/'  SES '/' TASK '/' num2str(permnum) ]
%DERIVATIVESDIR=/home/smnelson/shared/projects/extended_scanning/derivatives/fmri_prep/sub-AC/xcp_d/

%infile=[ '/home/smnelson/shared/projects/extended_scanning/derivatives/fmri_prep/sub-AC/xcp_d/sub-' SUB '/ses-' SES '/func/sub-' SUB '_ses-' SES '_task-' TASK '_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii' ]
%/home/smnelson/shared/projects/extended_scanning/derivatives/fmri_prep/sub-AC/xcp_d/
%BASEDIR='/home/yaco0006/shared/projects/extended_scanning/analyses/TM_splits/'
%infile='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/derivatives/xcpd_FD2mm/xcp_d//sub-101/ses-1/func/sub-101_ses-1_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii'
%% step 1, load random run order
% Define BASEDIR
%BASEDIR='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/'
%infolder='/home/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/sub-101/ses-1/restMENORDICrmnoisevols/2'
%BASEDIR = '/home/yaco0006/shared/projects/extended_scanning/analyses/TM_splits/';

%intrp_noise=1;%
if intrp_noise == 1
    % Add required paths
    addpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks');
    %addpath('/projects/standard/faird/shared/code/internal/utilities/interpolate_noise_for_timeseries/');
    addpath('/projects/standard/faird/shared/code/internal/utilities/interpolate_noise_for_timeseries/');
    MRE_DIR='/projects/standard/faird/shared/code/external/utilities/MATLAB_Runtime_R2016b/v91/'
    addpath(MRE_DIR)
    % Set the wb_command path
    WB_CMD = '/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command';

    % Run the interpolate_noise_for_timeseries function
    infile = interpolate_noise_for_timeseries(infile, WB_CMD, 0);
 end


% Identify the directory containing the run files
run_files_dir = fileparts(infile);

% List all files in the directory
files = dir(fullfile(run_files_dir, ['sub-' SUB '_ses-' SES '_task-' TASK '_run-*_space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii']));

% Extract run numbers from file names
run_numbers = regexp({files.name}, 'run-(\d+)_', 'tokens');
run_numbers = cellfun(@(x) str2double(x{1}), run_numbers);

% Define the path to the .mat file
mat_file_path = fullfile(BASEDIR, ['rand_order_runs_sub-' SUB '_ses-' SES '.mat']);

% Check if the .mat file exists
if exist(mat_file_path, 'file')
    % Load the existing .mat file
    load(mat_file_path, 'shuffled_order_matrix');
else
    % Create shuffled order matrix
    num_permutations = 1000; % or whatever number you need
    shuffled_order_matrix = zeros(num_permutations, numel(run_numbers));
    for i = 1:num_permutations
        shuffled_order_matrix(i, :) = run_numbers(randperm(numel(run_numbers)));
    end

    % Save the shuffled order matrix
    save(mat_file_path, 'shuffled_order_matrix');
end

% Use the appropriate permutation from the shuffled order matrix
run_order = shuffled_order_matrix(permnum, :);

%% step 2, load concatenated dtseries

%load concatenated time series
concatenated_timeseries=cifti_read(infile);
data=concatenated_timeseries.cdata;


% Initialize framelist
framelist = zeros(numel(run_numbers), 1);

% Load each run file and determine the number of frames
for i = 1:numel(run_numbers)
    run_file = fullfile(run_files_dir, files(i).name);
    run_data = cifti_read(run_file);
    framelist(i) = size(run_data.cdata, 2); % Number of frames in the temporal dimension
end

%create array with starting and stopping point of frame list
framelist_start=1;
for i=2:size(framelist,1)
    framelist_start(i,1)=framelist(i-1,1)+framelist_start(i-1,1);
end

for i=1:size(framelist,1)
    framelist_stop(i,1)=framelist_start(i,1)+framelist(i,1)-1;
end

%split data by run according to the frames per run
for i=1:size(framelist,1)
    data_by_run{i}=concatenated_timeseries.cdata(:,framelist_start(i):framelist_stop(i));
end


% Map actual run numbers to indices
run_number_to_index = containers.Map(run_numbers, 1:numel(run_numbers));

% Adjust run_order to use indices instead of actual run numbers
run_order_indices = arrayfun(@(x) run_number_to_index(x), run_order);

% Rearrange data by run order to build new concatenated timeseries
rearranged_data = data_by_run{run_order_indices(1)};

for k = 2:length(run_order_indices)
    rearranged_data = [rearranged_data, data_by_run{run_order_indices(k)}];
end


new_timeseries=concatenated_timeseries;
new_timeseries.cdata=rearranged_data;
new_timeseries.diminfo{1,2}.length=size(rearranged_data,2);


cifti_write(new_timeseries, [infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries.dtseries.nii']);
%% step 3, load motion file and create masks
%load motion file
load([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-dcan_qc_power_2014_FD_only.mat']);

%pick fd traces with fitting FD value
for i=1:size(motion_data,2)
    list_thresholds(i,1)=motion_data{1,i}.FD_threshold;
end
index=find(list_thresholds==FD);

fd_vector=motion_data{1,index}.frame_removal;

retained_frames=abs(fd_vector-1);
%% step 3.1, sort motion file according to new run order

%split data by run according to the frames per run
for i=1:size(framelist,1)
    fd_by_run{i}=retained_frames(framelist_start(i):framelist_stop(i));
end

%rearrange data by run order to build new concatenated motion trace
k=1;
rearranged_fd=[fd_by_run{1,run_order_indices(k)}];
while k<size(run_order_indices,2)
rearranged_fd=[rearranged_fd; fd_by_run{1,run_order_indices(k+1)}];
k=k+1;
end

good_frames=find(rearranged_fd==1); %good frames in whole dataset

%% step 3.2 replace cell in motion file
motion_data{1,index}.frame_removal=abs(rearranged_fd-1);
motion_data{1,index}.total_frame_count=size(rearranged_fd,1);
motion_data{1,index}.remaining_frame_count=size(good_frames,1);
motion_data{1,index}.remaining_seconds=size(good_frames,1)*TR;
save([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-filtered_motion_mask.mat'], 'motion_data');

%% step 3.3, create masks and write them to tmp space
mkdir([infolder '/masks'])

% mask groundtruth - start after MAXMIN
cap=round(MAXMIN*60/TR);
if size(good_frames,1)>cap*2
    mask_gt=zeros(size(rearranged_fd));
    mask_gt(good_frames(cap+1:cap*2))=1;
else
    error('not enough data')
end

writematrix(mask_gt, [infolder '/masks/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(MAXMIN) 'min.txt']);

%mask half 1 for every minute defined in MIN_X
MIN_X=[1:MAXMIN];

for i=1:size(MIN_X,2)
    framecount=round(MIN_X(i)*60/TR);
    mask_h1=zeros(size(rearranged_fd));
    mask_h1(good_frames(1:framecount))=1;

    writematrix(mask_h1, [infolder '/masks/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
end


end

