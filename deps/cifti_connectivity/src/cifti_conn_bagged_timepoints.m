function [motion_vectors, bagged_indices] = cifti_conn_bagged_timepoints(timeseries_file, motion_file, FD_file, minTP,TR, bagged_desired_minutes, output_directory)

%timeseries_file='/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-rest_SpaInt_Gordon.ptseries.nii';
%timeseries_file='/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii';
%FD_file='/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_desc-filtered_motion.tsv';
%motion_file='/home/znahas/shared/projects/PCS/derivatives/02052024/xcp_d/sub-PCS0001/ses-01/func/sub-PCS0001_ses-01_task-restMENORDICrmnoisevols_desc-dcan_qc_power_2014_FD_only.mat';
%output_directory='/panfs/jay/groups/14/znahas/shared/projects/PCS/dconns/sub-PCS0001/bagged_ses-01_with_bad_runs_excluded_smoothed2.55_fMRIprep_T2bold_norun02/bags/';
%minTP=25; %number of low motion_minutes to sample from
%bagged_desired_minutes=60; %the total number of minutes that correspond with the number of times to sample.
%TR=1.761;
FD_threshold=0.2;
smoothing_kernel='none';
bit8=0;remove_outliers=1;
%additional_mask_conc='/home/znahas/shared/projects/PCS/code/total_3619f_remove_1473_to_2525_and_run02.txt';
additional_mask_conc='none';
use_continous_minutes=0;
num_bootstramp_samples=500;

addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'));
%% Adding paths for this function
this_code = which('template_matching_RH');
[code_dir,~] = fileparts(this_code);
support_folder=[code_dir '/support_files']; %find support files in the code directory.
addpath(genpath(support_folder));
settings=settings_comparematrices;%
np=size(settings.path,2);

amIdeployed = isdeployed();
amIdeployed=num2str(double(amIdeployed));
disp(['is deployed equals: ' amIdeployed]);

if isdeployed
    disp('Matlab is deployed. Not adding paths, as they should have been added during compiling.')
else
    disp('Attempting to add neccesaary paths and functions.')
    warning('off') %supress addpath warnings to nonfolders.
    for i=1:np
        addpath(genpath(settings.path{i}));
    end
    %rmpath('/mnt/max/shared/code/external/utilities/MSCcodebase/Utilities/read_write_cifti') % remove non-working gifti path included with MSCcodebase
    %rmpath('/home/exacloud/lustre1/fnl_lab/code/external/utilities/MSCcodebase/Utilities/read_write_cifti'); % remove non-working gifti path included with MSCcodebase
    addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/plotting-tools'));
    addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/Zscore_dconn'));
    warning('on')
end

if exist('wb_command','var') ==1
    %do nothing
else
    wb_command=settings.path_wb_c; %path to wb_command
end

minTP_num_frames = round(minTP*60/TR);
desired_num_frames = round(bagged_desired_minutes*60/TR); %round down


[~,timseriesfilename,~]=fileparts(timeseries_file);
[~,~,seriestemp]=fileparts(timseriesfilename);series=seriestemp(2:end);

%% Start
%load FD column
if strcmp(FD_file(end-3:end),'.mat') ==1
    load(FD_file);
    FD=motion_numbers.FD;
else
    motion_numbers=readtable(FD_file, "FileType","text",'Delimiter', '\t');
    motion_numbers_headers = motion_numbers.Properties.VariableNames;
    FD_column_Index = find(contains(motion_numbers_headers,'framewise_displacement'));
    FD=table2array(motion_numbers(:,FD_column_Index));
end


%load motion censor data
% load(motion_file);
% mask = motion_data{1,21}.frame_removal;
%
% mask_keep=find(mask==0);
% cii = ciftiopen(timeseries_file,wb_command);
% timeseries=cii.cdata;

% scrubbed_timeseries=timeseries(:,mask_keep);

% end
%
%
% function [motion_vectors, bagged_indices] = bagged_time_calculation(wb_command, ...
%     dt_or_ptseries_conc_file, series, motion_file, FD_threshold, TR, ...
%     bagged_desired_minutes, smoothing_kernel, bit8, remove_outliers, additional_mask_conc,  ...
%     make_bagged_motion_vectors, output_directory, dtseries_conc,use_continous_minutes)
% This script is a modularized version of cifti_conn_matrix_exaversion,
% except that it also accepts and uses these parameters: remove_outliers,
% additional_mask, and make_dconn_conc.

