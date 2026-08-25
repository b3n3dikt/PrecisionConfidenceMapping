function motion_and_dtseries_bagging_cleaned(SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct, motion_txt)

% Display the function call for easy rerun
disp("matlab call for function")
inputdisp = sprintf('motion_and_dtseries_bagging_cleaned(''%s'', ''%s'', %f, ''%s'', %f, %d, %d, ''%s'', ''%s'', ''%s'', %d, ''%s'', %d, %f);', ...
    SUB, SES, FD, TASK, TR, MAXMIN, permnum, infolder, infile, BASEDIR, intrp_noise, shuffle_option, shuffle_chunk_size, holdout_pct);
disp(inputdisp);

if nargin < 15, motion_txt = ''; end

% STANDALONE PCM: cifti-matlab is already on path via MATLAB_ADDPATH in config.sh.

% Load concatenated time series
concatenated_timeseries = cifti_read(infile);
data = concatenated_timeseries.cdata;

% ── Load motion / build good-frame mask ──────────────────────────────────────
if ~isempty(motion_txt)
    % Custom binary mask (.txt): 1 = keep, 0 = remove
    raw = readmatrix(motion_txt);
    retained_frames = raw(:);
    good_frames = find(retained_frames == 1);
    data = data(:, good_frames);

    % Synthetic motion_data so downstream .mat save still works
    index = 1;
    motion_data = cell(1,1);
    motion_data{1,1}.FD_threshold          = FD;
    motion_data{1,1}.frame_removal         = double(~logical(retained_frames));
    motion_data{1,1}.total_frame_count     = numel(retained_frames);
    motion_data{1,1}.remaining_frame_count = numel(good_frames);
    motion_data{1,1}.remaining_seconds     = numel(good_frames) * TR;
    fprintf('[motion_bagging] txt mask: %d / %d frames retained\n', numel(good_frames), numel(retained_frames));
