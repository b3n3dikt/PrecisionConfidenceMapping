function motion_scrub_dtseries(infile, motionfile, outfolder, FD)
    % Add paths to necessary toolboxes
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));    
    
    [SUB, SES, TASK] = extract_sub_ses_task_from_path(infile);

    % Now you can use SUB, SES, and TASK in your subsequent code
    fprintf('Processing data for Subject: %s, Session: %s, Task: %s\n', SUB, SES, TASK);
    

    % Load the input dtseries file
    concatenated_timeseries = cifti_read(infile);
    data = concatenated_timeseries.cdata;

    % Load the motion file
    load(motionfile);
    disp(motionfile)

    % Scrub motion

    % Pick fd traces with fitting FD value
    FD = str2double(FD);
    for i = 1:size(motion_data, 2)
        list_thresholds(i, 1) = motion_data{1, i}.FD_threshold;
    end
    index = find(list_thresholds == FD);

    fd_vector = motion_data{1, index}.frame_removal;
    retained_frames = abs(fd_vector - 1);

    % Filter data to only include 'retained_frames == 1'
    good_frames = find(retained_frames == 1);
    new_data = data(:, good_frames);

    % Create new dtseries object
    new_timeseries = concatenated_timeseries;
    new_timeseries.cdata = new_data;
    new_timeseries.diminfo{1,2}.length = size(new_data, 2);

    % Save the new dtseries file
    new_infile = fullfile(outfolder, sprintf('sub-%s_ses-%s_task-%s_scrubbed-FD-%s.dtseries.nii', SUB, SES, TASK,num2str(FD)));
    cifti_write(new_timeseries, new_infile);


end