function smooth_dtseries(input_directory,output_directory,smoothing_kernal)

    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    clear smoothedfile_name
    Column = 'COLUMN';
    cmd = [wb_command ' -cifti-smoothing ' char(input_directory) char(orig_cifti_filename) ' ' num2str(smoothing_kernal) ' ' num2str(smoothing_kernal) ' ' Column ' ' char(output_directory) char(orig_cifti_filename(1:length(char(orig_cifti_filename))-13)) '_SMOOTHED_' num2str(smoothing_kernal) '.' suffix  ' -left-surface ' C{i} '  -right-surface ' D{i}];
    disp('207')
    disp(cmd)
    system(cmd);
    clear cmd

    % A_smoothed{i} = [char(output_directory) char(orig_cifti_filename(1:length(char(orig_cifti_filename))-13)) '_SMOOTHED_' num2str(smoothing_kernal) '.' suffix];
    % temp_name = [A_smoothed{i} '_all_frames_at_FD_' motion_file '.' suffix2];
    % if exist(A_smoothed{i}) == 0 %check to see if smoothing file does not exist
    %     clear smoothedfile_name
    %     Column = 'COLUMN';
    %     cmd = [wb_command ' -cifti-smoothing ' char(input_directory) char(orig_cifti_filename) ' ' num2str(smoothing_kernal) ' ' num2str(smoothing_kernal) ' ' Column ' ' char(output_directory) char(orig_cifti_filename(1:length(char(orig_cifti_filename))-13)) '_SMOOTHED_' num2str(smoothing_kernal) '.' suffix  ' -left-surface ' C{i} '  -right-surface ' D{i}];
    %     disp('207')
    %     disp(cmd)
    %     system(cmd);
    %     clear cmd

end