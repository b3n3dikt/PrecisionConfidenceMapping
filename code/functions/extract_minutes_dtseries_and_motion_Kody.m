function extract_minutes_dtseries_and_motion(infile, motionfile, outfolder, TR, minutes, keep_from, SUB, SES, TASK)
    % Add paths to necessary toolboxes
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
    % Check if SUB, SES, and TASK were provided as inputs
    if nargin < 7  % If less than 7 arguments were passed
        SUB = [];  % Set SUB to empty if not provided
    end
    if nargin < 8  % If less than 8 arguments were passed
        SES = [];  % Set SES to empty if not provided
    end
    if nargin < 9  % If less than 9 arguments were passed
        TASK = []; % Set TASK to empty if not provided
    end

    % Only extract SUB, SES, and TASK if they are not provided
    if isempty(SUB) || isempty(SES) || isempty(TASK)
        [SUB, SES, TASK] = extract_sub_ses_task_from_path(infile);
    end

    % Now you can use SUB, SES, and TASK in your subsequent code
    fprintf('Processing data for Subject: %s, Session: %s, Task: %s\n', SUB, SES, TASK);
   
    
    % Load the input dtseries file
    concatenated_timeseries = cifti_read(infile);
    data = concatenated_timeseries.cdata;

    % Load the motion file
    load(motionfile);
    disp(motionfile)
    
    % Calculate the number of TRs to keep based on the specified minutes
    minutes = str2double(minutes);
    TR = str2double(TR);
    total_TRs = size(data, 2);
    TRs_to_keep = round((minutes * 60) / TR);
    
    % Determine the starting and ending TRs based on user preference
    if strcmp(keep_from, 'start')
        start_TR = 1;
        end_TR = min(TRs_to_keep, total_TRs);
    elseif strcmp(keep_from, 'end')
        start_TR = max(1, total_TRs - TRs_to_keep + 1);
        end_TR = total_TRs;
    else
        error('Invalid option for keep_from. Use "start" or "end".');
    end

    % Extract the specified TR range from the data
    new_data = data(:, start_TR:end_TR);

    % Create new dtseries object
    new_timeseries = concatenated_timeseries;
    new_timeseries.cdata = new_data;
    new_timeseries.diminfo{1,2}.length = size(new_data, 2);

    % Save the new dtseries file
    new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s-%sminutes_truncated_bold.dtseries.nii', SUB, SES, TASK, num2str(minutes)));
    cifti_write(new_timeseries, new_infile);
    
    % % Adjust motion data for the new file
    % if strcmp(keep_from, 'start')
    %     new_motion_data = motion_data{1,1}.frame_removal(start_TR:end_TR);
    % elseif strcmp(keep_from, 'end')
    %     new_motion_data = motion_data{1,1}.frame_removal(start_TR:end_TR);
    % end
    % 
    % % Update motion file fields
    % motion_data{1,1}.frame_removal = new_motion_data;
    % motion_data{1,1}.total_frame_count = length(new_motion_data);
    % motion_data{1,1}.remaining_frame_count = sum(new_motion_data == 0); % Assuming 0 indicates a good frame
    % motion_data{1,1}.remaining_seconds = motion_data{1,1}.remaining_frame_count * TR;

    for index = 1:size(motion_data, 2)
        % Adjust motion data for the new file
        if strcmp(keep_from, 'start')
            new_motion_data = motion_data{1, index}.frame_removal(start_TR:end_TR);
        elseif strcmp(keep_from, 'end')
            new_motion_data = motion_data{1, index}.frame_removal(start_TR:end_TR);
        end
        
        % Update motion file fields for each motion data cell
        motion_data{1, index}.frame_removal = new_motion_data;
        motion_data{1, index}.total_frame_count = length(new_motion_data);
        motion_data{1, index}.remaining_frame_count = sum(new_motion_data == 0); % Assuming 0 indicates a good frame
        motion_data{1, index}.remaining_seconds = motion_data{1, index}.remaining_frame_count * TR;
    end
    
    % Save the updated motion file
    new_motionfile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s-%sminutes_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK, num2str(minutes)));
    save(new_motionfile, 'motion_data');



end