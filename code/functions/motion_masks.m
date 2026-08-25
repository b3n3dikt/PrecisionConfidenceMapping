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

% Load motion file and create masks
load([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-dcan_qc_power_2014_FD_only.mat']);

% Pick fd traces with fitting FD value
for i = 1:size(motion_data, 2)
    list_thresholds(i, 1) = motion_data{1, i}.FD_threshold;
end
index = find(list_thresholds == FD);

fd_vector = motion_data{1, index}.frame_removal;
retained_frames = abs(fd_vector - 1);

good_frames = find(retained_frames == 1);

motion_data{1, index}.frame_removal = abs(retained_frames - 1);
motion_data{1, index}.total_frame_count = size(retained_frames, 1);
motion_data{1, index}.remaining_frame_count = size(good_frames, 1);
motion_data{1, index}.remaining_seconds = size(good_frames, 1) * TR;
save([infolder '/sub-' SUB '_ses-' SES '_task-' TASK '_desc-filtered_motion_mask.mat'], 'motion_data');

%% step 3.3, create masks and write them to tmp space
mkdir([infolder '/masks'])

% mask groundtruth - start after MAXMIN
cap=round(MAXMIN*60/TR);
if size(good_frames,1)>cap*2
    mask_gt=zeros(size(retained_frames));
    mask_gt(good_frames(cap+1:cap*2))=1;
else
    error('not enough data, error line 218')
end

writematrix(mask_gt, [infolder '/masks/sub-' SUB '_ses-' SES '_mask_groundtruth_' num2str(MAXMIN) 'min.txt']);

%mask half 1 for every minute defined in MIN_X
MIN_X=[1:MAXMIN];

for i=1:size(MIN_X,2)
    framecount=round(MIN_X(i)*60/TR);
    mask_h1=zeros(size(retained_frames));
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
        mask_gt = zeros(size(retained_frames));
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
        mask_h1 = zeros(size(retained_frames));
        mask_h1(good_frames(1:framecount)) = 1;
        writematrix(mask_h1, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_half1_' num2str(MIN_X(i)) 'min.txt']);
    end

    % Mask unused - start after MAXMIN
    cap = round(holdout_MINs * 60 / TR);
    if size(good_frames,1) > cap
        mask_unused = zeros(size(retained_frames));
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
        mask_holdout = zeros(size(retained_frames));
        mask_holdout(good_frames(1:cap)) = 1;
    else
        error('Not enough data for the specified holdout percentage, error at line 280');
    end
else
    % Calculate new holdout_MINs based on total good frames
    TotalGoodMins = floor(size(good_frames, 1) * TR / 60);
    holdout_MINs = TotalGoodMins;
    
    % Create the holdout mask
    mask_holdout = zeros(size(retained_frames));
    mask_holdout(good_frames(1:end)) = 1;
end

% Save the holdout mask
writematrix(mask_holdout, [infolder '/masks_holdout/sub-' SUB '_ses-' SES '_mask_holdout_' num2str(holdout_MINs) 'min.txt']);

fprintf('Result: %f, %f\n', holdout_MINs, TotalGoodMins);



end


