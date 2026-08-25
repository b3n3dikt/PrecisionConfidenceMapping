function concatenate_multiple_dtseries_and_motion(dtseriesconc, motionconc, outfolder, TR, SUB, SES, TASK)

% Add paths to necessary toolboxes
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    % Read .conc files and extract dtseries and motion files
    dtseries_files = readlines(dtseriesconc);
    motion_files = readlines(motionconc);

    if length(dtseries_files) ~= length(motion_files)
        error('Mismatch between the number of dtseries and motion files in the .conc files.');
    end

    % Load and concatenate all dtseries files
    concatenated_data = [];
    for i = 1:length(dtseries_files)
        timeseries = cifti_read(dtseries_files{i});
        data = timeseries.cdata;
        concatenated_data = [concatenated_data, data];
    end

    % Create new dtseries object for the concatenated data
    concatenated_timeseries = cifti_read(dtseries_files{1});
    concatenated_timeseries.cdata = concatenated_data;
    concatenated_timeseries.diminfo{1,2}.length = size(concatenated_data, 2);

    % Save the concatenated dtseries file
    new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_bold.dtseries.nii', SUB, SES, TASK));
    cifti_write(concatenated_timeseries, new_infile);

    % Load and concatenate all motion files
    concatenated_motion_data = cell(size(load(motion_files{1}, 'motion_data')));
    for index = 1:size(concatenated_motion_data, 2)
        concatenated_motion_data{index}.frame_removal = [];
        concatenated_motion_data{index}.skip = [];
        concatenated_motion_data{index}.epi_TR = [];
        concatenated_motion_data{index}.FD_threshold = [];
    end

    for i = 1:length(motion_files)
        load(motion_files{i}, 'motion_data');
        for index = 1:size(concatenated_motion_data, 2)
            if isfield(motion_data{index}, 'skip')
                concatenated_motion_data{index}.skip = [concatenated_motion_data{index}.skip; motion_data{index}.skip];
            end
            if isfield(motion_data{index}, 'epi_TR')
                concatenated_motion_data{index}.epi_TR = [concatenated_motion_data{index}.epi_TR; motion_data{index}.epi_TR];
            end
            if isfield(motion_data{index}, 'FD_threshold')
                concatenated_motion_data{index}.FD_threshold = [concatenated_motion_data{index}.FD_threshold; motion_data{index}.FD_threshold];
            end
            if isfield(motion_data{index}, 'frame_removal')
                concatenated_motion_data{index}.frame_removal = [concatenated_motion_data{index}.frame_removal; motion_data{index}.frame_removal];
            end
        end
    end

    % Update the remaining fields
    for index = 1:size(concatenated_motion_data, 2)
        concatenated_motion_data{index}.total_frame_count = length(concatenated_motion_data{index}.frame_removal);
        concatenated_motion_data{index}.remaining_frame_count = sum(concatenated_motion_data{index}.frame_removal == 0); % Assuming 0 indicates a good frame
        concatenated_motion_data{index}.remaining_seconds = concatenated_motion_data{index}.remaining_frame_count * str2double(TR); % Using TR passed as an input
    end

    % Save the concatenated motion file
    new_motionfile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK));
    save(new_motionfile, 'motion_data', '-v7.3');

    fprintf('Concatenation complete. Files saved to %s\n', outfolder);
end

% 
% 
% 
% function concatenate_multiple_dtseries_and_motion(dtseriesconc, motionconc, outfolder, TR, SUB, SES, TASK)

% % Add paths to necessary toolboxes
%     addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
% 
%     % Read .conc files and extract dtseries and motion files
%     dtseries_files = readlines(dtseriesconc);
%     motion_files = readlines(motionconc);
% 
%     if length(dtseries_files) ~= length(motion_files)
%         error('Mismatch between the number of dtseries and motion files in the .conc files.');
%     end
% 
%     % Initialize the first files for concatenation
%     concatenated_dtseries = dtseries_files{1};
%     concatenated_motion = motion_files{1};
% 
%     % Concatenate each subsequent dtseries and motion file
%     for i = 2:length(dtseries_files)
%         intermediate_outfolder = fullfile(outfolder, sprintf('intermediate_%d', i));
%         mkdir(intermediate_outfolder);
% 
%         concatenate_dtseries_and_motion(concatenated_dtseries, concatenated_motion, dtseries_files{i}, motion_files{i}, intermediate_outfolder, TR, SUB, SES, TASK);
% 
%         concatenated_dtseries = fullfile(intermediate_outfolder, sprintf('sub-%s_ses-%s_task-%s_bold.dtseries.nii', SUB, SES, TASK));
%         concatenated_motion = fullfile(intermediate_outfolder, sprintf('sub-%s_ses-%s_task-%s_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK));
%     end
% 
%     % Final output
%     final_outfile_dtseries = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_bold.dtseries.nii', SUB, SES, TASK));
%     final_outfile_motion = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_desc-dcan_qc_power_2014_FD_only.mat', SUB, SES, TASK));
% 
%     movefile(concatenated_dtseries, final_outfile_dtseries);
%     movefile(concatenated_motion, final_outfile_motion);
% 
%     fprintf('Concatenation complete. Files saved to %s\n', outfolder);
% end