%% Parameter definitions
% dt_or_ptseries_conc_file = dense timeseries or parcellated timeseries conc file (i.e. text file with paths to each file being examined
% series = 'dtseries' or 'ptseries'; specify if files are dense or parcellated
% motion_file = conc file that points to FNL motion mat files for each dt or ptseries (note: if no motion file to be used, type 'none')
% FD threshold = specify motion threshold (e.g. 0.2)
% TR = Repetition time of your data
% bagged_desired_minutes = specify the number of minutes to be used to generate the correlation matrix
% smoothing_kernal = specify smoothing kernal (note: if no smoothing file to be used, type 'none')
% left_surface_file = path to left surface files or conc of surface files.
% right_surface_file = path to right surface files or conc of surface files.
% bit8 = set to 1 if you want to make the outputs smaller in 8bit.
% remove_outliers = set to 0 to use all frames below FD threshold.  Set to 1 to censor additional frames that are outliers in in terms of standard deivtaion of the bold signal.
% additional_mask = provide an additional file of 1s (keep) and 0s (remove)
% that is the same length as the dtseries, only use selected frames. %
% (e.g.you want to make a connectivity matrix of only the second half of
% the dtseries.)  This can also be a conc file of additional masks.
% make_dconn_conc = output a list of dconns that have been made.
% dtseries_conc = used with outlier detection.  Ensures that stdev is only calculated on dtseries even if ptseries is provided.
% use_continous_minutes = allows user to sample continuous (motion-censored) minutes rather randomly sampled minutes throughout the collection.
% limit memory value = when running correlation, set limit of memory to use (in GB).

%% Input validation
orig_conc_folders = split(timeseries_file, filesep);
orig_conc_file = char(orig_conc_folders(end));
no_output = 0;
if ~exist('output_directory', 'var')
    output_directory = [];
    no_output = 1;
    disp('All series files exist. Continuing ...')
else
    output_directory = char(output_directory);
    
    disp(['mkdir -p ' output_directory])
    system(['mkdir -p ' output_directory])
    
end
if isempty(output_directory)
    no_output = 1;
end

% convert number variables to cnumbers (only within compiled code)
% Check to ensure that input variables which should be numbers are numbers
bit8 = make_numeric(bit8, 'Beta 8');
FD_threshold = make_numeric(FD_threshold, 'FD threshold');
TR = make_numeric(TR, 'TR');
bagged_desired_minutes = make_numeric(bagged_desired_minutes, 'Minutes limit');
remove_outliers = make_numeric(remove_outliers, 'Outlier removal');
smoothing_kernel = make_numeric(smoothing_kernel, 'Smoothing kernel');
use_continous_minutes =make_numeric(use_continous_minutes, 'use continous minutes');

reset(RandStream.getGlobalStream,sum(100*clock)); % added to ensure randomness of frame sampling during parellization -RH 05/30/2023

if (~strcmpi(smoothing_kernel, 'none')) && (strcmpi(series, 'ptseries'))
    disp('Check your settings. Smoothing not allowed on ptseries.');
    return
end

%% Load concatenated paths (i.e. paths to ciftis)
[A, conc] = get_paths_from_conc(timeseries_file);
if ~strcmpi(timeseries_file, 'none')
    [dtseries_E, ~] = get_paths_from_conc(timeseries_file);
    if length(A) ~= length(dtseries_E)
        error(['Length of pt_or_dtseries.conc file (' num2str(length(A)) ') does not match length of ' ...
            'timeseries .conc file that is used for outlier detection(' num2str(length(dtseries_E)) '). Double check your conc files.'])
    end
else
    dtseries_E = 'none';
end



%% Set file extensions
if strcmpi(series, 'ptseries')
    suffix = 'ptseries.nii';
    suffix2 = 'pconn.nii';
    
    % set default precision
    % Connectivity file sizes are NOT reduced for ptseries
    output_precision = ' ';
    %you probably won't run into memory issues with pconns.
    memory_limit_option = ' ';
    memory_limit_value  = ' ';
    
elseif strcmpi(series, 'dtseries')
    suffix = 'dtseries.nii';
    suffix2 = 'dconn.nii';
    if exist('bit8', 'var')
        bit8 = make_numeric(bit8, 'Beta 8');
        
        %set default precision.
        if bit8 == 1  % Connectivity file sizes are reduced for dtseries
            output_precision = [' -cifti-output-datatype INT8 ' ...
                '-cifti-output-range -1.0 1.0'];
        else
            output_precision = ' ';
        end
    else
        output_precision = ' ';
    end
    %restrict memory usage.
    if exist('memory_limit_value', 'var') && strcmp('memory_limit_value','none') ~=1
        memory_limit_option = ' -mem-limit ';
        memory_limit_value = make_numeric(memory_limit_value, 'Memory limit value');
    else
        memory_limit_option = ' ';
        memory_limit_value  = ' ';
    end
else
    'series needs to be "ptseries" or "dtseries"';
    return
end

disp(smoothing_kernel)
disp('setting smoothing kernal to none at this stage.')
smoothing_kernel='none';

%% prealocate memory if you want to do smoothing
if ~strcmpi(smoothing_kernel, 'none')
    A_smoothed = num2cell(zeros(size(A)));
    C = get_surface_files('left', left_surface_file, conc);
    D = get_surface_files('right', right_surface_file, conc);
end

%% Generate Motion Vectors and correlation matrix
if strcmpi(motion_file, 'none') % run this if no motion censoring
    disp('No motion files, will use all frames to generate matrices')
    for i = 1:length(A)
        [orig_cifti_filename, input_directory, ...
            ~] = get_folder_params(A{i}, filesep);
        if no_output
            output_directory = char(input_directory);
        end
        
        % Run minutes limit calculation
        if strcmpi(smoothing_kernel, 'none')
            left = 'none';
            right = 'none';
        else
            left = C{i};
            right = D{i};
        end
        min_file_end = '_cifti_censor_FD_vector_All_Good_Frames.txt';
        %         [A_smoothed{i}, dconn_outfile_path] = execute_workbench(...
        %             FD_threshold, input_directory, left, '_all_frames_at_', ...
        %             min_file_end, motion_file, orig_cifti_filename, 'none', ...
        %             output_directory, output_precision, right, ...
        %             smoothing_kernel, suffix, suffix2, wb_command,...
        %             memory_limit_option, memory_limit_value);
    end
else % use motion censoring
    % rename temp file so it isn't overwritten when running in parallel
    v=num2str(randi([1 10000000]));
    %stdev_temp_filename=[output_directory orig_conc_file char(v) '_temp.txt'];
    stdev_temp_filename=[output_directory char(v) '_temp.txt']; %filename was getting too long
    if strcmp('conc', conc)
        B = importdata(motion_file);
    else
        B = {motion_file};
    end
    
    %Make sure length of motion files matches length of timeseries
    if length(A) ~= length(B)
        disp(['Length of motion .conc file does not match length of ' ...
            'series .conc file.'])
    end
    
    % Check that all motion files in conc file exist
    for i = 1:length(B)
        if ~exist(B{i}, 'file')
            disp(['Motion file ' num2str(i) ' does not exist'])
            return
        end
    end
    disp('All motion files exist. Continuing ...')
    
    %% Generate motion vector for subject and generate correlation matrix
    for i = 1:length(B)
        motion_exten = strsplit(B{i}, '.');
        motion_exten = char(motion_exten(end));
        
        % Get input folder parameters
        [orig_cifti_filename, input_directory, ...
            ~] = get_folder_params(A{i}, filesep);
        if no_output
            output_directory = char(input_directory);
        end
        other_motion_mask = ~strcmp('mat', motion_exten);
        if strcmpi(dtseries_E, 'none')
            outlier_rmv_file = 'none';
        else
            outlier_rmv_file = dtseries_E{i};
        end
        
        % use an external mask (.txt) instead of calculating the mask here
        [orig_motion_filename, inputB_directory, ...
            ~] = get_folder_params(B{i}, filesep);
        if other_motion_mask
            try
                FDvec = importdata(B{i});
                FDvec = remove_outliers_if(remove_outliers, FDvec, ...
                    outlier_rmv_file, stdev_temp_filename, wb_command, 15);
            catch
                error('Motion mask need to be a readable vector (e.g. .txt file).')
            end
        else  % Use power 2014 motion
            FDvec = get_FDvec(B{i}, FD_threshold);
            if no_output
                output_directory = char(inputB_directory);
            end
            FDvec = add_mask_to_FDvec(FDvec, additional_mask_conc,conc,i);
            FDvec = remove_outliers_if(remove_outliers, FDvec, ...
                outlier_rmv_file, stdev_temp_filename, wb_command, 15);
        end  % [input_directory orig_cifti_filename] was instead of rmv
        
        % Assign variables for minutes limit calculation
        if strcmpi(bagged_desired_minutes, 'none')
            min_cmd_part = '_all_frames_at_';
            min_file_end = '_cifti_censor_FD_vector_All_Good_Frames.txt';
            motion_mask_path = save_out_file(output_directory, orig_motion_filename, ...
                FD_threshold, min_file_end, FDvec);
        else
            % Get the number of good minutes in your data
            good_frames_idx = find(FDvec == 1);
            good_minutes = (length(good_frames_idx)*TR)/60;
            
            % If there is less than 30 seconds of good data, then do not
            % generate the correlation matrix
            if good_minutes < 0.5
                disp(['Subject ' num2str(i) ' has less than 30 ' ...
                    'seconds of good data.'])
                min_cmd_part = 'NA';
                min_file_end = 'lessthan30secs.txt';
                motion_mask_path ='NA';
                % if there is not enough data for your subject, just generate
                % the matrix with all available frames
            elseif minTP > good_minutes
                %                 min_cmd_part = '_all_frames_at_';
                %                 min_file_end = ['_cifti_censor_FD_vector_All_Good_' ...
                %                                 'Frames.txt'];
                %                 motion_mask_path = save_out_file(output_directory, orig_motion_filename, ...
                %                               FD_threshold, min_file_end, FDvec);
                min_cmd_part = 'NA';
                motion_mask_path ='NA';
                disp(['Subject ' num2str(i) ' has fewer minutes (' num2str(good_minutes) ') than the minTP: ' num2str(minTP) ])
                
                % if there is enough data, match the amount of data used for
                % your subject matrix to the bagged_desired_minutes
            elseif minTP <= good_minutes
                if use_continous_minutes ==1
                    error('Bagging using continous minutes has not yet been implemented.');
%                     total_num_good_frames = length(good_frames_idx);
%                     minute_limit_frames = round(bagged_desired_minutes*60/TR);
%                     %pick a random good index, that is between the first good
%                     %index and the last goodindex (provided the interval is at least as long as
%                     %the minutes limit).
%                     good_frames_start_idx = randi([1 (total_num_good_frames- minute_limit_frames)]);
%                     FDvec_cut = zeros(length(FDvec), 1);
%                     ones_idx = good_frames_idx(good_frames_start_idx:good_frames_start_idx+minute_limit_frames);
%                     FDvec_cut(ones_idx) = 1;
                else
                    
                    % Number of good frames to randomly pull
                    %                 rand_good_frames = sort(randperm(length( ...
                    %                     good_frames_idx), round(bagged_desired_minutes*60/TR)));
                    
                    %[sorted_FD,sorted_FD_idx]=sort(FD,'ascend'); %old way
                    %NOTE: A fix has been implemented here to ensure that the frames that
                    %are being excluded are not inlcluded in the sorting
                    %process.
                    
                    %new way
                    FD_adj=FD;
                    FD_adj(~logical(FDvec))=55; %set the FD of the exclude frames to something high like 55555, so that they aren't used.
                    [sorted_FD,sorted_FD_idx]=sort(FD_adj,'ascend'); 
                    

                    FDvec_cut = zeros(length(FDvec), 1); %preallocation for speed.
                    all_FDvec_cut_scaled = zeros(length(FDvec), num_bootstramp_samples); 
                    %                 ones_idx = good_frames_idx(rand_good_frames);
                    sorted_FD_idx_size_minTP = sorted_FD_idx(1:minTP_num_frames);
                    
                    mytest = find(FD_adj(sorted_FD_idx_size_minTP) > 10);
                    %check the data
                    if isempty(mytest)~=1
                        error('Your FD vector after sorting somehow contains a frame that should have been removed.')
                    end
                    
                    all_bootstramp_samples_sizeTP=zeros(desired_num_frames,num_bootstramp_samples);
                    all_FD_cuts=zeros(length(FDvec),num_bootstramp_samples);
                    all_bootstramp_samples_sizeTP_scaled=zeros(desired_num_frames,num_bootstramp_samples);
                    
                    for b=1:num_bootstramp_samples
                        disp(num2str(b))
                        % randomly sample withreplacement the frames with the
                        % lowest n, (desired_num_frames) times.
                        [bootstramp_samples_sizeTP,~]=datasample(sorted_FD_idx_size_minTP,desired_num_frames);
                        
                        FDvec_cut(bootstramp_samples_sizeTP) = 1;
                        all_bootstramp_samples_sizeTP(:,b)=bootstramp_samples_sizeTP;
                        all_FD_cuts(:,b) = FDvec_cut; % this vector isn't very helpful since frames are sampled multiple times -R.H.
                        unique_frames = unique(all_bootstramp_samples_sizeTP(:,b));
                        frame_counts = histc(all_bootstramp_samples_sizeTP(:,b), unique_frames);
                        
                        for u=1:size(unique_frames)
                            all_FDvec_cut_scaled(unique_frames(u),b)=frame_counts(u);
                            bootidx=find(bootstramp_samples_sizeTP==unique_frames(u));
                            all_bootstramp_samples_sizeTP_scaled(bootidx,b)=frame_counts(u);
                        end
                        
%                         bfig=bar3(all_FDvec_cut_scaled);
%                         for k = 1:length(bfig)
%                             zdata = bfig(k).ZData;
%                             bfig(k).CData = zdata;
%                             bfig(k).FaceColor = 'interp';
%                         end
                         
                        % The new vector that should match good frames with the minutes limit
                        %FDvec_cut(ones_idx) = 1;
                        
                        min_cmd_part = ['_' num2str(bagged_desired_minutes) ...
                            'bagmin_scaledweights'];
                        min_file_end = ['FD_from_minTP_' num2str(minTP,'%03.f') 'min' min_cmd_part ...
                            'bag' num2str(b,'%03.f') '.txt'];
                        motion_mask_path = save_out_file(output_directory, orig_motion_filename, ...
                            FD_threshold, min_file_end, all_FDvec_cut_scaled(:,b));
                    end
                end
                disp(['Done generating ' num2str(num_bootstramp_samples) ' bootstrap samplings of length: ' num2str(desired_num_frames), ' frames (' num2str(bagged_desired_minutes) ' minutes) from the ' num2str(minTP) ' minutes of lowest motion.']);
                
            else
                disp(['Something is wrong about the number of good ' ...
                    'minutes calculation.'])
            end
        end
       
        % Run minutes limit calculation
        if strcmpi(bagged_desired_minutes, 'none') || good_minutes >= 0.5
            if strcmpi(smoothing_kernel, 'none')
                left = 'none';
                right = 'none';
            else
                left = C{i};
                right = D{i};
            end
            %             [A_smoothed{i}, dconn_outfile_path] = execute_workbench(...
            %                 FD_threshold, input_directory, left, min_cmd_part, ...
            %                 min_file_end, motion_file, orig_cifti_filename, ...
            %                 orig_motion_filename, output_directory, ...
            %                 output_precision, right, smoothing_kernel, suffix, ...
            %                 suffix2, wb_command,memory_limit_option, memory_limit_value);
            if strcmpi(smoothing_kernel, 'none')
                clear A_smoothed
            end
        else
            disp('Outfile name is NA, becauase subject has less than 30 seconds of data.')
            dconn_outfile_path = 'NA'
        end
    end
end

%% Generate final conc file for other code (e.g. cifti_conn_pairwise_corr)
% Greg Conan initially modularized everything from here down on 2019-11-11
% if make_bagged_motion_vectors ==1
%     disp(['Done making calculating bagged vectors files for subjects. Making ' ...
%         'output .conc files now.'])
%     
%     %% Save all paths into different conc files
%     if strcmpi(smoothing_kernel, 'none')
%         smoothing = 'none';
%     else  % use smoothed data
%         smoothing = A_smoothed;
%     end
%     if strcmpi(motion_file, 'none')
%         motion_file_obj = 'none';
%         stdev = 'none';
%     else
%         motion_file_obj = B;
%         stdev = stdev_temp_filename;
%     end
%     
%     % Sort paths into separate lists based on how their total amount of
%     % good minutes compares to the bagged_desired_minutes threshold
%     [dconn_paths_all_frames, dconn_paths_all_frames_at_thresh, ...
%         dconn_paths_all_frames_at_thresh_min_lim, ...
%         subjectswithoutenoughdata] = sort_paths(A, motion_file_obj, ...
%         dtseries_E, FD_threshold, bagged_desired_minutes, motion_file, ...
%         no_output, output_directory, remove_outliers, smoothing, ...
%         stdev, suffix2, TR, wb_command, additional_mask_conc,conc);
%     
%     % Save all of those path lists into .conc files
%     finish_and_save_concs(A, FD_threshold, bagged_desired_minutes, ...
%         motion_file, no_output, output_directory, ...
%         timeseries_file, series(1), smoothing_kernel, ...
%         dconn_paths_all_frames, dconn_paths_all_frames_at_thresh, ...
%         dconn_paths_all_frames_at_thresh_min_lim, ...
%         subjectswithoutenoughdata)
% end
% disp('Done making output concs.')
end


%% Other functions used by the main function


function num_var = make_numeric(num_var, var_name)
% Convert num_var to a number if it is not already a number or 'none'
if ~strcmpi(num_var, 'none') && ~isnumeric(num_var)
    disp([var_name ' passed in as a string. Converting to numeric.'])
    num_var = str2num(num_var);
end
end


function [paths, conc] = get_paths_from_conc(conc_file)
% Check to see if there 1 subject or a list of subjects in conc file.
conc = strsplit(conc_file, '.');
conc = char(conc(end));
if strcmp('conc', conc)
    paths = importdata(conc_file);
else
    paths = {conc_file};
end

% Validate that all paths in .conc file point to real files
for i = 1:length(paths)
    if ~exist(paths{i}, 'file')
        disp(['Subject series ' num2str(i) ' does not exist.'])
        return
    end
end
disp('All series files exist. Continuing ...')
end


function surface_files = get_surface_files(LR, surface_conc, conc)
% Get all paths to surface files
if strcmpi('conc', conc)
    surface_files = importdata(surface_conc);
else
    surface_files = {surface_conc};
end

% Check to make sure surface files exist
for i = 1:length(surface_files)
    if ~exist(surface_files{i}, 'file')
        disp(['Subject ' LR ' surface ' num2str(i) ' does not exist'])
        return
    end
end
disp(['All ' LR ' surface files for smoothing exist. Continuing ...'])
end


function [cifti, in_dir, folders] = get_folder_params(A_i, sep)
% Return the path to the original cifti file, the path to the input
% directory, and an object holding all parts of A_i's file path
folders = split(A_i, sep);
cifti = char(folders(end));
folder_input = join(folders(1:end-1), sep);
in_dir = [char(folder_input) sep];
end


function execute_display_and_clear(cmd, msg)
% Given a string that can be executed on the command line, execute it
% and then clear the variable holding that string. Also display msg.
tic;
disp(msg);
disp(cmd);
system(cmd);
toc;
clear cmd
end


function [A_smoothed_i, outfile] = execute_workbench(...
    FD_threshold, input_dir, left, min_cmd_part, min_file_end, ...
    motion_file, orig_cifti_file, orig_motion_file, output_dir, ...
    precision, right, smoothing, suffix, suffix2, wb_command, ...
    memory_limit_option, memory_limit_value)
% Calculate the number of good minutes and get the output file name
if strcmpi(motion_file, 'none')
    min_cmd_motion = [min_cmd_part 'FD_' motion_file];
    min_file_end = '.txt';
    weights = '';
else
    min_cmd_motion = [min_cmd_part 'FD_' num2str(FD_threshold)];
end
if strcmpi(smoothing, 'none')
    outfile = [char(output_dir) char(orig_cifti_file) ...
        min_cmd_motion '.' suffix2];
    A_smoothed_i = 'none';
else % Smooth
    A_smoothed_i = [char(output_dir) char(orig_cifti_file( ...
        1:length(char(orig_cifti_file))-13)) '_SMOOTHED_' ...
        num2str(smoothing) '.' suffix];
    outfile = [A_smoothed_i min_cmd_motion '.' suffix2];
    if ~exist(A_smoothed_i, 'file')
        cmd = [wb_command ' -cifti-smoothing ' char(input_dir) ...
            char(orig_cifti_file) ' ' num2str(smoothing) ' ' ...
            num2str(smoothing) ' COLUMN ' char(output_dir) ...
            char(orig_cifti_file(1:length(char(orig_cifti_file) ...
            )-13)) '_SMOOTHED_' num2str(smoothing) '.' suffix ...
            ' -left-surface ' left '  -right-surface ' right];
        execute_display_and_clear(cmd, cmd);
    else %smoothed series already exists
        disp('Smoothed series already created for this subject')
    end
end
if ~exist(outfile, 'file') % check to see if the file already exists
    if strcmpi(smoothing, 'none')
        if ~exist('weights', 'var')
            weights = [' -weights ' char(output_dir) ...
                char(orig_motion_file) '_' ...
                num2str(FD_threshold) min_file_end];
        end
        cmd = [wb_command ' ' precision ...
            ' -cifti-correlation ' char(input_dir) ...
            char(orig_cifti_file) ' ' char(output_dir) ...
            char(orig_cifti_file) min_cmd_motion '.' suffix2 ...
            weights ' -fisher-z' memory_limit_option ' ' num2str(memory_limit_value)];
    else
        if ~exist('weights', 'var')
            weights = [' -weights ' char(output_dir) ...
                char(orig_motion_file) '_' ...
                num2str(FD_threshold) min_file_end];
        end
        cmd = [wb_command ' ' precision ' -cifti-correlation ' ...
            A_smoothed_i ' ' A_smoothed_i min_cmd_motion '.' ...
            suffix2 weights ' -fisher-z' memory_limit_option ' ' num2str(memory_limit_value)];
    end
    execute_display_and_clear(cmd, ['Running wb_command cifti-' ...
        'correlation. This may take a few minutes.']);
else
    disp([outfile ' already exists'])
end
end


function [all_frames, at_thresh, at_thr_min_lim, without] = sort_paths(...
    A, B, dtseries_E, FD_threshold, bagged_desired_minutes, ...
    motion_file, no_output, output_directory, remove_outliers, ...
    smoothed, stdev_temp_filename, suffix2, TR, wb_command, mask,conc)
% Build and return 4 lists of paths to connectivity matrix files, such
% that each list contains matrices with a certain amount of good data
% compared to the bagged_desired_minutes and FD_threshold:
without = [];        % All subject sessions with < 30 sec of good data
at_thr_min_lim = []; % Other frames at FD_threshold and bagged_desired_minutes
at_thresh = [];      % Other frames at FD_threshold
all_frames = [];     % Other frames regardless of bagged_desired_minutes & FD

if no_output
    output_directory = char(input_directory);
end

% Sort all connectivity matrix file paths
for i = 1:length(A)
    
    % Input validation
    [orig_cifti_path, input_directory, ...
        ~] = get_folder_params(A{i}, filesep);
    if strcmpi(smoothed, 'none')
        A_dir = strcat(char(output_directory), char(orig_cifti_path));
    else
        A_dir = smoothed{i};
    end
    
    % Sort subject sessions
    if strcmpi(motion_file, 'none')
        all_frames = [all_frames; strcat({A_dir}, ...
            '_all_frames_at_FD_', motion_file, '.', {suffix2})];
    else
        FDvec = get_FDvec(B{i}, FD_threshold);
        if strcmpi(dtseries_E, 'none')
            dt = dtseries_E;
        else
            dt = dtseries_E{i};
        end
        FDvec = additional_frame_removal(mask, dt, FDvec, ...
            input_directory, orig_cifti_path, ...
            remove_outliers, stdev_temp_filename, wb_command,i, conc);
        [at_thresh, at_thr_min_lim, without] = collect_conns( ...
            A_dir, suffix2, FD_threshold, FDvec, bagged_desired_minutes, ...
            TR, at_thresh, at_thr_min_lim, without);
    end
end
end


function FDvec = additional_frame_removal(additional_mask_conc, dt, FDvec, ...
    input_directory, orig_cifti_filename, remove_outliers,...
    stdev_temp_filename, wb_command, i, conc)
% additional frame removal depending on additional_mask
if strcmpi(additional_mask_conc, 'none')
    FDvec = remove_frames_from_FDvec([input_directory ...
        orig_cifti_filename], FDvec, stdev_temp_filename, ...
        wb_command, 15);
else
    [additional_mask_paths, ~] = get_paths_from_conc(additional_mask_conc);
    additional_mask = additional_mask_paths{i};
    FDvec = add_mask_to_FDvec(FDvec, additional_mask,conc,i);
    FDvec = remove_outliers_if(remove_outliers, FDvec, dt, ...
        stdev_temp_filename, wb_command, 15);
end
end


function FDvec = get_FDvec(file_with_FDvec, fd)
% Get FDvec from the file at file_with_FDvec
load(file_with_FDvec)
allFD = zeros(1, length(motion_data)); % motion_data is from file
for j = 1:length(motion_data)
    allFD(j) = motion_data{j}.FD_threshold;
end
FDidx = find(allFD == fd);
FDvec = motion_data{FDidx}.frame_removal;
FDvec = abs(FDvec-1);
end


function FDvec = remove_outliers_if(remove_outliers, FDvec, filename, ...
    stdev_temp_filename, wb_command, wait)
% Remove outliers from external mask if user said to; otherwise pass
if remove_outliers && ~strcmpi(filename, 'none')
    disp(['Removing outliers using .dtseries file ' filename])
    FDvec = remove_frames_from_FDvec(filename, FDvec, ...
        stdev_temp_filename, wb_command, wait);
else  % exist('remove_outliers','var') == 1 && remove_outliers == 0;
    disp(['Motion censoring performed on FD alone. '...
        'Frames with outliers in BOLD std dev not removed']);
end
end


function FDvec = add_mask_to_FDvec(FDvec, additional_mask_conc,conc,i)
% Add to FDvec to account for additional_mask
if strcmpi(additional_mask_conc, 'none')
    disp(['No additional mask supplied. Using full time series. ' ...
        'Frames will be excluded only by FD (unless removal of ' ...
        'outliers is indicated).'])
else
    % Load .txt file with 0s and 1s. 0s are frames to be discarded,
    % and 1s are frames to make your matrix.
    if strcmp('conc', conc)
        additional_mask_paths = importdata(additional_mask_conc);
    else
        additional_mask_paths = {additional_mask_conc};
    end
    
    additionalvec = load(additional_mask_paths{i});
    FDvec_temp = FDvec & (additionalvec);
    FDvec = FDvec_temp;
end
end


function FDvec = remove_frames_from_FDvec(cifti_file, FDvec, ...
    stdev, wb_command, wait)
% additional frame removal based on Outliers command: isoutlier with
% "median" method.
cmd = [wb_command ' -cifti-stats ' char(cifti_file) ...
    ' -reduce STDEV > ' stdev];
system(cmd);
if wait > 0
    disp(['Waiting ' num2str(wait) ' seconds for writing of temp ' ...
        'file before reading. (not an error)'])
    pause(wait);
end
clear cmd
STDEV_file=load(stdev); % load stdev of .nii file.
FDvec_keep_idx = find(FDvec==1); %find frames kept from the FD mask

% find outlier
Outlier_file=isthisanoutlier(STDEV_file(FDvec_keep_idx), 'median');
Outlier_idx=find(Outlier_file==1); %find outlier indices
FDvec(FDvec_keep_idx(Outlier_idx)) = 0; %set outliers to zero in FDvec
system(['rm ' stdev]); %clean up
clear STDEV_file FDvec_keep_idx Outlier_file Outlier_idx
end


function finish_and_save_concs(A, FD_threshold, bagged_desired_minutes, ...
    motion_file, no_output, output_directory, series_path, p_or_d, ...
    smoothing_kernel, all_frames, at_thresh, at_thr_min_lim, without)
% Given lists of paths to connectivity matrices, save them into their
% respective .conc files
if no_output
    [~, input_directory, ~] = get_folder_params(A{1}, filesep);
    output_directory =char(input_directory);
end
conc_names = {'all_frames', 'at_thresh', 'at_thr_min_lim', ...
    'without'};
concs = {all_frames, at_thresh, at_thr_min_lim, without};
for i=1:4
    conc_path = get_conc_path(series_path, p_or_d, ...
        FD_threshold, conc_names(i), bagged_desired_minutes, ...
        smoothing_kernel, motion_file, output_directory);
    make_conn_conc(conc_path, concs(i));
end
end


function [at_thresh, at_thresh_min_lim, without] = collect_conns( ...
    A_i, ext, FD_threshold, FDvec, min_lim, TR, ...
    at_thresh, at_thresh_min_lim, without)
% Get the names of connectivity matrices which meet FD threshold or
% lack enough subject data
fd = num2str(FD_threshold);
if strcmpi(min_lim, 'none')
    at_thresh = [at_thresh; strcat({A_i}, '_all_frames_at_FD_', ...
        {fd}, '.', {ext})];
else
    % Sort pconn based on how its good minutes compare to the limit
    good_frames_idx = find(FDvec == 1);
    good_minutes = (length(good_frames_idx)*TR)/60;
    if good_minutes < 0.5
        without = [without; strcat({A_i}, '_lessthan30sec_', ...
            {fd}, '.', {ext})];
    elseif good_minutes < min_lim
        at_thresh = [at_thresh; strcat({A_i}, ...
            '_all_frames_at_FD_', {fd}, '.', {ext})];
    elseif good_minutes >= min_lim
        at_thresh_min_lim = [at_thresh_min_lim; strcat({A_i}, '_', ...
            {num2str(min_lim)}, '_minutes_of_data_at_FD_', {fd}, ...
            '.', {ext})];
    else
        disp('Something is wrong generating .conc files.')
    end
end
end



function motion_mask_path = save_out_file(out_dir, orig_motion, fd, min_file_end, FDvec)
% Build output file name and save it
motion_mask_path = [char(out_dir) char(orig_motion) '_' num2str(fd) ...
    min_file_end];
fileID = fopen(motion_mask_path, 'w');
fprintf(fileID, '%1.0f\n', FDvec);
fclose(fileID);
end


function conc_path = get_conc_path(series_path, p_or_d, FD_threshold, ...
    minutes_condition, bagged_desired_minutes, smoothing, motion, output_dir)
% Build and return the path to one .conc file using input parameters
[~, series, ext] = fileparts(series_path);
conc_prefix = [series ext '_' p_or_d 'conn_of_' p_or_d 'tseries'];
fd = num2str(FD_threshold);
minutes_condition = char(minutes_condition);

if strcmpi(minutes_condition, 'all_frames')
    min = '_all_frames_at_FD_';
elseif strcmpi(minutes_condition, 'at_thresh_min_lim')
    min = ['_' num2str(bagged_desired_minutes) '_minutes_of_data_at_FD_'];
elseif strcmpi(minutes_condition, 'without')
    min = '_lessthan30sec_';
else
    min = '_all_frames_at_FD_';
end

if strcmpi(motion, 'none')
    conc_extra = [min motion];
else
    if strcmpi(smoothing, 'none')
        conc_extra = [min fd];
    else
        conc_extra = ['_SMOOTHED_' smoothing min fd];
    end
end
conc_path = [output_dir conc_prefix conc_extra '.conc'];
end


function make_conn_conc(concname, paths)
% Save .conc file listing paths to all connectivity matrices
paths = paths{1};
if ~isempty(paths)
    fileID = fopen(char(concname), 'w');
    [nrows, ~] = size(paths);
    for row = 1:nrows
        fprintf(fileID, '%s\n', char(paths{row}));
    end
    fclose(fileID);
end
end


