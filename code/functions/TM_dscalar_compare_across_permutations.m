function TM_dscalar_compare_across_permutations(TASK_DIR, dscalarswithassignments1, percent_holdout, make_NetConfMaps)
% TASK_DIR: full path to the task folder (e.g. BASEDIR/sub-SUB/ses-SES/task-TASK_method-...)
% Figures are written to TASK_DIR/figures/ciftis/

fig_dir = fullfile(TASK_DIR, 'figures');
mkdir(fig_dir);

% STANDALONE PCM: Removed hardcoded addpath calls. cifti-matlab and
% functions are already on path via MATLAB_ADDPATH set in config.sh.
% wb_command is assumed on PATH via `module load workbench`.
this_fn = mfilename('fullpath');
[fn_dir, ~] = fileparts(this_fn);          % code/functions/
pcm_root    = fileparts(fileparts(fn_dir)); % PCM_standalone/
tm_dir      = fullfile(pcm_root, 'template_matching');
WB_DIR      = ''; % not used — wb_command is on PATH


% Load the dscalar file lists
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);


num_permutations = length(dscalar_list1); % Total number of comparisons
tempscalar = dscalar_list1{1};
tmpdscalar = cifti_read(tempscalar);
tmpdata = tmpdscalar.cdata;
num_networks=length(unique(tmpdata));
network_stability_all = zeros(num_networks, num_permutations); % Replace num_networks with actual number
all_transition_matrices = zeros(num_networks, num_networks, num_permutations);

%% Test if networks are the same 
% for i = 1:length(dscalar_list1)
% 
%     dscalar1 = dscalar_list1{i};
% 
%     % Load data and perform analysis
%     Mdscalar = cifti_read(dscalar1);
%     Mdata = Mdscalar.cdata;
%     Munique(i)=size(unique(Mdata),1);
% 

% 
% 
% end
%% Loop through the files and compare
% 



