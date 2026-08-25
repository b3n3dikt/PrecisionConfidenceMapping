function Cross2movie_TM_compapare(fig_dir)
%compare cross to movie template matching

%fig_dir='/projects/standard/smnelson/shared/projects/extended_scanning/code/TM_code/BeneTesting/figures';
fig_dir='/home/yaco0006/shared/projects/extended_scanning/code/TM_code/BeneTesting/figures2';

mkdir(fig_dir);
addpath(genpath('/projects/standard/faird/ramirezj/code/internal/HighField'))
addpath(genpath('/projects/standard/smnelson/shared/projects/extended_scanning/code/TM_code/BeneTesting/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';

%Load movie data
Mscalar_path='/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/sub-AC/video/abcd_template/subcort_included/sub-AC_ses-combined_task-videoMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_template_matched_Zscored_recolored.dscalar.nii';
Mdscalar = read_cifti(Mscalar_path);
Mdata = Mdscalar.cdata;
Mdtseries_path = '/home/smnelson/shared/projects/extended_scanning/derivatives/fmri_prep/video/xcpd/xcp_d/sub-AC/ses-combined/func/sub-AC_ses-combined_task-videoMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii';
Mdtseries = read_cifti(Mdtseries_path);
Mdata_dt = Mdtseries.cdata;
%load crosshair data
Cscalar_path='/projects/standard/smnelson/shared/projects/extended_scanning/TM_outputs/sub-AC/cross/abcd_template/subcort_included/sub-AC_ses-combined_task-crossMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated_template_matched_Zscored_recolored.dscalar.nii';
Cdscalar = read_cifti(Cscalar_path);
Cdata = Cdscalar.cdata;
Cdtseries_path = '/home/smnelson/shared/projects/extended_scanning/derivatives/fmri_prep/cross/xcpd/xcp_d/sub-AC/ses-combined/func/sub-AC_ses-combined_task-crossMENORDICrmnoisevols_space-fsLR_den-91k_desc-interpolated_bold_spatially_interpolated.dtseries.nii';
Cdtseries = read_cifti(Cdtseries_path);
Cdata_dt = Cdtseries.cdata;

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
left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
alluvialflow(transition_matrix, left_labels, right_labels, 'Network Transitions from Movie to Crosshair Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Movie_to_Cross'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing all vertices i.e. the ones that stay the same and the ones that

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};

alluvialflow(transition_matrix_full, left_labels, right_labels, 'Network Transitions from Movie to Crosshair Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Movie_to_Cross'];
BED_exportfig(f, fig_out, 'png',9); close



%% Plotting Alluvia again with other direction

%% if not transposing you can Investigation between network Transitions
%[transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Cdata, Mdata);

transposed_transition_matrix = transpose(transition_matrix);
transposed_transition_matrix_full = transpose(transition_matrix_full);

%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);


left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
alluvialflow(transposed_transition_matrix, left_labels, right_labels, 'Network Transitions from Crosshair to Movie Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Cross_to_Movie'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing all vertices i.e. the ones that stay the same and the ones that

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};

alluvialflow(transposed_transition_matrix_full, left_labels, right_labels, 'Network Transitions from Crosshair to Movie Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Cross_to_Movie'];
BED_exportfig(f, fig_out, 'png',9); close



%% Between network alluvia plot figure showing only vertices that change
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);


left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
alluvialflow(transposed_transition_matrix, left_labels, right_labels, 'Network Transitions from Crosshair to Movie Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_Only_Network_transitions_from_Cross_to_Movie'];
BED_exportfig(f, fig_out, 'png',9); close

%% Normalized alluvia plot

% Assuming transition_matrix_full contains the raw transition counts
transposed_network_totals = sum(transposed_transition_matrix_full, 2); % Total vertices per network (row-wise sum)

% Normalize each row by its total
transposed_normalized_transition_matrix = bsxfun(@rdivide, transposed_transition_matrix_full, transposed_network_totals);

f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

left_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};
right_labels = {'DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL','CO','SMD','SML', 'AUD', 'Tpole', 'MTL', 'PMN', 'PON'};

