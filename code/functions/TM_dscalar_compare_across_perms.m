function TM_dscalar_compapare_across_perms(BASEDIR, dscalarswithassignments1, dscalarswithassignments2)
function TM_dscalar_compare_across_files(BASEDIR, dscalarswithassignments1, dscalarswithassignments2)
    % ... (initial setup code)

    % Load the dscalar file lists
    dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
    dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

    % Check if the lists have the same length
    if length(dscalar_list1) ~= length(dscalar_list2)
        error('The two dscalar lists do not have the same number of files.');
    end

    % Loop through the files and compare
    for i = 1:length(dscalar_list1)
        dscalar1 = dscalar_list1{i};
        dscalar2 = dscalar_list2{i};

        % Load data and perform analysis
        Mdscalar = read_cifti(dscalar1);
        Mdata = Mdscalar.cdata;

        Cdscalar = read_cifti(dscalar2);
        Cdata = Cdscalar.cdata;

        % Perform comparisons and analysis as in your original code
        % ...

    end
end

function dscalar_list = load_dscalar_list(dscalarswithassignments)
    % Your existing code to load the .conc file or individual dscalar files
    % ...
end







%% Code taking from other script that loads dscalars from .conc file



function TM_dscalar_compapare_across_perms(BASEDIR, dscalar_example)
%compare cross to movie template matching

%fig_dir='/projects/standard/smnelson/shared/projects/extended_scanning/code/TM_code/BeneTesting/figures';
BASEDIR='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/Template_Matching/TM_permutations/'

fig_dir=[ BASEDIR '/figures/AllPerms' ];
mkdir(fig_dir);
%dscalar1='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/sub-101/ses-1/restMENORDICrmnoisevols/1/Half1/abcd-SCAN_template/SCAN_network/sub-101_ses-1_task-restMENORDICrmnoisevols_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';
%dscalar2='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/TM_split_halves/sub-101/ses-1/restMENORDICrmnoisevols/1/Half2/abcd-SCAN_template/SCAN_network/sub-101_ses-1_task-restMENORDICrmnoisevols_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';
%dscalar_example='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/Template_Matching/TM_permutations/sub-101/ses-1/restMENORDICrmnoisevols/1/Half1/abcd-SCAN_template/SCAN_network/sub-101_ses-1_task-restMENORDICrmnoisevols_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';
% 
% %% I want these variable to be propigated from the dscalar_example but
% don't know how to do that
% BASEDIR='/panfs/jay/groups/34/yaco0006/shared/projects/HighField_7T/analyses/Template_Matching/TM_permutations/'
% SUB='101'
% SES='1'
% TASK='restMENORDICrmnoisevols';
% perm=1
% HALF1=1 %Data will be split 
% TEMPLATE='abcd-SCAN_template';
% NETWORKS='SCAN_network'
% DSCALAREXT='bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii';


    %% Start loop 

    mkdir(fig_dir);
    %addpath(genpath('/projects/standard/faird/ramirezj/code/internal/HighField'))
    %addpath(genpath('/home/yaco0006/shared/projects/extended_scanning/code/functions'))
    WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
    
num_permutations = 100; % Total number of permutations
num_networks=15;
network_stability_all = zeros(num_networks, num_permutations); % Replace num_networks with actual number
all_transition_matrices = zeros(num_networks, num_networks, num_permutations);
for perm = 1:num_permutations
    % Construct dscalar paths for current permutation
    dscalar1=[ BASEDIR '/sub-' SUB '/ses-' SES '/' TASK '/' num2str(perm) '/Half' num2str(HALF1) '/' TEMPLATE '/' NETWORKS '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii'];
    dscalar1=[ BASEDIR '/sub-' SUB '/ses-' SES '/' TASK '/' num2str(perm) '/Half' num2str(HALF2) '/' TEMPLATE '/' NETWORKS '/sub-' SUB '_ses-' SES '_task-' TASK '_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii'];

    %dscalar1 = ['/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/Template_Matching_split_halves/sub-AC/ses-combined/crossMENORDICrmnoisevols/' num2str(perm) '/Half1/abcd-SCAN_template/SCAN_network/**_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii'];
    %dscalar2 = ['/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/Template_Matching_split_halves/sub-AC/ses-combined/crossMENORDICrmnoisevols/' num2str(perm) '/Half2/abcd-SCAN_template/SCAN_network/*_bold_shuffled_timeseries_template_matched_Zscored_scanthresh3_recolored.dscalar.nii'];

    %Load movie data
    
    Mdscalar = read_cifti(dscalar1);
    Mdata = Mdscalar.cdata;
    
    %load crosshair data
    
    Cdscalar = read_cifti(dscalar2);
    Cdata = Cdscalar.cdata;
    
    
    s%% Investigation between network Transitions
    [transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Mdata, Cdata);
    
    %% Creating some summary statistics 
    
    transposed_transition_matrix_full = transpose(transition_matrix_full);
    
    all_transition_matrices(:,:,perm)=transposed_transition_matrix_full;
    
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

    % Store the results in the respective arrays
    network_stability_all(:, perm) = network_stability; % Example for network stability
    % Repeat for other metrics
end

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



%% End loop 



end
