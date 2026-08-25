function TM_dscalar_compare_across_files(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, make_NetConfMaps)

%BASEDIR='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined'
%dscalarswithassignments1='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/sub-01_ses-combined_successful_half1.conc'
%dscalarswithassignments2='/home/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/sub-01_ses-combined_successful_half2.conc'


fig_dir=[ BASEDIR '/figures/AllPerms' ];
mkdir(fig_dir);

%addpath(genpath('/projects/standard/faird/ramirezj/code/internal/HighField'))
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
%addpath(genpath('/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/read_write_cifti/'));

addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';


% Load the dscalar file lists
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

% Check if the lists have the same length
if length(dscalar_list1) ~= length(dscalar_list2)
    error('The two dscalar lists do not have the same number of files.');
end
num_permutations = length(dscalar_list1); % Total number of comparisons
tempscalar = dscalar_list1{1};
tmpdscalar = cifti_read(tempscalar);
tmpdata = tmpdscalar.cdata;
num_networks=length(unique(tmpdata));
network_stability_all = zeros(num_networks, num_permutations); % Replace num_networks with actual number
all_transition_matrices = zeros(num_networks, num_networks, num_permutations);


%% Loop through the files and compare
% 
for i = 1:length(dscalar_list1)

    dscalar1 = dscalar_list1{i};
    dscalar2 = dscalar_list2{i};

    % Load data and perform analysis
    Mdscalar = cifti_read(dscalar1);
    Mdata = Mdscalar.cdata;

    Cdscalar = cifti_read(dscalar2);
    Cdata = Cdscalar.cdata;

    %% Investigation between network Transitions
    [transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Mdata, Cdata);

    %% Creating some summary statistics

    transposed_transition_matrix_full = transpose(transition_matrix_full);

    all_transition_matrices(:,:,i)=transposed_transition_matrix_full;

    num_vertices = sum(transposed_transition_matrix_full, 'all');
    diagonal = diag(transposed_transition_matrix_full);
    same_count = sum(diagonal);
    percent_same = (same_count / num_vertices) * 100;

    % Percent of vertices that changed to each network
    percent_change_to_network = zeros(size(transposed_transition_matrix_full, 1), 1);
    for j = 1:length(percent_change_to_network)
        percent_change_to_network(j) = (sum(transposed_transition_matrix_full(:, j)) - transposed_transition_matrix_full(j, j)) / num_vertices * 100;
    end

    % Most Common Transitions
    transition_matrix_no_diag = transposed_transition_matrix_full;
    transition_matrix_no_diag(1:size(transition_matrix_no_diag, 1)+1:end) = 0; % Set diagonal to zero
    [max_transitions, max_indices] = max(transition_matrix_no_diag, [], 2); % Max in each row

    % Network Stability
    network_stability = diag(transposed_transition_matrix_full) ./ sum(transposed_transition_matrix_full, 2);

    % Overall Change Rate
    total_transitions = sum(transition_matrix_no_diag, 'all');
    overall_change_rate = total_transitions / num_vertices * 100;

    % Store the results in the respective arrays
    network_stability_all(:, i) = network_stability; % Example for network stability
    % Repeat for other metrics

end
%%
% Calculate averages and standard deviations across permutations
avg_network_stability = mean(network_stability_all, 2);
std_network_stability = std(network_stability_all, 0, 2);

% Plotting with error bars

% Add labels, title, etc.
left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};


% Create a bar plot for network stability
f = figure('Units', 'pixel', 'Position', [0 0 800 1000]);

% Plotting the average network stability as bars
bar(avg_network_stability, 'FaceColor', 'blue'); % You can choose a color
hold on; % Hold on to add error bars to the same plot

% Adding error bars
errorbar(1:length(avg_network_stability), avg_network_stability, std_network_stability, 'LineStyle', 'none', 'Color', 'black');

xticks(1:length(left_labels));
xticklabels(left_labels);
xlabel('Networks');
ylabel('Stability Ratio');
title('Network Stability');

% Optionally, rotate x-axis labels for better readability
set(gca, 'XTickLabelRotation', 45); % Rotate labels by 45 degrees

% Save the figure if needed
fig_out = [fig_dir '/Network_Stability_SplitHalf1toHalf2'];
saveas(f, fig_out, 'png');
close all;

% Calculate averages and standard deviations across permutations
avg_transition_matrix = mean(all_transition_matrices, 3);
std_transition_matrix = std(all_transition_matrices, 0, 3);



% Transition matrix Figures
load('BED_xt_cmaps.mat')
cmap = (BED_xt_cmaps.gradient);
%without network vertices that stay the same
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(avg_transition_matrix);
xlabel('Split Half1 Data')
ylabel('Split Half2 Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_transition_matrix_average_across_perumations'];
BED_exportfig(f, fig_out, 'png', 30); close