cifti_dir = fullfile(fig_dir, 'ciftis');
mkdir(cifti_dir);
%make_NetConfMaps=1
if make_NetConfMaps == 1

    % STANDALONE PCM: template_matching is already on path via MATLAB_ADDPATH.
    % wb_command is assumed on PATH via `module load workbench`.
    addpath(genpath(tm_dir));

    %visualizedscalars(dscalarswithassignments,outputname,output_map_type, plot_results,surface_only,if_mode_which_network_number)
    wb_command = 'wb_command';
    fig_out=[cifti_dir '/Probability_Maps_across_perms_TM_Percent_holdout']
    visualizedscalars(dscalarswithassignments1,fig_out,'calc_probability',1,0,0);

    fig_out=[cifti_dir '/Mode_of_Shuffled_dscalars_Percent_holdout']
    visualizedscalars(dscalarswithassignments1,fig_out,'calc_mode',1,0,0);
    %% Making pngs of figures 
    
    % Define the wildcard pattern for the files
    filePattern = [ cifti_dir '/Probability_Maps_across_perms_TM_Percent_holdout_*dscalar.nii'];
    % Use the dir function to get a list of files matching the pattern
    fileListStruct = dir(filePattern); 
    % Extract the names of the files from the struct
    fileNames = {fileListStruct.name};
    
    % (Optional) Build full paths to the files if needed
    fullFilePaths = fullfile({fileListStruct.folder}, fileNames);
    lowerthresh=0;
    upperthresh=1;
    colorscheme=[ 'ROY-BIG-BL' ]
    for n = 1:length(fullFilePaths)
        confcifti=fullFilePaths{n};

        plot_surface_and_subcorticals(confcifti, cifti_dir, lowerthresh, upperthresh, colorscheme)

    end

    % Directory containing the PNG files
    
    % Pattern to match your files
    filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig.png');
    createImageGrid(cifti_dir, 'All_surface_networks_confidence_maps_images.png', filePattern);

    % The labeled image grids are cosmetic. insertText() inside
    % createImageGridWithLabels needs the Computer Vision Toolbox, and a
    % surface-only run produces no subcortical PNGs, so these calls can fail.
    % Wrap them so a failure here can never block the critical dlabel
    % conversion and thresholding steps further below.
    try
        filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig.png');
        createImageGridWithLabels(cifti_dir, 'All_surface_networks_confidence_maps_images_with_labels.png', filePattern);

        filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_AX.png');
        createImageGridWithLabels(cifti_dir, 'All_subcortical_AX_networks_confidence_maps_images_with_labels.png', filePattern);
        filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_CO.png');
        createImageGridWithLabels(cifti_dir, 'All_subcortical_CO_networks_confidence_maps_images_with_labels.png', filePattern);
        filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_PA.png');
        createImageGridWithLabels(cifti_dir, 'All_subcortical_PA_networks_confidence_maps_images_with_labels.png', filePattern);
    catch ME
        warning('[PCM] Labeled image-grid step failed (%s); continuing to dlabel + thresholding.', ME.message);
    end


    % Making Mode Images Define the wildcard pattern for the files
    
    
    filePattern = [ cifti_dir '/Mode_of_Shuffled_dscalars_Percent_holdout_population_mode_proportion.dscalar.nii'];
    % -----------------------------------------------------------
    %  convert mode-proportion map to dlabel
    % -----------------------------------------------------------
    % STANDALONE PCM: dscalar2dlabel.sh is bundled in template_matching/
    shellScript = fullfile(tm_dir, 'dscalar2dlabel.sh');
    dscalarFile = fullfile(cifti_dir,'Mode_of_Shuffled_dscalars_Percent_holdout_population_mode.dscalar.nii');

    if exist(dscalarFile,'file')
        [status,out] = system(sprintf('%s "%s"', shellScript, dscalarFile));

        if status ~= 0
            warning('dscalar2dlabel.sh returned exit code %d.\n%s', status, out);
        end
    else
        warning('Mode-proportion dscalar not found  skipping dlabel conversion.');
    end
    
    % Use the dir function to get a list of files matching the pattern
    fileListStruct = dir(filePattern); 
    % Extract the names of the files from the struct
    fileNames = {fileListStruct.name};
    
    % (Optional) Build full paths to the files if needed
    fullFilePaths = fullfile({fileListStruct.folder}, fileNames);
    lowerthresh=0;
    upperthresh=1;
    colorscheme=[ 'ROY-BIG-BL' ]
    for n = 1:length(fullFilePaths)
        confcifti=fullFilePaths{n};

        plot_surface_and_subcorticals(confcifti, cifti_dir, lowerthresh, upperthresh, colorscheme)

    end

    filePattern = [ cifti_dir '/Mode_of_Shuffled_dscalars_Percent_holdout_population_mode.dscalar.nii'];
    % Use the dir function to get a list of files matching the pattern
    fileListStruct = dir(filePattern); 
    % Extract the names of the files from the struct
    fileNames = {fileListStruct.name};
    
    % (Optional) Build full paths to the files if needed
    fullFilePaths = fullfile({fileListStruct.folder}, fileNames);
    lowercolor=1;
    % FIXED at 18, matching the 'power_surf' colorscheme below (a fixed 1-18 Power/ABCC
    % network palette, same convention set_cifti_powercolors.m encodes for the per-perm
    % dscalars). Was briefly changed to num_networks=length(unique(tmpdata)) (line 26) in
    % PCM_multimethod for macaque support, but that's WRONG for this fixed palette:
    % num_networks is only how many of the 18 network IDs are actually PRESENT in one
    % subject's data (e.g. 15 if that subject has no vertices in 3 of the networks), not the
    % palette's scale ceiling -- using it here compresses the 1-18 color scale down to
    % 1-num_networks, so the same network ID renders a different color than the fixed
    % palette intends. This repo was rsync'd from PCM_multimethod after that regression
    % landed there, so it inherited the same bug. Fixed to 18 here too (user confirmed
    % 2026-08-26: real network IDs in these dscalars are a subset of 1-18, e.g. missing
    % 4/6/17, and the power_surf bar maps 1=red...18=magenta regardless of which IDs are
    % present).
    uppercolor=18;
    lowerthresh=0.1;
    upperthresh=30;
    colorscheme=[ 'power_surf' ]
    for n = 1:length(fullFilePaths)
        confcifti=fullFilePaths{n};

        plot_surface_and_subcorticals_parcellation(confcifti, cifti_dir,lowercolor,uppercolor,lowerthresh, upperthresh, colorscheme)

    end
%/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.4.sh ${1} ${fileroot_name_short} ${filedir_name} FALSE 1 18 power_surf TRUE 0.1 30 THRESHOLD_TEST_SHOW_INSIDE TRUE TRUE png 8 118 FALSE /projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_scalar_MSI.scene /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"

    % -----------------------------------------------------------------
    % Threshold probability maps at standard levels
    % -----------------------------------------------------------------
    fprintf('[PCM] Running threshold_confidence_maps for %s\n', cifti_dir);
    thresholds = [0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 0.99];
    for t = thresholds
        threshold_confidence_maps(cifti_dir, str2double(percent_holdout), t, true);
    end
    fprintf('[PCM] Thresholding complete.\n');

end

end





