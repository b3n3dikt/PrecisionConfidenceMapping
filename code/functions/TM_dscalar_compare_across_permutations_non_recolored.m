function TM_dscalar_compare_across_permutations_non_recolored(BASEDIR, dscalarswithassignments1, percent_holdout, make_NetConfMaps)

% BASEDIR='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-05/ses-combined'
% dscalarswithassignments1='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-05/ses-combined/sub-05_ses-combined_successful_half1.conc'
% dscalarswithassignments2='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-05/ses-combined/sub-05_ses-combined_successful_half2.conc'
% 

fig_dir=[ BASEDIR '/figures/Percent_Holdout-' percent_holdout ];
mkdir(fig_dir);

addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
%addpath(genpath('/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/read_write_cifti/'));

addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';


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



cifti_dir=[ fig_dir '/non_recolored_ciftis' ];
mkdir(cifti_dir);
%make_NetConfMaps=1
if make_NetConfMaps == 1

    addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    %visualizedscalars(dscalarswithassignments,outputname,output_map_type, plot_results,surface_only,if_mode_which_network_number)
    wb_command = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64/wb_command';
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

    filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig.png');
    createImageGridWithLabels(cifti_dir, 'All_surface_networks_confidence_maps_images_with_labels.png', filePattern);

    filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_AX.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_AX_networks_confidence_maps_images_with_labels.png', filePattern);
    filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_CO.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_CO_networks_confidence_maps_images_with_labels.png', filePattern);
    filePattern = fullfile(cifti_dir, 'Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability_fig_PA.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_PA_networks_confidence_maps_images_with_labels.png', filePattern);


    % Making Mode Images Define the wildcard pattern for the files
    
    
    filePattern = [ cifti_dir '/Mode_of_Shuffled_dscalars_Percent_holdout_population_mode_proportion.dscalar.nii'];
    % -----------------------------------------------------------
    %  convert mode-proportion map to dlabel
    % -----------------------------------------------------------
    shellScript = '/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/dscalar2dlabel.sh';
    dscalarFile = fullfile(cifti_dir,'Mode_of_Shuffled_dscalars_Percent_holdout_population_mode.dscalar.nii');
    disp("Running dlable conversion")
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
    uppercolor=18;
    lowerthresh=0.1;
    upperthresh=30;
    colorscheme=[ 'power_surf' ]
    for n = 1:length(fullFilePaths)
        confcifti=fullFilePaths{n};

        plot_surface_and_subcorticals_parcellation(confcifti, cifti_dir,lowercolor,uppercolor,lowerthresh, upperthresh, colorscheme)

    end
%/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.4.sh ${1} ${fileroot_name_short} ${filedir_name} FALSE 1 18 power_surf TRUE 0.1 30 THRESHOLD_TEST_SHOW_INSIDE TRUE TRUE png 8 118 FALSE /projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene /projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_scalar_MSI.scene /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii /projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii"

end

end





