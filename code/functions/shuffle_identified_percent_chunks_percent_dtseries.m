function shuffle_identified_percent_chunks_percent_dtseries(SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile,BASEDIR,intrp_noise,shuffle_option,percent_chunk_size,holdout_pct)

addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
%addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/')
disp("input data is:")
%disp([SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile,BASEDIR,intrp_noise,shuffle_option,percent_chunk_size,holdout_pct])
%disp([ "sub:" SUB " Ses:" SES " FD:" num2str(FD), " Task" TASK, " TR" num2str(TR) " MaxMin" num2str(MAXMIN) " Permutation" num2str(permnum) " Infolder" infolder " infile" infile " Basedir" BASEDIR " intrp noise" num2str(intrp_noise) " shuffle_option: " shuffle_option " percent_chunk_size: " num2str(percent_chunk_size)  " holdout_pct: " num2str(holdout_pct) ])

%% Example input for testing
%SUB='101'
%SES='1'
%TASK='restMENORDICrmnoisevols'
%FD=0.3;
%TR=1.761;
%MAXMIN=35;
%permnum=1;
%infile='/home/yaco0006/shared/projects/HighField_7T/data/processed/derivatives/T2fmriprep/FD-2mm_r-45/xcp_d/sub-101/ses-1/func/sub-101_ses-1_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii'
%intrp_noise=0
%shuffle_option = 'percent'; % Options: 'run' or 'percent'
%percent_chunk_size = 10; % Percentage for chunk size if 'percent' option is chosen
%BASEDIR=['/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/Template_Matching/NetConfV2/sub-101/ses-1'];
%infolder=[BASEDIR '/sub-' SUB '/ses-'  SES '/' TASK '/' num2str(permnum) ]
%holdout_pct = 80;
%% Example input for testing

% SUB='SUBID'
% SES='SESID'
% TASK='TASK'
% FD=0.3;
% TR=1.761;
% MAXMIN=35;
% permnum=1;
% infile='/Path/to/xcpd_out/sub-SUBID/ses-SESID/func/sub-SUBID_ses-SESID-interpolated_bold.dtseries.nii'
% intrp_noise=0
% %shuffle_option = 'percent'; % Options: 'run' or 'percent'
% percent_chunk_size = 15; % Percentage for chunk size if 'percent' option is chosen
% BASEDIR=['/Path/to/analyses/folder/'];
% infolder=[BASEDIR '/' SUB '/'  SES '/' TASK '/' num2str(permnum) ]

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



% Parameters

% Define the path to the .mat file for storing shuffled order
shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(percent_chunk_size) '-percent_order_sub-' SUB '_ses-' SES '.mat']);

% Load concatenated time series
concatenated_timeseries = cifti_read(infile);
data = concatenated_timeseries.cdata;
total_TRs = size(data, 2);
num_permutations = 10000; % or whatever number you need

if strcmp(shuffle_option, 'run')
    % Existing code for shuffling based on runs


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


elseif strcmp(shuffle_option, 'percent')
    % Check if the shuffled order mat file exists
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_percent_order');
        chunk_size_TRs = round(total_TRs * (percent_chunk_size / 100));
        num_chunks = ceil(total_TRs / chunk_size_TRs);
    else
        % Calculate chunk size in TRs and create shuffled order
        chunk_size_TRs = round(total_TRs * (percent_chunk_size / 100));
        num_chunks = ceil(total_TRs / chunk_size_TRs);
        shuffled_percent_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_percent_order(i, :) = randperm(num_chunks);
        end
        % Save the shuffled order
        save(shuffled_mat_path, 'shuffled_percent_order');
    end

    % Use the appropriate permutation from the shuffled percent order
    percent_order = shuffled_percent_order(permnum, :);

    % Divide data into chunks and shuffle
    chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    chunk_sizes(end) = total_TRs - chunk_size_TRs * (num_chunks - 1); % Adjust last chunk size
    data_chunks = mat2cell(data, size(data, 1), chunk_sizes);
    shuffled_data_chunks = data_chunks(percent_order);

    % Concatenate shuffled chunks
    rearranged_data = cat(2, shuffled_data_chunks{:});
end


% Construct the new timeseries
new_timeseries = concatenated_timeseries;
new_timeseries.cdata = rearranged_data;
new_timeseries.diminfo{1,2}.length = size(rearranged_data, 2);

% Save the new timeseries
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

% Motion data shuffling logic
if strcmp(shuffle_option, 'run')
    % Existing code for run-based motion data shuffling

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


elseif strcmp(shuffle_option, 'percent')
    % Calculate chunk sizes for motion data to match dtseries data
    motion_chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    motion_chunk_sizes(end) = size(retained_frames, 1) - chunk_size_TRs * (num_chunks - 1);

    % Divide motion data into chunks
    fd_chunks = mat2cell(retained_frames, motion_chunk_sizes, 1);

    % Shuffle fd chunks
    shuffled_fd_chunks = fd_chunks(percent_order);

    % Concatenate shuffled fd chunks
    rearranged_fd = cat(1, shuffled_fd_chunks{:});
end

good_frames=find(rearranged_fd==1); %good frames in whole dataset


%% step 3.1, sort motion file according to new run order

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
    error('not enough data split have 259')
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

%% Holdout masks
% Making masks for holdout, where ground truth is all of the data, and
%%% hold out is data up to a given percent of the data
total_good_TRs=size(good_frames,1)
disp(['Total good frames are ' total_good_TRs 'of the total acquired TRs which are ' total_TRs ])
holdout_size_TRs = round(total_good_TRs * (holdout_pct / 100));

%holdout_size_TRs = round(total_TRs * (holdout_pct / 100));
unused_size_TRs = size(good_frames,1)-holdout_size_TRs;
holdout_MINs=floor(holdout_size_TRs*TR/60);
unused_MINs=floor(unused_size_TRs*TR/60);
disp(['Total holdout minutes of the good frames are  ' holdout_MINs ' with unused minutes being ' unused_MINs ])

mkdir([infolder '/masks_holdout'])

% mask groundtruth - start after MAXMIN
if size(good_frames,1)>holdout_size_TRs
    mask_gt=zeros(size(rearranged_fd));
    mask_gt(good_frames(:))=1;
else
    error('not enough data split pct line 289')
end
TotalGoodMins=floor(size(good_frames,1)*TR/60);
writematrix(mask_gt, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(TotalGoodMins) 'min.txt']);

%mask half 1 for every minute defined in MIN_X
MIN_X=[1:holdout_MINs];

for i=1:size(MIN_X,2)
    framecount=round(MIN_X(i)*60/TR);
    mask_h1=zeros(size(rearranged_fd));
    mask_h1(good_frames(1:framecount))=1;

    writematrix(mask_h1, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
end


% mask groundtruth - start after MAXMIN
cap=round(holdout_MINs*60/TR);
if size(good_frames,1)>cap
    mask_unused=zeros(size(rearranged_fd));
    mask_unused(good_frames(cap+1:end))=1;
else
    error('not enough data split pct line 312')
end

writematrix(mask_unused, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_unused_' num2str(unused_MINs) 'min.txt']);


% mask groundtruth - start after MAXMIN
cap=round(holdout_MINs*60/TR);
if size(good_frames,1)>cap
    mask_holdout=zeros(size(rearranged_fd));
    mask_holdout(good_frames(1:cap))=1;
else
    error('not enough data split pct line 324')
end

writematrix(mask_holdout, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_holdout_' num2str(holdout_MINs) 'min.txt']);

fprintf('Result: %f,%f\n', holdout_MINs, TotalGoodMins);

end

