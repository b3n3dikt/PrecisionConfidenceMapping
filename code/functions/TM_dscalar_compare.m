function TM_dscalar_compare(fig_dir, dscalar1, dscalar2)
%compare cross to movie template matching

%fig_dir='/projects/standard/smnelson/shared/projects/extended_scanning/code/TM_code/BeneTesting/figures';
%fig_dir='/home/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/figures';
%dscalar1='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/sub-101/ses-1/restMENORDICrmnoisevols/1/Half1/abcd-SCAN_template/SCAN_network/sub-101_ses-1_task-restMENORDICrmnoisevols_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';
%dscalar2='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/sub-101/ses-1/restMENORDICrmnoisevols/1/Half2/abcd-SCAN_template/SCAN_network/sub-101_ses-1_task-restMENORDICrmnoisevols_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';

%dscalar1='/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/sub-AC/video/abcd_template/subcort_included/sub-AC_ses-combined_task-videoMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_template_matched_Zscored_recolored.dscalar.nii';
%dscalar2='/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/sub-AC/cross/abcd_template/subcort_included/sub-AC_ses-combined_task-crossMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_template_matched_Zscored_recolored.dscalar.nii';

mkdir(fig_dir);

mkdir(fig_dir);
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))

%addpath(genpath('/projects/standard/faird/ramirezj/code/internal/HighField'))
%addpath(genpath('/home/yaco0006/shared/projects/extended_scanning/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';

%Load movie data

Mdscalar = cifti_read(dscalar1);
Mdata = Mdscalar.cdata;

%load crosshair data

Cdscalar = cifti_read(dscalar2);
Cdata = Cdscalar.cdata;



%% Investigation between network Transitions
[transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Mdata, Cdata);

% Transition matrix Figures
load('BED_xt_cmaps.mat')
cmap = (BED_xt_cmaps.gradient);
%without network vertices that stay the same
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(transition_matrix);
xlabel('Cross Hair Data')
ylabel('Movie Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_transition_matrix_network_changes_only'];
BED_exportfig(f, fig_out, 'png', 30); close

% with all transition and same networks
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(transition_matrix_full);
xlabel('Cross Hair Data')
ylabel('Movie Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_transition_matrix_all_vertices'];
BED_exportfig(f, fig_out, 'png', 30); close


%% Normalize Transition matrix to percentages to plot 
% Assuming transition_matrix_full contains the raw transition counts
network_totals = sum(transition_matrix_full, 2); % Total vertices per network (row-wise sum)

% Normalize each row by its total
normalized_transition_matrix = bsxfun(@rdivide, transition_matrix_full, network_totals);

% with all transition and same networks
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(normalized_transition_matrix);
xlabel('Crosshair Data')
ylabel('Movie Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_Percent_normalized_transition_matrix_all_vertices'];
BED_exportfig(f, fig_out, 'png', 30); close


%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

%left_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
%right_labels = {'N1', 'N2', 'N3', 'N4', 'N5', 'N6','N7','N8','N9', 'N10', 'N11', 'N12', 'N13', 'N14'};
left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON' , 'SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'};
alluvialflow(transition_matrix, left_labels, right_labels, 'Network Transitions from Half1 to Half2 Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Half1_to_Half2'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing all vertices i.e. the ones that stay the same and the ones that

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON' 'SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON' 'SCAN'};

alluvialflow(transition_matrix_full, left_labels, right_labels, 'Network Transitions from Half1 to Half2 Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Half1_to_Half2'];
BED_exportfig(f, fig_out, 'png',9); close



%% Plotting Alluvia again with other direction

%% if not transposing you can Investigation between network Transitions
%[transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Cdata, Mdata);

transposed_transition_matrix = transpose(transition_matrix);
transposed_transition_matrix_full = transpose(transition_matrix_full);

%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);


left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};
alluvialflow(transposed_transition_matrix, left_labels, right_labels, 'Network Transitions from Half2 to Half1 Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Half2_to_Half1'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing all vertices i.e. the ones that stay the same and the ones that

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};

alluvialflow(transposed_transition_matrix_full, left_labels, right_labels, 'Network Transitions from Half2 to Half1 Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Half2_to_Half1'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);


left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON','SCAN'};
alluvialflow(transposed_transition_matrix, left_labels, right_labels, 'Network Transitions from Half2 to Half1 Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Half2_to_Half1'];
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

% with all transition and same networks
f = figure('Units', 'pixel', 'Position', [0 0 800 800],'visible','off');
imagesc(transposed_normalized_transition_matrix);
xlabel('Movie Data')
ylabel('Crosshair Data')
colormap(cmap); colorbar; axis square;
fig_out = [fig_dir '/figure_Percent_normalized_transition_matrix_all_vertices_Crosshair_oercent'];
BED_exportfig(f, fig_out, 'png', 30); close


%% Extracting difference and consistent matrices

% Identify changes between Mdata and Cdata
changes = double(Mdata ~= Cdata);
sum(changes)
% Identify consistent (unchanged) elements
consistent = double(~changes);
sum(consistent)

%


%% Creating some summary statistics 

transposed_transition_matrix_full = transpose(transition_matrix_full);

num_vertices = sum(transposed_transition_matrix_full, 'all');
diagonal = diag(transposed_transition_matrix_full);
same_count = sum(diagonal);
percent_same = (same_count / num_vertices) * 100;

% Percent of vertices that changed to each network
percent_change_to_network = zeros(size(transposed_transition_matrix_full, 1), 1);
for i = 1:length(percent_change_to_network)
    percent_change_to_network(i) = (sum(transposed_transition_matrix_full(:, i)) - transposed_transition_matrix_full(i, i)) / num_vertices * 100;
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

% Assuming network_stability is calculated as shown in the previous example
%network_labels = {'Network 1', 'Network 2', ..., 'Network N'}; % Replace with your actual network names

% Create a bar plot for network stability
f = figure('Units', 'pixel', 'Position', [0 0 800 1000]);
%f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

bar(network_stability)
xticks(1:length(left_labels))
xticklabels(left_labels)
xlabel('Networks')
ylabel('Stability Ratio')
title('Network Stability')
%rotateXLabels(gca, 45) % Optional: Rotate x labels for better visibility

% Save the figure if needed
fig_out = [fig_dir '/Network_Stability_Crosshair2movie'];
BED_exportfig(f, fig_out, 'png',9); close
close all

end