alluvialflow(transposed_normalized_transition_matrix, left_labels, right_labels, 'Network Transitions from Crosshair to Movie Template Matching');
fig_out = [fig_dir '/AlluviaFlow_plot_All_Network_transitions_from_Cross_to_Movie_normalized_percent'];
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

% Compute mean signal for Mdata_dt where networks change
% Multiplying the dtseries matrix with the changes mask (replicated to match the size)
% and then computing the mean across rows
mean_changes_M = mean(Mdata_dt(changes == 1, :), 1);
mean_consistent_M = mean(Mdata_dt(changes == 0, :), 1);
% Compute mean signal for Cdata_dt where networks are consistent
% Similarly, multiplying with the consistent mask and computing the mean
mean_consistent_C = mean(Cdata_dt(consistent == 1, :), 1);


%mean_changes_M = rand(10, 1);  % example dummy data for testing 4713 time points
%mean_consistent_M = rand(10, 1);  % 4713 time points
% Create a figure
figure;
f = figure('Units', 'pixel', 'Position', [0 0 1600 600]);

% Plot for mean_changes_M
subplot(2, 1, 1); % Two rows, one column, first subplot
plot(mean_changes_M, 'r'); % 'r' for red color
title('Mean Time Series for Changes');
xlabel('Time Points');
ylabel('Mean Signal');
legend('Mean Changes');

% Plot for mean_consistent_M
subplot(2, 1, 2); % Two rows, one column, second subplot
plot(mean_consistent_M, 'b'); % 'b' for blue color
title('Mean Time Series for Consistent Networks');
xlabel('Time Points');
ylabel('Mean Signal');
legend('Mean Consistent');

% Adjust the layout
sgtitle('Time Series Analysis'); % Super title for the entire figure

fig_out = [fig_dir '/Mean_time_series_consistent_and_change_networks_Movie'];
BED_exportfig(f, fig_out, 'png',9); close
close all
%% plotting timeseries of each network that changes or stays the same
unique_networks = unique([Mdata; Cdata]);

% Consistent Data Plot
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

% Plot for overall consistent data
subplot(length(unique_networks) + 1, 1, 1);
plot(mean_consistent_M, 'b'); % Overall consistent data
title('Overall Consistent Networks');

% Loop through each unique network
for i = 1:length(unique_networks)
    network_number = unique_networks(i); % Actual network number
    consistent_network = consistent & (Cdata == network_number);
    mean_consistent_network = mean(Cdata_dt(consistent_network == 1, :), 1);

    subplot(length(unique_networks) + 1, 1, i + 1);
    plot(mean_consistent_network);
    title(['Consistent - Network ' left_labels{i}]);
    %title(['Consistent - Network ' num2str(network_number)]);
end

fig_out = [fig_dir '/Mean_time_series_consistent_across_all_networks_Movie'];
BED_exportfig(f, fig_out, 'png',9); 
close all;

% Changing Data Plot
%figure;
f = figure('Units', 'pixel', 'Position', [0 0 600 1600]);

subplot(num_networks + 1, 1, 1);
plot(mean_changes_M, 'r'); % Overall changing data
title('Overall Changing Networks');



% Loop through each unique network
for i = 1:length(unique_networks)
    network_number = unique_networks(i); % Actual network number
    changes_network = changes & (Cdata == network_number);
    mean_changes_network = mean(Cdata_dt(changes_network == 1, :), 1);

    subplot(length(unique_networks) + 1, 1, i + 1);
    plot(mean_changes_network);
    title(['Changes - Network ' left_labels{i}]);
    %title(['Consistent - Network ' num2str(network_number)]);
end


% Save the figures if needed
% saveas(...); for each figure
fig_out = [fig_dir '/Mean_time_series_that_change_across_all_networks_Movie'];
BED_exportfig(f, fig_out, 'png',9); close
close all



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
xticks(1:length(network_labels))
xticklabels(left_labels)
xlabel('Networks')
ylabel('Stability Ratio')
title('Network Stability')
rotateXLabels(gca, 45) % Optional: Rotate x labels for better visibility

% Save the figure if needed
fig_out = [fig_dir '/Network_Stability_Crosshair2movie'];
BED_exportfig(f, fig_out, 'png',9); close
close all

end
