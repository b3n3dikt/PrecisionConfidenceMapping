function motion_and_dtseries_bagging(SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct)

% Display the function call for easy rerun


disp("matlab call for function")
inputdisp = sprintf('motion_and_dtseries_bagging(''%s'', ''%s'', %f, ''%s'', %f, %d, %d, ''%s'', ''%s'', ''%s'', %d, ''%s'', %d, %f);', ...
    SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct);
disp(inputdisp);

addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

% Parameters
shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-percent_order_sub-' SUB '_ses-' SES '.mat']);

% Load concatenated time series
concatenated_timeseries = cifti_read(infile);
data = concatenated_timeseries.cdata;
total_TRs = size(data, 2);
num_permutations = 10000; % or whatever number you need

if strcmp(shuffle_option, 'run')
    % Existing code for shuffling based on runs
    run_files_dir = fileparts(infile);
    files = dir(fullfile(run_files_dir, ['sub-' SUB '_ses-' SES '_task-' TASK '_run-*_space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii']));
    run_numbers = regexp({files.name}, 'run-(\d+)_', 'tokens');
    run_numbers = cellfun(@(x) str2double(x{1}), run_numbers);
    mat_file_path = fullfile(BASEDIR, ['rand_order_runs_sub-' SUB '_ses-' SES '.mat']);
    
    if exist(mat_file_path, 'file')
        load(mat_file_path, 'shuffled_order_matrix');
    else
        shuffled_order_matrix = zeros(num_permutations, numel(run_numbers));
        for i = 1:num_permutations
            shuffled_order_matrix(i, :) = run_numbers(randperm(numel(run_numbers)));
        end
        save(mat_file_path, 'shuffled_order_matrix');
    end

    run_order = shuffled_order_matrix(permnum, :);

    % Load concatenated dtseries
    concatenated_timeseries = cifti_read(infile);
    data = concatenated_timeseries.cdata;

    framelist = zeros(numel(run_numbers), 1);
    for i = 1:numel(run_numbers)
        run_file = fullfile(run_files_dir, files(i).name);
        run_data = cifti_read(run_file);
        framelist(i) = size(run_data.cdata, 2);
    end

    framelist_start = 1;
    for i = 2:size(framelist, 1)
        framelist_start(i, 1) = framelist(i-1, 1) + framelist_start(i-1, 1);
    end

    for i = 1:size(framelist, 1)
        framelist_stop(i, 1) = framelist_start(i, 1) + framelist(i, 1) - 1;
    end

    for i = 1:size(framelist, 1)
        data_by_run{i} = concatenated_timeseries.cdata(:, framelist_start(i):framelist_stop(i));
    end

    run_number_to_index = containers.Map(run_numbers, 1:numel(run_numbers));
    run_order_indices = arrayfun(@(x) run_number_to_index(x), run_order);
    rearranged_data = data_by_run{run_order_indices(1)};
    
    for k = 2:length(run_order_indices)
        rearranged_data = [rearranged_data, data_by_run{run_order_indices(k)}];
    end

elseif strcmp(shuffle_option, 'percent')
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_percent_order');
        chunk_size_TRs = round(total_TRs * (shuffle_chunk_size / 100));
        num_chunks = ceil(total_TRs / chunk_size_TRs);
    else
        chunk_size_TRs = round(total_TRs * (shuffle_chunk_size / 100));
        num_chunks = ceil(total_TRs / chunk_size_TRs);
        shuffled_percent_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_percent_order(i, :) = randperm(num_chunks);
        end
        save(shuffled_mat_path, 'shuffled_percent_order');
    end

    percent_order = shuffled_percent_order(permnum, :);
    chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    chunk_sizes(end) = total_TRs - chunk_size_TRs * (num_chunks - 1);
    data_chunks = mat2cell(data, size(data, 1), chunk_sizes);
    shuffled_data_chunks = data_chunks(percent_order);
    rearranged_data = cat(2, shuffled_data_chunks{:});

elseif strcmp(shuffle_option, 'minutes')
    chunk_size_TRs = round((shuffle_chunk_size * 60) / TR);
    num_chunks = ceil(total_TRs / chunk_size_TRs);
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-minute_chunks_order_sub-' SUB '_ses-' SES '.mat']);
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_minute_order');
    else
        shuffled_minute_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_minute_order(i, :) = randperm(num_chunks);
        end
        save(shuffled_mat_path, 'shuffled_minute_order');
    end

    minute_order = shuffled_minute_order(permnum, :);
    chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    chunk_sizes(end) = total_TRs - chunk_size_TRs * (num_chunks - 1);
    data_chunks = mat2cell(data, size(data, 1), chunk_sizes);
    shuffled_data_chunks = data_chunks(minute_order);
    rearranged_data = cat(2, shuffled_data_chunks{:});

