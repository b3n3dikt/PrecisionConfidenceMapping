function [cii_save_name, dropout_indices] = interpolate_noise_for_timeseries(dtseries_file,wb_command,run_locally,outputdir)

%INTERPOLATE_NOISE_FOR_SUBCORTICALS - This function works by finding
%voxels/grayordiantes in thetimseries that are equal to 0 (exactly) and
%injects noise into each frame based on the mean and standard deviation of
%the grayordinates in the same structure.

%R. Hermosillo 10/13/2022
%Inputs are: dtseries file = full path to the dtseriesfile
%wb_command = full path to workbench command.
%run_locally = Set to 1 if your running this on Robert's Desktop computer. Set to 0
%if you're running this on MSI. (This will automatically load the necessary cifti dependencies.)

%some dependencies used by this software:
%Gifti 1.6
%Matlab-cifti
%ft_read_cifti_mod - a utility that can be downloaded from the Midnight
%Scan Clud database.

%% Step 0: Add dependency paths
%add cifti paths
if isnumeric(run_locally) ==0
run_locally = str2num(run_locally);
end

if run_locally ==1
    %Some hardcodes:
    wb_command = ('C:\Users\hermosir\Desktop\workbench\bin_windows64\wb_command');
    addpath(genpath('C:\Users\hermosir\Documents\repos\HCP_MATLAB'));
    addpath('C:\Users\hermosir\Documents\repos\MSCcodebase-master\Utilities\read_write_cifti\utilities')
    addpath('C:\Users\hermosir\Documents\repos\MSCcodebase-master\Utilities\read_write_cifti\gifti')
    addpath('C:\Users\hermosir\Documents\repos\MSCcodebase-master\Utilities\read_write_cifti\fileio')
    %support_folder='C:\Users\hermosir\Documents\repos\support_folder';
else
    this_code = which('template_matching_RH');
    [code_dir,~] = fileparts(this_code);
    support_folder=[code_dir '/support_files']; %find support files in the code directory.
    addpath(genpath(support_folder));
    settings=settings_comparematrices;%
    np=size(settings.path,2);
    disp('Attempting to add neccesaary paths and functions.')
    warning('off') %supress addpath warnings to nonfolders.
    for i=1:np
        addpath(genpath(settings.path{i}));
    end
    warning('on')
    % Check if wb_command has been provided
    if ~exist('wb_command', 'var') || isempty(wb_command)
        % If wb_command is not provided or is empty, set the default path
        wb_command = settings.path_wb_c; %path to wb_command
    end
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/read_write_cifti/'));
end

%% Step 1 - Open timseries file
[filepath,filenamewext1,ext2] = fileparts(dtseries_file);
[~,filename,ext1] = fileparts(filenamewext1);
disp('Loading cifti...')
cii = ciftiopen(dtseries_file,wb_command);

timeseries = cii.cdata;
interpolated_timeseries = timeseries;
ftdtseries =ft_read_cifti_mod(dtseries_file);
all_vertices_timeseries_structs = ftdtseries.brainstructure;
isgray_structs = all_vertices_timeseries_structs(find(all_vertices_timeseries_structs>0));
total_zeros = sum(timeseries(:,1) ==0);
%% Step2 generate (normally-distributed) random noise using the mean and standard deviation of each
%frame.
unique_structs = unique(isgray_structs);

for i = 1:max(unique_structs) % go through all 21 structures.
    this_structs_timseries = timeseries(isgray_structs ==i,:);
    orig_indices_for_this_struct = find(isgray_structs ==i);
    
    %[A] = find(this_structs_timseries(:,1) ==0); % get indices of the missing data.
    [dropout_indices] = find(this_structs_timseries(:,end) ==0); % get indices of the missing data.
    
     bad_vox = isnan(this_structs_timseries(:,1));
    badvox_indices = find(bad_vox ==1);
    
    if isempty(dropout_indices)
        disp(['No 0s rows found in structure: ' char(ftdtseries.brainstructurelabel(i))]);
    else
        numdropout = size(dropout_indices,1);
        disp(['Number of voxels with 0s: ' num2str(numdropout) ' in ' char(ftdtseries.brainstructurelabel(i))]);
        
        isdropout=this_structs_timseries(:,1) ==0;
        hadsignal=this_structs_timseries(:,1) ~=0;
        
        %subts = this_structs_timseries(59413:end,:);
        %isdropout_sub = isdropout(59413:end,:);
        %hadsignal_sub = hadsignal(59413:end,:);
        random_noise_for_vox = zeros(size(dropout_indices,1),size(this_structs_timseries,2)); %preallocate
        submeans = mean(this_structs_timseries(hadsignal,:),1); % get mean of only subcortical regions that have a signal
        substdev = std(this_structs_timseries(hadsignal,:),1);
        
        for t=1:size(timeseries,2)
            random_noise_for_vox(:,t) = normrnd(submeans(t),substdev(t),[1,numdropout]);
        end
        %timeseries(A,:) = random_noise_for_vox;
        interpolated_timeseries(orig_indices_for_this_struct(dropout_indices),:) = random_noise_for_vox;
    end
end
disp(['total found = ' num2str(total_zeros)])
%fill in the missing frames (A are the indices) with the random noise.
cii.cdata = interpolated_timeseries;
if exist('outputdir','var') ~=0
    cii_save_name = [outputdir filesep filename '_spatially_interpolated' ext1 ext2];
else
    cii_save_name = [filepath filesep filename '_spatially_interpolated' ext1 ext2];
end
ciftisave(cii,cii_save_name,wb_command)
disp('Done interpolateing missing voxels/grayordinates.')

end