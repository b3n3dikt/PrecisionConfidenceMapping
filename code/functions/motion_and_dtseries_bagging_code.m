function motion_and_dtseries_bagging_code(SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct)

% Display the function call for easy rerun
disp("matlab call for function")
inputdisp = sprintf('motion_and_dtseries_bagging_cleaned(''%s'', ''%s'', %f, ''%s'', %f, %d, %d, ''%s'', ''%s'', ''%s'', %d, ''%s'', %d, %f);', ...
    SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct);
disp(inputdisp);

addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

% Parameters
shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-percent_order_sub-' SUB '_ses-' SES '.mat']);

% Load concatenated time series (the "original," uncleaned data)
concatenated_timeseries = cifti_read(infile);
all_data = concatenated_timeseries.cdata;           % All frames (before FD scrubbing)
original_total_TRs = size(all_data, 2);            % Total TRs in the uncleaned data

% Load motion file
load([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-dcan_qc_power_2014_FD_only.mat']);

approx_FD_all = build_approx_FD(motion_data);  

% Identify which row in motion_data matches our chosen FD threshold
for i = 1:size(motion_data, 2)
    list_thresholds(i, 1) = motion_data{1, i}.FD_threshold;
end
index = find(list_thresholds == FD);

fd_vector = motion_data{1, index}.frame_removal;   % 1 => remove this frame, 0 => keep
retained_frames = abs(fd_vector - 1);              % 1 => keep, 0 => removed
good_frames = find(retained_frames == 1);          % Indices of frames that survived FD threshold

% -------------------------------------------------------------------------
% IMPORTANT: Motion data is made from binary masks so FD value will only be approximated using bulild_approx_FD.m
% -------------------------------------------------------------------------
data = all_data(:, good_frames);
approx_fd_good = approx_FD_all(good_frames);  % <--- subset

total_good_TRs = length(good_frames);



% Filter the data to include only 'retained_frames == 1'
data = all_data(:, good_frames);                 % Motion-scrubbed data

% Update total_TRs to reflect only the motion-scrubbed frames
total_TRs = size(data, 2);
num_permutations = 10000; % or whatever number you need

% Proceed with shuffling options
if strcmp(shuffle_option, 'run')
    % ------------------------------------------------
    % 1) run-based shuffling ...
    % ------------------------------------------------
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

    % Initialize cell array to store good frames data per run
    data_by_run = cell(1, numel(run_numbers));
    
    % Keep track of each runs start/stop
    framelist = zeros(numel(run_numbers), 1);
    framelist_start = zeros(numel(run_numbers), 1);
    framelist_stop = zeros(numel(run_numbers), 1);
    current_start = 1;

    for i = 1:numel(run_numbers)
        run_file = fullfile(run_files_dir, files(i).name);
        run_data = cifti_read(run_file);
        run_timeseries = run_data.cdata;
        run_size = size(run_timeseries, 2);
        framelist(i) = run_size;
        
        % Indices in the *original concatenated timeseries*
        framelist_start(i) = current_start;
        framelist_stop(i) = current_start + run_size - 1;
        current_start = current_start + run_size;
        
        % Among these frames, find which frames survived FD threshold
        idx = framelist_start(i):framelist_stop(i);
        run_retained_frames = retained_frames(idx);
        good_run_frames = run_retained_frames == 1;
        
        % Extract good frames from that run
        run_data_good = run_timeseries(:, good_run_frames);
        data_by_run{i} = run_data_good;
    end

    % Map run numbers to their original indices
    run_number_to_index = containers.Map(run_numbers, 1:numel(run_numbers));
    run_order_indices = arrayfun(@(x) run_number_to_index(x), run_order);

    % Concatenate in the new run order
    rearranged_data = data_by_run{run_order_indices(1)};
    for k = 2:length(run_order_indices)
        rearranged_data = [rearranged_data, data_by_run{run_order_indices(k)}];
    end

elseif strcmp(shuffle_option, 'percent')
    % ------------------------------------------------
    % 2) percent-based chunk shuffling
    % ------------------------------------------------
    total_good_TRs = size(data, 2);
    chunk_size_TRs = round(total_good_TRs * (shuffle_chunk_size / 100));
    num_chunks = ceil(total_good_TRs / chunk_size_TRs);
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-percent_order_sub-' SUB '_ses-' SES '.mat']);
    
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_percent_order');
    else
        shuffled_percent_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_percent_order(i, :) = randperm(num_chunks);
        end
        save(shuffled_mat_path, 'shuffled_percent_order');
    end

    percent_order = shuffled_percent_order(permnum, :);
    chunk_sizes = repmat(chunk_size_TRs, 1, num_chunks);
    chunk_sizes(end) = total_good_TRs - chunk_size_TRs * (num_chunks - 1);
    data_chunks = mat2cell(data, size(data, 1), chunk_sizes);
    shuffled_data_chunks = data_chunks(percent_order);
    rearranged_data = cat(2, shuffled_data_chunks{:});