elseif strcmp(shuffle_option, 'TRs')
    num_TRs = total_TRs;
    num_chunks = num_TRs;
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_TR_order_sub-' SUB '_ses-' SES '.mat']);
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order');
    else
        shuffled_TR_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_TR_order(i, :) = randperm(num_chunks);
        end
        save(shuffled_mat_path, 'shuffled_TR_order');
    end

    TR_order = shuffled_TR_order(permnum, :);
    rearranged_data = data(:, TR_order);

elseif strcmp(shuffle_option, 'bootstrap')
    % Bootstrapping with replacement
    num_TRs = total_TRs;
    num_chunks = num_TRs;
    shuffled_mat_path = fullfile(BASEDIR, ['bootstrap_TR_order_sub-' SUB '_ses-' SES '.mat']);
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order');
    else
    shuffled_TR_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_TR_order(i, :) = randi(total_TRs, 1, total_TRs); % Random indices with replacement
            %bootstrap_indices = randi(total_TRs, 1, total_TRs);  % Random indices with replacement
        end
        save(shuffled_mat_path, 'shuffled_TR_order');
    end
    TR_order = shuffled_TR_order(permnum, :);
    rearranged_data = data(:, TR_order);
    %rearranged_data = data(:, bootstrap_indices);
end

% Construct the new timeseries
new_timeseries = concatenated_timeseries;
new_timeseries.cdata = rearranged_data;
new_timeseries.diminfo{1,2}.length = size(rearranged_data, 2);

