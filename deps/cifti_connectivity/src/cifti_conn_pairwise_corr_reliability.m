function scalar_paths = cifti_conn_pairwise_corr_reliability(wb_command, num_reps, dtseries1, motion1,Lmidthickness1,Rmidthickness1,dtseries2,motion2,Lmidthickness2,Rmidthickness2, keep_conn_matrices,working_directory,output_directory,inherit_name,output_name,minutes_file,network_dscalar)

% This function generates a 2 correlation matrices from 2 supplied
% dtseries, correlates them to output a dtseries.  It loops through the
% text file which contain a vector of minutes.

%pconn_dconn_template = template correlation matrix to compare data to
%pconn_or_dconn = specify if your data are parcellated or dense
%subject_conn_conc = conc file that has full paths to your cifti connectivity matrices
%keep_conn_matrices = set to 1 to keep the correlation matrices.  Set to 0 to remove correlation matrices.
%output_directory = path to some output directory
%inherit_name = if set to 1, then the code will try to write out a dscalar using a combination of the template and subject dconn names.  HOwever if the file name gets too long, then the code will fail.  Instead, provide an output name.
%output_name = provide an output name.  If you you set inheret_name = 1,
%then this variable will not be used.

%pconn_dconn_template='/mnt/max/shared/code/internal/utilities/hcp_comm_det_damien/Merged_HCP_best80_dtseries.conc_AVG.dconn.nii';
%pconn_or_dconn='dconn';
%subject_conn_conc='/mnt/max/shared/code/internal/utilities/hcp_comm_det_damien/cub-sub-NDARINVLWRKNUN1_FNL_preproc_v2_Atlas.dtseries.nii_dconn_of_dtseries_SMOOTHED_1.7_3_minutes_of_data_at_FD_0.35.conc';

%% make sure template exists (i.e. paths to template)

if exist(dtseries1,'file')==0
    disp(dtseries1);
    disp('Template d or pconn file does not exist');
    
else
    [~,filename,extension] = fileparts(dtseries1);
    pconn_dconn_template_basename = [filename extension];
end

addpath('/projects/standard/faird/shared/projects/AnitaOHSUVAcollab/code');
addpath('/projects/standard/faird/shared/code/internal/utilities/cifti_connectivity/src');
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/'));
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/')); %Add top level folder to get paircorr_mod.m
%% make sure files connectivity matrices in conc exist
%conc = strsplit(subject_conn_conc, '/');
conc = strsplit(dtseries2, '.');
conc = char(conc(end));

% Lmidthickness1 = {Lmidthickness1};
% Rmidthickness1 = {Rmidthickness1};
% Lmidthickness2 = {Lmidthickness2};
% Rmidthickness2 = {Rmidthickness2};

if isnumeric(inherit_name) ==0
    inherit_name = str2num(inherit_name);
end

if isnumeric(keep_conn_matrices) ==0
    keep_conn_matrices=str2num(keep_conn_matrices);
end

if isnumeric(num_reps) ==0
    num_reps=str2num(num_reps);
end
%% Generate workbench command to do the pairwise correlation for all matrices in conc file
% fileparts(dtseries2)
% myname = strsplit(dtseries2,'.');
% cifti_type = char(myname(end-1));


[~,name,~] = fileparts(dtseries2);
if contains(name,'ptseries')
    suffix = 'pscalar.nii';
elseif contains(name,'dtseries')
    suffix = 'dscalar.nii';
else
    error('Input must be ptseries or dtseries');
end

% if strcmp(cifti_type,'ptseries') ==1
%     suffix = 'pscalar.nii';
%     disp(cifti_type);
% elseif strcmp(cifti_type,'dtseries') ==1
%     suffix = 'dscalar.nii';
%     disp(cifti_type);
% else
%     'matrices needs to be "ptseries" or "dtseries"';
%     return
% end