elseif strcmp(shuffle_option, 'minutes')
    % ------------------------------------------------
    % 3) minute-based chunk shuffling
    % ------------------------------------------------
    total_good_TRs = size(data, 2);
    chunk_size_TRs = round((shuffle_chunk_size * 60) / TR);
    num_chunks = ceil(total_good_TRs / chunk_size_TRs);
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
    chunk_sizes(end) = total_good_TRs - chunk_size_TRs * (num_chunks - 1);
    data_chunks = mat2cell(data, size(data, 1), chunk_sizes);
    shuffled_data_chunks = data_chunks(minute_order);
    rearranged_data = cat(2, shuffled_data_chunks{:});

elseif strcmp(shuffle_option, 'TRs')
    % ------------------------------------------------
    % 4) Shuffle entire TRs
    % ------------------------------------------------
    total_good_TRs = size(data, 2);
    num_chunks = total_good_TRs;
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
    % ------------------------------------------------
    % 5) Bootstrap with replacement of all good frames
    % ------------------------------------------------
    total_good_TRs = size(data, 2);
    num_chunks = total_good_TRs;
    shuffled_mat_path = fullfile(BASEDIR, ['bootstrap_TR_order_sub-' SUB '_ses-' SES '.mat']);
    
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order');
    else
        shuffled_TR_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            % Pick from the total_good_TRs with replacement
            shuffled_TR_order(i, :) = randi(total_good_TRs, 1, total_good_TRs);
        end
        save(shuffled_mat_path, 'shuffled_TR_order');
    end

    TR_order = shuffled_TR_order(permnum, :);
    rearranged_data = data(:, TR_order);
    % Example: we might set 
    rearranged_fd = ones(total_good_TRs, 1);
    %rearranged_fd = approx_fd_good(TR_order);

elseif strcmp(shuffle_option, 'bagging')
    % ------------------------------------------------
    % 6) Bagging (bootstrap) but to a desired length in minutes
    % ------------------------------------------------
    desired_length_minutes = shuffle_chunk_size;
    desired_TRs = round(desired_length_minutes * 60 / TR);
    num_good_frames = size(data, 2);

    shuffled_mat_path = fullfile(BASEDIR, ['bagging_TR_order_' num2str(desired_length_minutes) 'min_sub-' SUB '_ses-' SES '.mat']);

    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order');
    else
        shuffled_TR_order = zeros(num_permutations, desired_TRs);
        for i = 1:num_permutations
            shuffled_TR_order(i, :) = randi(num_good_frames, 1, desired_TRs);
        end
        save(shuffled_mat_path, 'shuffled_TR_order');
    end

    TR_order = shuffled_TR_order(permnum, :);
    rearranged_data = data(:, TR_order);
    rearranged_fd = ones(desired_TRs, 1);

    %rearranged_fd = approx_fd_good(TR_order); %if actually using fd values instead of mask. 
    total_TRs = desired_TRs;