% Save the new timeseries
cifti_write(new_timeseries, [infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries.dtseries.nii']);

% Load motion file and create masks
load([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-dcan_qc_power_2014_FD_only.mat']);

% Pick fd traces with fitting FD value
for i = 1:size(motion_data, 2)
    list_thresholds(i, 1) = motion_data{1, i}.FD_threshold;
end
index = find(list_thresholds == FD);

fd_vector = motion_data{1, index}.frame_removal;
retained_frames = abs(fd_vector - 1);

if strcmp(shuffle_option, 'run')
    % Existing code for run-based motion data shuffling
    for i = 1:size(framelist, 1)
        fd_by_run{i} = retained_frames(framelist_start(i):framelist_stop(i));
    end

    k = 1;
    rearranged_fd = [fd_by_run{1, run_order_indices(k)}];
    while k < size(run_order_indices, 2)
        rearranged_fd = [rearranged_fd; fd_by_run{1, run_order_indices(k+1)}];
        k = k + 1;
    end

elseif strcmp(shuffle_option, 'percent')
    motion_chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    motion_chunk_sizes(end) = size(retained_frames, 1) - chunk_size_TRs * (num_chunks - 1);
    fd_chunks = mat2cell(retained_frames, motion_chunk_sizes, 1);
    shuffled_fd_chunks = fd_chunks(percent_order);
    rearranged_fd = cat(1, shuffled_fd_chunks{:});

elseif strcmp(shuffle_option, 'minutes')
    motion_chunk_sizes = chunk_sizes;
    fd_chunks = mat2cell(retained_frames, motion_chunk_sizes, 1);
    shuffled_fd_chunks = fd_chunks(minute_order);
    rearranged_fd = cat(1, shuffled_fd_chunks{:});

elseif strcmp(shuffle_option, 'TRs')
    rearranged_fd = retained_frames(TR_order);

elseif strcmp(shuffle_option, 'bootstrap')
    % Bootstrapping with replacement for motion data
    %bootstrap_indices = randi(total_TRs, 1, total_TRs);
    rearranged_fd = retained_frames(TR_order);
end

good_frames = find(rearranged_fd == 1);

motion_data{1, index}.frame_removal = abs(rearranged_fd - 1);
motion_data{1, index}.total_frame_count = size(rearranged_fd, 1);
motion_data{1, index}.remaining_frame_count = size(good_frames, 1);
motion_data{1, index}.remaining_seconds = size(good_frames, 1) * TR;
save([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-filtered_motion_mask.mat'], 'motion_data');

%% step 3.3, create masks and write them to tmp space
mkdir([infolder '/masks'])

% Calculate the number of frames corresponding to MAXMIN minutes
cap = round(MAXMIN * 60 / TR);

% Initialize the ground truth mask with zeros
mask_gt = zeros(size(rearranged_fd));

% Total number of good frames
num_good_frames = length(good_frames);

if num_good_frames >= cap * 2
    % Enough frames for two halves
    start_idx = cap + 1;
    end_idx = cap * 2;
    mask_indices = good_frames(start_idx:end_idx);
    mask_gt(mask_indices) = 1;
    used_minutes = (length(mask_indices) * TR) / 60;
    disp(['Using frames ' num2str(mask_indices(1)) ' to ' num2str(mask_indices(end)) ...
        ' for ground truth (' num2str(used_minutes) ' minutes).']);
elseif num_good_frames >= cap
    % Not enough for two halves, but enough for one cap
    disp('Not enough data for two halves; using the last data frames for ground truth.');
    start_idx = num_good_frames - cap + 1;
    end_idx = num_good_frames;
    mask_indices = good_frames(start_idx:end_idx);
    mask_gt(mask_indices) = 1;
    used_minutes = (length(mask_indices) * TR) / 60;
    disp(['Using frames ' num2str(mask_indices(1)) ' to ' num2str(mask_indices(end)) ...
        ' for ground truth (' num2str(used_minutes) ' minutes).']);
elseif num_good_frames > 0
    % Not enough data for one cap, use all available good frames
    disp('Not enough data for full cap; using all available good frames for ground truth.');
    mask_indices = good_frames;
    mask_gt(mask_indices) = 1;
    used_minutes = (length(mask_indices) * TR) / 60;
    disp(['Using frames ' num2str(mask_indices(1)) ' to ' num2str(mask_indices(end)) ...
        ' for ground truth (' num2str(used_minutes) ' minutes).']);
else
    % No good frames available
    error('No good frames available to create ground truth mask.');
end

% Write the ground truth mask to a text file
writematrix(mask_gt, [infolder '/masks/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(MAXMIN) 'min.txt']);

% mask groundtruth - start after MAXMIN
%cap=round(MAXMIN*60/TR);
%if size(good_frames,1)>cap*2
%    mask_gt=zeros(size(rearranged_fd));
%    mask_gt(good_frames(cap+1:cap*2))=1;
%else
%    error('not enough data, error line 218')
%end

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
% holdout is data up to a given percent of the data
holdout_size_TRs = round(total_TRs * (holdout_pct / 100));
unused_size_TRs = size(good_frames,1) - holdout_size_TRs;
holdout_MINs = floor(holdout_size_TRs * TR / 60);
unused_MINs = floor(unused_size_TRs * TR / 60);
mkdir([infolder '/masks_holdout'])

if holdout_pct < 100
    % Mask groundtruth - start after MAXMIN
    if size(good_frames,1) > holdout_size_TRs
        mask_gt = zeros(size(rearranged_fd));
        mask_gt(good_frames(:)) = 1;
    else
        error('not enough data, error line 249')
    end
    TotalGoodMins = floor(size(good_frames,1) * TR / 60);
    writematrix(mask_gt, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(TotalGoodMins) 'min.txt']);

    % Mask half 1 for every minute defined in MIN_X
    MIN_X = [1:holdout_MINs];
    for i = 1:size(MIN_X,2)
        framecount = round(MIN_X(i) * 60 / TR);
        mask_h1 = zeros(size(rearranged_fd));
        mask_h1(good_frames(1:framecount)) = 1;
        writematrix(mask_h1, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
    end

    % Mask unused - start after MAXMIN
    cap = round(holdout_MINs * 60 / TR);
    if size(good_frames,1) > cap
        mask_unused = zeros(size(rearranged_fd));
        mask_unused(good_frames(cap + 1:end)) = 1;
    else
        error('not enough data, error line 269')
    end
    writematrix(mask_unused, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_unused_' num2str(unused_MINs) 'min.txt']);
end

% run this if less that 100 percent, but if 100 percent, recalculate holdout mins based on total good frames. 
if holdout_pct < 100
    cap = round(holdout_MINs * 60 / TR);
    if size(good_frames, 1) > cap
        mask_holdout = zeros(size(rearranged_fd));
        mask_holdout(good_frames(1:cap)) = 1;
    else
        error('Not enough data for the specified holdout percentage, error at line 280');
    end
else
    % Calculate new holdout_MINs based on total good frames
    TotalGoodMins = floor(size(good_frames, 1) * TR / 60);
    holdout_MINs = TotalGoodMins;
    
    % Create the holdout mask
    mask_holdout = zeros(size(rearranged_fd));
    mask_holdout(good_frames(1:end)) = 1;
end

% Save the holdout mask
writematrix(mask_holdout, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_holdout_' num2str(holdout_MINs) 'min.txt']);

fprintf('Result: %f, %f\n', holdout_MINs, TotalGoodMins);



end


