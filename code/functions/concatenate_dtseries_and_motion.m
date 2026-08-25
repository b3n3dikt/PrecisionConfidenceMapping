function concatenate_dtseries_and_motion(dtseries1, motionfile1, dtseries2, motionfile2, outfolder, TR, SUB, SES, TASK)
    % Add paths to necessary toolboxes
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    % If SUB, SES, and TASK are not provided, extract from the first dtseries file
    if nargin < 8 || isempty(SUB) || isempty(SES) || isempty(TASK)
        [SUB1, SES1, TASK1] = extract_sub_ses_task_from_path(dtseries1);
        if isempty(SUB)
            SUB = SUB1;
        end
        if isempty(SES)
            SES = SES1;
        end
        if isempty(TASK)
            TASK = TASK1;
        end
    end

    % Now you can use SUB, SES, and TASK in your subsequent code
    fprintf('Processing data for Subject: %s, Session: %s, Task: %s\n', SUB, SES, TASK);

    % Load the first dtseries file
    timeseries1 = cifti_read(dtseries1);
    data1 = timeseries1.cdata;

    % Load the second dtseries file
    timeseries2 = cifti_read(dtseries2);
    data2 = timeseries2.cdata;

    % Concatenate the dtseries data along the time dimension (2nd dimension)
    concatenated_data = [data1, data2];

    % Create new dtseries object for the concatenated data
    concatenated_timeseries = timeseries1;
    concatenated_timeseries.cdata = concatenated_data;
    concatenated_timeseries.diminfo{1,2}.length = size(concatenated_data, 2);

    % Save the concatenated dtseries file
    new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_bold.dtseries.nii', SUB, SES, TASK));
    cifti_write(concatenated_timeseries, new_infile);

    % Load the first motion file
    load(motionfile1, 'motion_data');
    motion_data1 = motion_data;

    % Load the second motion file
    load(motionfile2, 'motion_data');
    motion_data2 = motion_data;

    % Concatenate the motion data
    motion_data = cell(size(motion_data1));
    for index = 1:size(motion_data1, 2)
        if isfield(motion_data1{index}, 'skip')
            motion_data{index}.skip = motion_data1{index}.skip;
        end
        if isfield(motion_data1{index}, 'epi_TR')
            motion_data{index}.epi_TR = motion_data1{index}.epi_TR;
        end
        if isfield(motion_data1{index}, 'FD_threshold')
            motion_data{index}.FD_threshold = motion_data1{index}.FD_threshold;
        end
        if isfield(motion_data1{index}, 'frame_removal') && isfield(motion_data2{index}, 'frame_removal')
            motion_data{index}.frame_removal = vertcat(motion_data1{index}.frame_removal, motion_data2{index}.frame_removal);
        else
            motion_data{index}.frame_removal = []; % Handle the case if frame_removal does not exist
        end
        motion_data{index}.total_frame_count = length(motion_data{index}.frame_removal);
        motion_data{index}.remaining_frame_count = sum(motion_data{index}.frame_removal == 0); % Assuming 0 indicates a good frame
        motion_data{index}.remaining_seconds = motion_data{index}.remaining_frame_count * str2double(TR); % Using TR passed as an input
    end

    % Save the concatenated motion file
    new_motionfile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK));
    save(new_motionfile, 'motion_data');

    fprintf('Concatenation complete. Files saved to %s\n', outfolder);
end
% function concatenate_dtseries_and_motion(dtseries1, motionfile1, dtseries2, motionfile2, outfolder, TR, SUB, SES, TASK)
%     % Add paths to necessary toolboxes
%     addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
% 
%     % If SUB, SES, and TASK are not provided, extract from the first dtseries file
%     if nargin < 8 || isempty(SUB) || isempty(SES) || isempty(TASK)
%         [SUB1, SES1, TASK1] = extract_sub_ses_task_from_path(dtseries1);
%         if nargin < 8 || isempty(SUB)
%             SUB = SUB1;
%         end
%         if nargin < 8 || isempty(SES)
%             SES = SES1;
%         end
%         if nargin < 8 || isempty(TASK)
%             TASK = TASK1;
%         end
%     end
% 
%     % Now you can use SUB, SES, and TASK in your subsequent code
%     fprintf('Processing data for Subject: %s, Session: %s, Task: %s\n', SUB, SES, TASK);
% 
%     % Load the first dtseries file
%     timeseries1 = cifti_read(dtseries1);
%     data1 = timeseries1.cdata;
% 
%     % Load the second dtseries file
%     timeseries2 = cifti_read(dtseries2);
%     data2 = timeseries2.cdata;
% 
%     % Concatenate the dtseries data along the time dimension (2nd dimension)
%     concatenated_data = [data1, data2];
% 
%     % Create new dtseries object for the concatenated data
%     concatenated_timeseries = timeseries1;
%     concatenated_timeseries.cdata = concatenated_data;
%     concatenated_timeseries.diminfo{1,2}.length = size(concatenated_data, 2);
% 
%     % Save the concatenated dtseries file
%     new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_bold.dtseries.nii', SUB, SES, TASK));
%     cifti_write(concatenated_timeseries, new_infile);
% 
%     % Load the first motion file
%     load(motionfile1, 'motion_data');
%     motion_data1 = motion_data;
% 
%     % Load the second motion file
%     load(motionfile2, 'motion_data');
%     motion_data2 = motion_data;
% 
%     % Concatenate the motion data
%     motion_data = cell(size(motion_data1));
%     for index = 1:size(motion_data1, 2)
%         motion_data{index}.skip = motion_data1{index}.skip;
%         motion_data{index}.epi_TR = motion_data1{index}.epi_TR;
%         motion_data{index}.FD_threshold = motion_data1{index}.FD_threshold;
%         % Concatenate frame_removal vertically
%         motion_data{index}.frame_removal = vertcat(motion_data1{index}.frame_removal, motion_data2{index}.frame_removal);
%         motion_data{index}.total_frame_count = length(motion_data{index}.frame_removal);
%         motion_data{index}.remaining_frame_count = sum(motion_data{index}.frame_removal == 0); % Assuming 0 indicates a good frame
%         motion_data{index}.remaining_seconds = motion_data{index}.remaining_frame_count * str2double(TR); % Using TR passed as an input
%     end
%     % Save the concatenated motion file
%     new_motionfile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK));
%     save(new_motionfile, 'motion_data');
% 
%     fprintf('Concatenation complete. Files saved to %s\n', outfolder);
% end