else
    % Load motion file
    load([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-dcan_qc_power_2014_FD_only.mat']);

    for i = 1:size(motion_data, 2)
        list_thresholds(i, 1) = motion_data{1, i}.FD_threshold;
    end
    index = find(list_thresholds == FD);

    fd_vector = motion_data{1, index}.frame_removal;
    retained_frames = abs(fd_vector - 1);

    good_frames = find(retained_frames == 1);
    data = data(:, good_frames);
end

% Update total_TRs
total_TRs = size(data, 2);

% Shuffle-order cache files (built below, saved in BASEDIR and shared across the
% permutations of a run) are keyed by data length via ntr_tag. BASEDIR is the same
% for every truncation of a subject/session, so without this a cached order built
% for a longer scan would be loaded for a shorter truncation and index past the
% data -> "Index in position 2 exceeds array bounds". Keying by total_TRs keeps the
% cache shared within a truncation but separate across truncations / FD thresholds.
ntr_tag = ['_nTRs-' num2str(total_TRs)];

num_permutations = 10000; % or whatever number you need

% Proceed with shuffling options

if strcmp(shuffle_option, 'run')
    % Adjusted code for shuffling based on runs with good frames only
    run_files_dir = fileparts(infile);
    files = dir(fullfile(run_files_dir, ['sub-' SUB '_ses-' SES '_task-' TASK '_run-*_space-fsLR_den-91k_desc-interpolated_bold.dtseries.nii']));
    run_numbers = regexp({files.name}, 'run-(\d+)_', 'tokens');
    run_numbers = cellfun(@(x) str2double(x{1}), run_numbers);
    mat_file_path = fullfile(BASEDIR, ['rand_order_runs_sub-' SUB '_ses-' SES ntr_tag '.mat']);
    
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
    framelist = zeros(numel(run_numbers), 1);
    
    % Get start and stop indices for each run
    framelist_start = zeros(numel(run_numbers), 1);
    framelist_stop = zeros(numel(run_numbers), 1);
    current_start = 1;
    for i = 1:numel(run_numbers)
        run_file = fullfile(run_files_dir, files(i).name);
        run_data = cifti_read(run_file);
        run_timeseries = run_data.cdata;
        run_size = size(run_timeseries, 2);
        framelist(i) = run_size;
        
        % Indices in the concatenated timeseries
        framelist_start(i) = current_start;
        framelist_stop(i) = current_start + run_size - 1;
        current_start = current_start + run_size;
        
        % Get retained frames for this run
        idx = framelist_start(i):framelist_stop(i);
        run_retained_frames = retained_frames(idx);
        good_run_frames = run_retained_frames == 1;
        
        % Extract good frames data for this run
        run_data_good = run_timeseries(:, good_run_frames);
        data_by_run{i} = run_data_good;
    end

    % Map run numbers to indices
    run_number_to_index = containers.Map(run_numbers, 1:numel(run_numbers));
    run_order_indices = arrayfun(@(x) run_number_to_index(x), run_order);

    % Concatenate good frames data in shuffled run order
    rearranged_data = data_by_run{run_order_indices(1)};
    for k = 2:length(run_order_indices)
        rearranged_data = [rearranged_data, data_by_run{run_order_indices(k)}];
    end

elseif strcmp(shuffle_option, 'percent')
    total_good_TRs = size(data, 2);
    chunk_size_TRs = round(total_good_TRs * (shuffle_chunk_size / 100));
    num_chunks = ceil(total_good_TRs / chunk_size_TRs);
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-percent_order_sub-' SUB '_ses-' SES ntr_tag '.mat']);
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
    total_good_TRs = size(data, 2);
    chunk_size_TRs = round((shuffle_chunk_size * 60) / TR);
    num_chunks = ceil(total_good_TRs / chunk_size_TRs);
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_' num2str(shuffle_chunk_size) '-minute_chunks_order_sub-' SUB '_ses-' SES ntr_tag '.mat']);
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
    total_good_TRs = size(data, 2);
    num_chunks = total_good_TRs;
    shuffled_mat_path = fullfile(BASEDIR, ['shuffled_TR_order_sub-' SUB '_ses-' SES ntr_tag '.mat']);
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
    total_good_TRs = size(data, 2);
    num_chunks = total_good_TRs;
    shuffled_mat_path = fullfile(BASEDIR, ['bootstrap_TR_order_sub-' SUB '_ses-' SES ntr_tag '.mat']);
    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order');
    else
        shuffled_TR_order = zeros(num_permutations, num_chunks);
        for i = 1:num_permutations
            shuffled_TR_order(i, :) = randi(total_good_TRs, 1, total_good_TRs); % Random indices with replacement
        end
        save(shuffled_mat_path, 'shuffled_TR_order');
    end
    TR_order = shuffled_TR_order(permnum, :);
    rearranged_data = data(:, TR_order);
    rearranged_fd = ones(total_good_TRs, 1);


elseif strcmp(shuffle_option, 'bagging')
    % New 'bagging' option
    % New 'bagging' option
    % 'shuffle_chunk_size' represents the desired length in minutes
    desired_length_minutes = shuffle_chunk_size;
    desired_TRs = round(desired_length_minutes * 60 / TR);

    num_good_frames = size(data, 2);

    shuffled_mat_path = fullfile(BASEDIR, ['bagging_TR_order_' num2str(desired_length_minutes) 'min_sub-' SUB '_ses-' SES ntr_tag '.mat']);

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
    total_TRs = desired_TRs;

elseif strcmp(shuffle_option, 'bootstrap_variable')
    % Bootstrap with replacement, then keep a random-length prefix.
    %
    % WHY: standard bootstrap always uses the same number of TRs. This
    % method adds a second source of variability — each permutation also
    % uses a *different amount* of data, drawn uniformly between a
    % user-specified minimum and the full good-frame count. The result is
    % that high-confidence vertices must hold their assignment not only
    % under bootstrap resampling noise but also across a range of data
    % lengths. Confidence thresholds are effectively more stringent: a
    % vertex needs consistent assignment even when some permutations only
    % have ~min_minutes of (resampled) data to work with.
    %
    % 'shuffle_chunk_size' = minimum duration in minutes (default: 5).
    % Each permutation draws:
    %   (a) a bootstrap TR order (with replacement, full length)
    %   (b) a random keep length in [min_frames, total_good_TRs]
    % Both are pre-generated for all 10000 permutations and saved so
    % reruns are reproducible.

    total_good_TRs = size(data, 2);
    min_frames = max(1, round(shuffle_chunk_size * 60 / TR));

    % Clamp minimum to available data (handles high-motion subjects)
    if min_frames > total_good_TRs
        warning(['bootstrap_variable: min_frames (%d) > total_good_TRs (%d). ' ...
                 'Clamping minimum to 1 frame.'], min_frames, total_good_TRs);
        min_frames = 1;
    end

    shuffled_mat_path = fullfile(BASEDIR, ...
        ['bootstrap_variable_min' num2str(shuffle_chunk_size) 'min_sub-' SUB '_ses-' SES ntr_tag '.mat']);

    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'shuffled_TR_order', 'variable_lengths');
    else
        shuffled_TR_order = zeros(num_permutations, total_good_TRs);
        variable_lengths  = zeros(num_permutations, 1);
        for i = 1:num_permutations
            shuffled_TR_order(i, :) = randi(total_good_TRs, 1, total_good_TRs);
            variable_lengths(i)     = randi([min_frames, total_good_TRs]);
        end
        save(shuffled_mat_path, 'shuffled_TR_order', 'variable_lengths');
    end

    TR_order  = shuffled_TR_order(permnum, :);
    keep_TRs  = variable_lengths(permnum);

    bootstrapped = data(:, TR_order);          % full bootstrap
    rearranged_data = bootstrapped(:, 1:keep_TRs);  % truncate to random length
    rearranged_fd   = ones(keep_TRs, 1);
    total_TRs       = keep_TRs;

    disp(['[bootstrap_variable] perm=' num2str(permnum) ...
          ' keep_TRs=' num2str(keep_TRs) ...
          ' (' num2str(keep_TRs * TR / 60, '%.1f') ' min)']);

elseif strcmp(shuffle_option, 'subsample')
    % Random-length contiguous segment of the *real* (unshuffled) data.
    %
    % WHY: unlike bootstrap, this method does not resample TRs — it uses
    % actual data. Each permutation takes a contiguous window of random
    % length (between min_minutes and full scan length) starting at a
    % random position within the good frames. This tests temporal
    % stationarity and data sufficiency: does a vertex receive the same
    % network assignment regardless of which part of the scan is used and
    % how long that window is? Confidence maps from this method reflect
    % stability of the signal itself across time and quantity of data,
    % rather than resampling stability. Useful to run alongside bootstrap
    % to distinguish "the data is variable" from "the data is insufficient."
    %
    % 'shuffle_chunk_size' = minimum duration in minutes (default: 5).
    % Each permutation independently draws:
    %   (a) a random segment length in [min_frames, total_good_TRs]
    %   (b) a random start index such that the window fits within the data
    % Both are pre-generated and saved for reproducibility.

    total_good_TRs = size(data, 2);
    min_frames = max(1, round(shuffle_chunk_size * 60 / TR));

    % Clamp minimum to available data
    if min_frames > total_good_TRs
        warning(['subsample: min_frames (%d) > total_good_TRs (%d). ' ...
                 'Clamping minimum to 1 frame.'], min_frames, total_good_TRs);
        min_frames = 1;
    end

    shuffled_mat_path = fullfile(BASEDIR, ...
        ['subsample_min' num2str(shuffle_chunk_size) 'min_sub-' SUB '_ses-' SES ntr_tag '.mat']);

    if exist(shuffled_mat_path, 'file')
        load(shuffled_mat_path, 'subsample_lengths', 'subsample_starts');
    else
        subsample_lengths = zeros(num_permutations, 1);
        subsample_starts  = zeros(num_permutations, 1);
        for i = 1:num_permutations
            seg_len = randi([min_frames, total_good_TRs]);
            subsample_lengths(i) = seg_len;
            subsample_starts(i)  = randi(max(1, total_good_TRs - seg_len + 1));
        end
        save(shuffled_mat_path, 'subsample_lengths', 'subsample_starts');
    end

    seg_len   = subsample_lengths(permnum);
    start_idx = subsample_starts(permnum);
    end_idx   = start_idx + seg_len - 1;

    rearranged_data = data(:, start_idx:end_idx);
    rearranged_fd   = ones(seg_len, 1);
    total_TRs       = seg_len;

    disp(['[subsample] perm=' num2str(permnum) ...
          ' start=' num2str(start_idx) ...
          ' length=' num2str(seg_len) ...
          ' (' num2str(seg_len * TR / 60, '%.1f') ' min)']);

else
    error('Invalid shuffle_option provided.');
end

% Construct the new timeseries
new_timeseries = concatenated_timeseries;
new_timeseries.cdata = rearranged_data;
new_timeseries.diminfo{1,2}.length = size(rearranged_data, 2);

% Save the new timeseries
cifti_write(new_timeseries, [infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries.dtseries.nii']);

% Update motion data structure
motion_data{1, index}.frame_removal = zeros(size(rearranged_fd)); % All frames are good
motion_data{1, index}.total_frame_count = size(rearranged_fd, 1);
motion_data{1, index}.remaining_frame_count = size(rearranged_fd, 1);
motion_data{1, index}.remaining_seconds = size(rearranged_fd, 1) * TR;
save([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-filtered_motion_mask.mat'], 'motion_data');

%% Step 3.3, create masks and write them to tmp space
mkdir([infolder '/masks'])

% For 'bagging' option, we need to adjust the mask creation


% Calculate the number of frames corresponding to MAXMIN minutes
cap = round(MAXMIN * 60 / TR);

% Initialize variables that will be used later
num_good_frames = total_TRs;
good_frames = (1:num_good_frames)';

% Check if MAXMIN is zero
if MAXMIN == 0
    disp('MAXMIN is zero; skipping split-half ground truth section.');
else
    % Initialize the ground truth mask with zeros
    mask_gt = zeros(total_TRs, 1);
    
    % Proceed with the split-half ground truth section
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
    
    % Mask half 1 for every minute defined in MIN_X
    MIN_X = 1:MAXMIN;
    for i = 1:length(MIN_X)
        framecount = round(MIN_X(i) * 60 / TR);
        mask_h1 = zeros(total_TRs, 1);
        if framecount <= num_good_frames
            mask_h1(good_frames(1:framecount)) = 1;
        else
            mask_h1(good_frames) = 1;
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
            mask_h1(good_frames(1:framecount)) = 1;
        else
            mask_h1(good_frames) = 1;
        end
        writematrix(mask_h1, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
    end

    % Mask unused - frames after holdout_size_TRs
    if num_good_frames > holdout_size_TRs
        mask_unused = zeros(total_TRs, 1);
        mask_unused(good_frames(holdout_size_TRs + 1:end)) = 1;
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
    mask_holdout(good_frames(1:holdout_size_TRs)) = 1;
else
    mask_holdout(good_frames) = 1;
end
writematrix(mask_holdout, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_holdout_' num2str(holdout_MINs) 'min.txt']);

fprintf('Result: %f, %f\n', holdout_MINs, TotalGoodMins);

end



