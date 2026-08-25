function extract_minutes_dtseries_and_motion(infile, motionfile, outfolder, TR, minutes, keep_from, runperm)

    % Set default value for runperm if it's not provided

    if nargin < 7
        runperm = 1;
    end

    % Add paths to necessary toolboxes
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    % Seed the random number generator with the permutation number
    rng(runperm);

   % Extract subject, session, and task information from the infile path
    [SUB, SES, TASK] = extract_sub_ses_task_from_path(infile);
    fprintf('Processing data for Subject: %s, Session: %s, Task: %s\n', SUB, SES, TASK);

    % Load the input dtseries file
    concatenated_timeseries = cifti_read(infile);
    data = concatenated_timeseries.cdata;

    % Load the motion file
    load(motionfile);
    disp(['Loaded motion file: ' motionfile]);

    % Calculate the number of TRs to keep based on the specified minutes
    minutes = str2double(minutes);
    TR = str2double(TR);
    total_TRs = size(data, 2);
    TRs_to_keep = round((minutes * 60) / TR);

    % Ensure that the number of TRs to keep does not exceed the total TRs
    if TRs_to_keep > total_TRs
        error('Requested duration exceeds the total duration of the data.');
    end

    % Determine the starting and ending TRs based on user preference
    if strcmp(keep_from, 'start')
        start_TR = 1;
        end_TR = min(TRs_to_keep, total_TRs);
    elseif strcmp(keep_from, 'end')
        start_TR = max(1, total_TRs - TRs_to_keep + 1);
        end_TR = total_TRs;
    elseif strcmp(keep_from, 'random')
        % Calculate the maximum possible starting TR
        max_start_TR = total_TRs - TRs_to_keep + 1;
        % Randomly select a starting TR
        start_TR = randi([1, max_start_TR]);
        end_TR = start_TR + TRs_to_keep - 1;
    else
        error('Invalid option for keep_from. Use "start", "end", or "random".');
    end

    % Extract the specified TR range from the data
    new_data = data(:, start_TR:end_TR);

    % Create new dtseries object
    new_timeseries = concatenated_timeseries;
    new_timeseries.cdata = new_data;
    % Update the dimension info for the new number of timepoints
    new_timeseries.diminfo{1,2}.length = size(new_data, 2);

    % Save the new dtseries file
    new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s-%sminutes_truncated_bold.dtseries.nii', SUB, SES, TASK, num2str(minutes)));
    cifti_write(new_timeseries, new_infile);
    fprintf('Saved new dtseries file: %s\n', new_infile);

    % Adjust motion data for the new file
    for index = 1:size(motion_data, 2)
        % Extract motion data for the specified TR range
        new_motion_data = motion_data{1, index}.frame_removal(start_TR:end_TR);

        % Update motion file fields for each motion data cell
        motion_data{1, index}.frame_removal = new_motion_data;
        motion_data{1, index}.total_frame_count = length(new_motion_data);
        % Assuming 0 indicates a good frame
        motion_data{1, index}.remaining_frame_count = sum(new_motion_data == 0);
        motion_data{1, index}.remaining_seconds = motion_data{1, index}.remaining_frame_count * TR;
    end

    % Save the updated motion file
    new_motionfile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s-%sminutes_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK, num2str(minutes)));
    save(new_motionfile, 'motion_data');
    fprintf('Saved new motion file: %s\n', new_motionfile);
end