% =====================================================================
% NEW OPTION: mo_bagging
% =====================================================================
elseif strcmp(shuffle_option, 'mo_bagging')
    % In "mo_bagging", we:
    %  1) Sort the motion-scrubbed frames (i.e., 'data' and 'good_fd') from
    %     least to most motion.
    %  2) Take only the lowest-motion X% of the *original* total frames,
    %     i.e. a fraction of size(original_total_TRs) rather than size(data,2).
    %  3) Then bootstrap (with replacement) from those low-motion frames
    %     back up to the *original* data length (original_total_TRs).
    %
    % Lets say shuffle_chunk_size = 20 means "take 20% of the original
    % dataset length as the pool of lowest-motion frames, then bag them
    % back to 100% of the original length".

    % 1) Sort the good frames by ascending FD
    [sorted_fd, sorted_idx] = sort(approx_fd_good, 'ascend');
    
    % 2) Figure out how many frames we want to keep for the "pool" of
    %    lowest-motion frames. That is shuffle_chunk_size% of the
    %    ORIGINAL (uncleaned) data length.
    %    For example, if original_total_TRs = 1000 and shuffle_chunk_size=20,
    %    we want 0.20 * 1000 = 200 frames from the lowest FD.
    lowest_motion_count = round(original_total_TRs * (shuffle_chunk_size / 100));
    
    % 3) We cannot exceed total_good_TRs (since we only have so many
    %    frames after scrubbing). So let's take the min of the two:
    %lowest_motion_count = min(lowest_motion_count, total_TRs);
    lowest_motion_count = min(lowest_motion_count, total_good_TRs);


    % The actual indices (among the motion-scrubbed frames) corresponding
    % to those lowest-motion frames:

    lowest_motion_indices = sorted_idx(1:lowest_motion_count);
    
    % 4) We want to bag (bootstrap) these frames back up to the length of
    %    the ORIGINAL data. So we build or load a permutation matrix that
    %    picks from the pool "lowest_motion_count" up to "original_total_TRs".
    mo_bagging_mat_path = fullfile(BASEDIR, ...
        ['mo_bagging_TR_order_' num2str(shuffle_chunk_size) 'pct_sub-' SUB '_ses-' SES '.mat']);
    
    if exist(mo_bagging_mat_path, 'file')
        load(mo_bagging_mat_path, 'shuffled_TR_order_mo_bagging');
    else
        % Initialize a big matrix: #permutations x original_total_TRs
        shuffled_TR_order_mo_bagging = zeros(num_permutations, original_total_TRs);
        
        for i = 1:num_permutations
            % Each row is a random sample (with replacement) from
            % the [1..lowest_motion_count] pool
            shuffled_TR_order_mo_bagging(i, :) = randi(lowest_motion_count, 1, original_total_TRs);
        end
        
        save(mo_bagging_mat_path, 'shuffled_TR_order_mo_bagging');
    end
    
    % 5) For the current permutation, get the 1 x original_total_TRs row
    TR_order_in_pool = shuffled_TR_order_mo_bagging(permnum, :);
    
    % 6) Map those pool indices (1..lowest_motion_count) back to the real
    %    frame indices in 'data'.
    final_indices = lowest_motion_indices(TR_order_in_pool);
    
    % 7) Rearrange both the dtseries data and FD according to final_indices
    rearranged_data = data(:, final_indices);
    rearranged_fd = ones(length(final_indices), 1);

    %rearranged_fd   = approx_fd_good(final_indices);

    % 8) We'll set total_TRs to the original total so the rest of the
    %    script sees the final timeseries as "full length".
    total_TRs = original_total_TRs;

else
    error('Invalid shuffle_option provided.');
end

% Construct the new timeseries
new_timeseries = concatenated_timeseries;
new_timeseries.cdata = rearranged_data;
new_timeseries.diminfo{1,2}.length = size(rearranged_data, 2);