scalar_paths = {};
minutes=importdata(minutes_file);
for i = 1:length(minutes) % note that i is the index here, not the number of minutes, so when using i, make sure to use minutes(i).
    %for i = 1:minutes % Don't make this mistake ...again...again -RH
    for j = 1:num_reps
        
        
        if inherit_name ==1
            [~,A_name,~] = fileparts(dtseries1);
            dconn1_vs_dconn2_output_name = [output_directory filesep A_name '_to_' num2str(minutes(i)) 'min_' num2str(j)  'rep.' suffix]; % set scalar name
        else
            dconn1_vs_dconn2_output_name = [output_directory filesep output_name '_to_' num2str(minutes(i)) 'min_' num2str(j)  'rep.' suffix];
        end
        if exist(dconn1_vs_dconn2_output_name, 'file') ~= 0
            disp([' Final scalar exists: ' dconn1_vs_dconn2_output_name]);
            disp('Skipping iteration...');
            scalar_paths = [scalar_paths; {dconn1_vs_dconn2_output_name}];
        else
            disp('Final dscalar does not exist. Continuing...');
            
            % 1a. Construct the display string
            %cmd_display = sprintf(['cifti_conn_matrix_for_wrapper_continous(%s, ''%s'', ''dtseries'', ''%s'', %.2f, %.2f, ''none'', %.2f, ''%s'', ''%s'', %d, %d, ''none'', %d, ''%s'', ''%s'', %d, %d)'], ...
            %wb_command, {dtseries1}, {motion1}, 0.2, 0.8, minutes(i), 2.55, {Lmidthickness1}, {Rmidthickness1}, 0, 1, 'none', 0, working_directory, {dtseries1}, 1, 64);
            
            % 1b. Print it to the Command Window
            %fprintf('RUNNING COMMAND:\n%s\n', cmd_display);
            [dconn1_path, motion_mask_path1] = cifti_conn_matrix_for_wrapper_continous(wb_command,dtseries1,'dtseries',motion1,0.2,0.8,minutes(i),2.55,Lmidthickness1,Rmidthickness1,0,1,'none',0,[working_directory filesep],dtseries1,1,64);
            [~, motion_mask_root] = fileparts(motion_mask_path1);
            cmd5 = ['cp ' motion_mask_path1 ' ' output_directory filesep motion_mask_root '.txt'];
            disp(cmd5); system(cmd5);
            
            scores_output_name1 = [output_directory filesep output_name '1_to_' num2str(minutes(i)) 'min_' num2str(j)  'rep.mat' ];
            sort_dconn_and_get_net_mean(dconn1_path,network_dscalar,scores_output_name1);
            
            
            [dconn2_path, motion_mask_path2] = cifti_conn_matrix_for_wrapper_continous(wb_command,dtseries2,'dtseries',motion2,0.2,0.8,minutes(i),2.55,Lmidthickness2,Rmidthickness2,0,1,'none',0,[working_directory filesep],dtseries2,1,64);
            [~, motion_mask_root] = fileparts(motion_mask_path2);
            cmd6 = ['cp ' motion_mask_path2 ' ' output_directory filesep motion_mask_root '.txt'];
            disp(cmd6); system(cmd6);
            
            scores_output_name2 = [output_directory filesep output_name '2_to_' num2str(minutes(i)) 'min_' num2str(j)  'rep.mat' ];
            sort_dconn_and_get_net_mean(dconn2_path,network_dscalar,scores_output_name2);
            
            
            
            if exist(dconn1_vs_dconn2_output_name,'file') == 0 % make sure the matrix doesn't already exist
                %[~,template_name,~] = fileparts(pconn_dconn_template);
                
                cmd = [wb_command ' -cifti-pairwise-correlation ' dconn1_path ' ' dconn2_path ' ' dconn1_vs_dconn2_output_name ];
                disp(cmd)
                tic;
                system(cmd);
                toc;
                clear cmd
            else
                disp([dconn1_vs_dconn2_output_name 'already exists']);
            end
            
            %add option to delete matrices after making scalars
            
            if keep_conn_matrices ==0
                cmd2 = ['rm -f ' dconn1_path];
                disp(strcat('removing matrix: ',(dconn1_path)))
                system(cmd2);
                clear cmd
                cmd3 = ['rm -f ' dconn2_path];
                disp(strcat('removing matrix: ',(dconn2_path)))
                system(cmd3);
                clear cmd
            else
                disp(strcat('keeping matrix: ',(dconn1_path)))
                disp(strcat('keeping matrix: ',(dconn2_path)))
            end
            
            %scalar_paths = [scalar_paths; strcat({pwd}, '/', {subject_conn_conc}, '_', {num2str(i)}, '_to_', {pconn_dconn_template}, '.', {suffix})]; %for scalar conc file
            scalar_paths = [scalar_paths; {dconn1_vs_dconn2_output_name}];
        end % reps
    end
end % minutes
% total_scalars = length(minutes) * num_reps;
% Summary_of_pairwise = [num2str(total_scalars) ' total scalars made.'];
% disp(Summary_of_pairwise);
completed = numel(scalar_paths);
disp([num2str(completed) ' scalars present or created.'])


disp('Done')