% Transition matrix Figures
load('BED_xt_cmaps.mat')
cmap = (BED_xt_cmaps.gradient);
%without network vertices that stay the same
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(std_transition_matrix);
xlabel('Split Half1 Data')
ylabel('Split Half2 Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_transition_matrix_Standard_Dev_across_perumations'];
BED_exportfig(f, fig_out, 'png', 30); close

%% Normalize Transition matrix to percentages to plot 
% Assuming transition_matrix_full contains the raw transition counts
network_totals = sum(transition_matrix_full, 2); % Total vertices per network (row-wise sum)

% Normalize each row by its total
normalized_transition_matrix = bsxfun(@rdivide, transition_matrix_full, network_totals);

% with all transition and same networks
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(normalized_transition_matrix);
xlabel('Split Half 1')
ylabel('Split Half 2')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_Percent_normalized_transition_matrix_all_vertices'];
BED_exportfig(f, fig_out, 'png', 30); close



%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

%left_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
%right_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON' , 'SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'};
alluvialflow(avg_transition_matrix, left_labels, right_labels, 'Average Network Transitions from Half1 to Half2 Template Matching 100 Permutations');
fig_out = [fig_dir '/AlluviaFlow_plot_Average_Network_transitions_from_Half1_to_Half2_permutations-' num2str(num_permutations)];
BED_exportfig(f, fig_out, 'png',9); close

%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

%left_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
%right_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON' , 'SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'};
alluvialflow(std_transition_matrix, left_labels, right_labels, 'STDEV Network Transitions from Half1 to Half2 Template Matching 100 Permutations');
fig_out = [fig_dir '/AlluviaFlow_plot_STDEV_Network_transitions_from_Half1_to_Half2_permutations-' num2str(num_permutations)];
BED_exportfig(f, fig_out, 'png',9); close

%% Normalized alluvia plot

% Assuming transition_matrix_full contains the raw transition counts
transposed_network_totals = sum(transposed_transition_matrix_full, 2); % Total vertices per network (row-wise sum)

% Normalize each row by its total
transposed_normalized_transition_matrix = bsxfun(@rdivide, transposed_transition_matrix_full, transposed_network_totals);

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

%left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
%right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};

alluvialflow(transposed_normalized_transition_matrix, left_labels, right_labels, 'Network Transitions from Crosshair to Movie Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Half2_to_Half1_normalized_percent'];
BED_exportfig(f, fig_out, 'png',9); close




cifti_dir=[ BASEDIR '/figures/AllPerms/ciftis' ];
mkdir(cifti_dir);
%make_NetConfMaps=1
if make_NetConfMaps == 1

    addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    %visualizedscalars(dscalarswithassignments,outputname,output_map_type, plot_results,surface_only,if_mode_which_network_number)
    wb_command = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64/wb_command';
    fig_out=[cifti_dir '/Probability_Maps_100_perm_TM_Split_half-1']
    visualizedscalars(dscalarswithassignments1,fig_out,'calc_probability',1,0,0);
    fig_out=[cifti_dir '/Probability_Maps_100_perm_TM_Split_half-2']
    visualizedscalars(dscalarswithassignments2,fig_out,'calc_probability',1,0,0);
    fig_out=[cifti_dir '/Mode_of_Shuffled_dscalaers_Split_half-1']
    visualizedscalars(dscalarswithassignments2,fig_out,'calc_mode',1,0,0);
    %% Making pngs of figures 
    
    % Define the wildcard pattern for the files
    filePattern = [ cifti_dir '/Probability_Maps*half-1*dscalar.nii'];
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
    filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig.png');
    createImageGrid(cifti_dir, 'All_surface_networks_confidence_maps_images.png', filePattern);

    filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig.png');
    createImageGridWithLabels(cifti_dir, 'All_surface_networks_confidence_maps_images_with_labels.png', filePattern);

    filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig_AX.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_AX_networks_confidence_maps_images_with_labels.png', filePattern);
    filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig_CO.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_CO_networks_confidence_maps_images_with_labels.png', filePattern);
    filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig_PA.png');
    createImageGridWithLabels(cifti_dir, 'All_subcortical_PA_networks_confidence_maps_images_with_labels.png', filePattern);


    % Making Mode Images Define the wildcard pattern for the files
    
    
    filePattern = [ cifti_dir '/Mode_of_Shuffled_dscalaers_Split_half-1_population_mode_proportion.dscalar.nii'];
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

    filePattern = [ cifti_dir '/Mode_of_Shuffled_dscalaers_Split_half-1_population_mode.dscalar.nii'];
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