% Save the new timeseries
cifti_write(new_timeseries, [infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries.dtseries.nii']);

% Update motion data structure for the new arrangement
% For now, we can mark all frames as "kept" in the final arrangement.
motion_data{1, index}.frame_removal = zeros(size(rearranged_fd)); 
motion_data{1, index}.total_frame_count = size(rearranged_fd, 1);
motion_data{1, index}.remaining_frame_count = size(rearranged_fd, 1);
motion_data{1, index}.remaining_seconds = size(rearranged_fd, 1) * TR;
save([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-filtered_motion_mask.mat'], 'motion_data');

%% Step 3.3, create masks and write them to tmp space
mkdir([infolder '/masks'])

% Calculate the number of frames corresponding to MAXMIN minutes
cap = round(MAXMIN * 60 / TR);

num_good_frames = total_TRs;
good_frames = (1:num_good_frames)';  %#ok<NASGU> (used below)

if MAXMIN == 0
    disp('MAXMIN is zero; skipping split-half ground truth section.');
else
    % Initialize the ground truth mask with zeros
    mask_gt = zeros(total_TRs, 1);
    
    if num_good_frames >= cap * 2
        % Enough frames for two halves
        start_idx = cap + 1;
        end_idx = cap * 2;
        mask_indices = (start_idx:end_idx);
        mask_gt(mask_indices) = 1;
        used_minutes = (length(mask_indices) * TR) / 60;
        disp(['Using frames ' num2str(mask_indices(1)) ' to ' num2str(mask_indices(end)) ...
            ' for ground truth (' num2str(used_minutes) ' minutes).']);
    elseif num_good_frames >= cap
        % Not enough for two halves, but enough for one cap
        disp('Not enough data for two halves; using the last data frames for ground truth.');
        start_idx = num_good_frames - cap + 1;
        end_idx = num_good_frames;
        mask_indices = (start_idx:end_idx);
        mask_gt(mask_indices) = 1;
        used_minutes = (length(mask_indices) * TR) / 60;
        disp(['Using frames ' num2str(mask_indices(1)) ' to ' num2str(mask_indices(end)) ...
            ' for ground truth (' num2str(used_minutes) ' minutes).']);
    elseif num_good_frames > 0
        % Not enough data for one cap, use all available good frames
        disp('Not enough data for full cap; using all available good frames for ground truth.');
        mask_indices = (1:num_good_frames);
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
    
    % Mask half 1 for every minute defined in MIN_X
    MIN_X = 1:MAXMIN;
    for i = 1:length(MIN_X)
        framecount = round(MIN_X(i) * 60 / TR);
        mask_h1 = zeros(total_TRs, 1);
        if framecount <= num_good_frames
            mask_h1(1:framecount) = 1;
        else
            mask_h1(1:num_good_frames) = 1;
        end
        writematrix(mask_h1, [infolder '/masks/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
    end
end

%% Holdout masks
% Making masks for holdout, where ground truth is all of the data, and
% holdout is data up to a given percent of the data
holdout_size_TRs = round(total_TRs * (holdout_pct / 100));
unused_size_TRs = num_good_frames - holdout_size_TRs;
holdout_MINs = floor(holdout_size_TRs * TR / 60);
unused_MINs = floor(unused_size_TRs * TR / 60);
mkdir([infolder '/masks_holdout'])
TotalGoodMins = floor(num_good_frames * TR / 60);

if holdout_pct < 100
    % Mask groundtruth - use all good frames
    mask_gt = ones(total_TRs, 1);
    TotalGoodMins = floor(num_good_frames * TR / 60);
    writematrix(mask_gt, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(TotalGoodMins) 'min.txt']);

    % Mask half 1 for every minute defined in MIN_X
    MIN_X = [1:holdout_MINs];
    for i = 1:length(MIN_X)
        framecount = round(MIN_X(i) * 60 / TR);
        mask_h1 = zeros(total_TRs, 1);
        if framecount <= num_good_frames
            mask_h1(1:framecount) = 1;
        else
            mask_h1(1:num_good_frames) = 1;
        end
        writematrix(mask_h1, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
    end

    % Mask unused - frames after holdout_size_TRs
    if num_good_frames > holdout_size_TRs
        mask_unused = zeros(total_TRs, 1);
        mask_unused((holdout_size_TRs + 1):end) = 1;
        writematrix(mask_unused, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_unused_' num2str(unused_MINs) 'min.txt']);
    else
        disp('Not enough data to create unused mask.');
    end
else
    % If holdout_pct is 100%, the holdout is all good frames
    holdout_MINs = floor(num_good_frames * TR / 60);
end

% Create the holdout mask
mask_holdout = zeros(total_TRs, 1);
if holdout_size_TRs <= num_good_frames
    mask_holdout(1:holdout_size_TRs) = 1;
else
    mask_holdout(1:num_good_frames) = 1;
end
writematrix(mask_holdout, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_holdout_' num2str(holdout_MINs) 'min.txt']);

fprintf('Result: %f, %f\n', holdout_MINs, TotalGoodMins);

end