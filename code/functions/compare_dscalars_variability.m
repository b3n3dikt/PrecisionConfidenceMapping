function compare_dscalars_variability(dscalars_list_file, subject_ids_list_file, outfolder, minute,threshold, threshold_between)

%COMPARE_DSCALARS_VARIABILITY Compute and save variability measures from dscalar files.
%
% This function reads a list of dscalar file paths and corresponding subject IDs,
% computes within-subject and between-subject entropy measures, consensus assignments,
% and saves the results as CIFTI files and plots.
%
% Usage:
% compare_dscalars_variability('dscalars_list.txt', 'subject_ids_list.txt', '/path/to/output_folder', minute)
    % Convert string inputs to numeric
    threshold = str2double(threshold);
    threshold_between = str2double(threshold_between);

    % Check for valid numeric conversion
    if isnan(threshold) || isnan(threshold_between)
        error('Threshold values must be numeric. Check your input variables.');
    end
    % Add necessary paths
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));

    %% Read Input Files

    % Read the list of dscalar file paths
    dscalars_list = importdata(dscalars_list_file); % Cell array of file paths

    % Read the list of subject IDs
    subject_ids_list = importdata(subject_ids_list_file); % Cell array of subject IDs

    if length(dscalars_list) ~= length(subject_ids_list)
        error('The number of dscalar files and subject IDs must be the same.');
    end

    % Convert minute to string for use in filenames
    minute_str = num2str(minute);

    %% Initialize Variables and Read CIFTI Files

    num_files = length(dscalars_list);
    subject_ids = {}; % To store corresponding subject IDs

    % Read in one CIFTI file to get the template structure
    cifti_template = cifti_read(dscalars_list{1}); % Read in the first file

    % Get the number of grayordinates from the template
    num_grayordinates = size(cifti_template.cdata, 1);

    % Preallocate data_matrix for efficiency
    data_matrix = zeros(num_grayordinates, num_files);

    % Loop over each file
    for i = 1:num_files
        % Load the CIFTI file
        cifti_data = cifti_read(dscalars_list{i});

        % Extract the network assignments (assuming scalar data)
        assignments = cifti_data.cdata; % Should be a vector of size [num_grayordinates x 1]

        % Check if the number of grayordinates matches
        if size(assignments, 1) ~= num_grayordinates
            error('Mismatch in number of grayordinates between files.');
        end

        % Append to data matrix
        data_matrix(:, i) = assignments;

        % Store subject ID
        subject_ids{i} = subject_ids_list{i};
    end

    %% Organize Data by Subject

    % Find unique subjects
    unique_subjects = unique(subject_ids);

    % Create a structure to hold data for each subject
    subject_data = struct();

    for s = 1:length(unique_subjects)
        subj_id = unique_subjects{s};

        % Find indices of files belonging to this subject
        subj_indices = find(strcmp(subject_ids, subj_id));

        % Store the data
        subject_data(s).id = subj_id;
        subject_data(s).assignments = data_matrix(:, subj_indices); % [num_grayordinates x num_runs]
    end

    %% Compute Within-Subject Measures

    for s = 1:length(subject_data)
        assignments = subject_data(s).assignments;
        num_runs = size(assignments, 2);

        % Get unique network labels
        unique_networks = unique(assignments(:));
        num_networks = length(unique_networks);
        sorted_unique_networks = sort(unique_networks);

        % Initialize counts matrix
        counts = zeros(num_grayordinates, num_networks);

        % Vectorized computation of counts
        for k_idx = 1:num_networks
            network_label = sorted_unique_networks(k_idx);
            counts(:, k_idx) = sum(assignments == network_label, 2);
        end

        % Compute probabilities
        probs = counts / num_runs;
        epsilon = 1e-12;
        probs(probs == 0) = epsilon;

        % Compute entropy
        entropy_within = -sum(probs .* log2(probs), 2);
        subject_data(s).entropy_within = entropy_within;

        % Compute number of unique networks per grayordinate
        num_unique_networks = sum(counts > 0, 2);
        subject_data(s).num_unique_networks = num_unique_networks;

        % Save entropy as CIFTI
        cifti_entropy = cifti_template; % Use the template
        cifti_entropy.cdata = entropy_within;
        new_infile = fullfile(outfolder, sprintf('sub-%s_entropy_within_%smin.dscalar.nii', subject_data(s).id, minute_str));
        cifti_write(cifti_entropy, new_infile);

        % Save number of unique networks as CIFTI
        cifti_unique_networks = cifti_template;
        cifti_unique_networks.cdata = num_unique_networks;
        new_infile_unique = fullfile(outfolder, sprintf('sub-%s_num_unique_networks_%smin.dscalar.nii', subject_data(s).id, minute_str));
        cifti_write(cifti_unique_networks, new_infile_unique);

        % Saving out probabilities for each network
        for k_idx = 1:num_networks
            network_label = sorted_unique_networks(k_idx);
            probs_k = probs(:, k_idx);
            cifti_probs = cifti_template; % Use the template
            cifti_probs.cdata = probs_k;
            new_infile_probs = fullfile(outfolder, sprintf('sub-%s_probs_network_%d_%smin.dscalar.nii', subject_data(s).id, network_label, minute_str));
            cifti_write(cifti_probs, new_infile_probs);
            fprintf('Saved probability CIFTI file for network %d: %s\n', network_label, new_infile_probs);
        end

        % Compute and save consensus assignments (Mode)
        consensus_mode = mode(assignments, 2);
        subject_data(s).consensus_mode = consensus_mode;

        cifti_mode = cifti_template;
        cifti_mode.cdata = consensus_mode;
        output_filename_mode = fullfile(outfolder, sprintf('sub-%s_consensus_mode_%smin.dscalar.nii', subject_data(s).id, minute_str));
        cifti_write(cifti_mode, output_filename_mode);
        fprintf('Saved mode consensus CIFTI file for subject %s: %s\n', subject_data(s).id, output_filename_mode);

        % Compute and save consensus assignments (Maximum Probability)
        [~, max_prob_idx] = max(probs, [], 2);
        consensus_max_prob = sorted_unique_networks(max_prob_idx);
        subject_data(s).consensus_max_prob = consensus_max_prob;

        cifti_max_prob = cifti_template;
        cifti_max_prob.cdata = consensus_max_prob;
        output_filename_max_prob = fullfile(outfolder, sprintf('sub-%s_consensus_max_prob_%smin.dscalar.nii', subject_data(s).id, minute_str));
        cifti_write(cifti_max_prob, output_filename_max_prob);
        fprintf('Saved maximum likelihood consensus CIFTI file for subject %s: %s\n', subject_data(s).id, output_filename_max_prob);

        % Compute and save consensus assignments (Thresholding)
        %threshold = 0.8; % Adjust as needed
        [max_probs, max_prob_idx] = max(probs, [], 2);
        consensus_threshold = zeros(num_grayordinates, 1); % Initialize with zeros for "uncertain"
        above_threshold = max_probs >= threshold;
        consensus_threshold(above_threshold) = sorted_unique_networks(max_prob_idx(above_threshold));
        subject_data(s).consensus_threshold = consensus_threshold;

        cifti_threshold = cifti_template;
        cifti_threshold.cdata = consensus_threshold;
        output_filename_threshold = fullfile(outfolder, sprintf('sub-%s_consensus_threshold_%.0fperc_%smin.dscalar.nii', subject_data(s).id, threshold*100, minute_str));
        cifti_write(cifti_threshold, output_filename_threshold);
        fprintf('Saved thresholded consensus CIFTI file for subject %s: %s\n', subject_data(s).id, output_filename_threshold);
    end

    %% Compute Between-Subject Measures

    % Collect the consensus assignments for each subject (e.g., mode)
    num_subjects = length(subject_data);

    consensus_assignments = zeros(num_grayordinates, num_subjects);

    for s = 1:num_subjects
        % Use the consensus assignments (mode) from each subject
        consensus_assignments(:, s) = subject_data(s).consensus_mode;
    end

    % Get unique network labels across all consensus assignments
    unique_networks = unique(consensus_assignments(:));
    num_networks = length(unique_networks);
    sorted_unique_networks = sort(unique_networks);

    % Initialize counts matrix
    counts = zeros(num_grayordinates, num_networks);

    % Vectorized computation of counts across subjects
    for k_idx = 1:num_networks
        network_label = sorted_unique_networks(k_idx);
        counts(:, k_idx) = sum(consensus_assignments == network_label, 2);
    end

    % Compute probabilities
    probs = counts / num_subjects;
    epsilon = 1e-12;
    probs(probs == 0) = epsilon;

    % Compute entropy
    entropy_between = -sum(probs .* log2(probs), 2);

    % Compute number of unique networks per grayordinate
    num_unique_networks_between = sum(counts > 0, 2);

    % Save the entropy as a new CIFTI file
    cifti_entropy = cifti_template;
    cifti_entropy.cdata = entropy_between;
    output_filename = fullfile(outfolder, sprintf('entropy_between_subjects_%smin.dscalar.nii', minute_str));
    cifti_write(cifti_entropy, output_filename);
    fprintf('Saved between-subject entropy CIFTI file: %s\n', output_filename);

    % Save the number of unique networks as another CIFTI file
    cifti_unique_networks = cifti_template;
    cifti_unique_networks.cdata = num_unique_networks_between;
    output_filename_unique = fullfile(outfolder, sprintf('num_unique_networks_between_subjects_%smin.dscalar.nii', minute_str));
    cifti_write(cifti_unique_networks, output_filename_unique);
    fprintf('Saved between-subject unique networks CIFTI file: %s\n', output_filename_unique);

    % Compute and save consensus assignments across subjects (Mode)
    consensus_mode_between = mode(consensus_assignments, 2);

    cifti_mode_between = cifti_template;
    cifti_mode_between.cdata = consensus_mode_between;
    output_filename_mode_between = fullfile(outfolder, sprintf('consensus_mode_between_subjects_%smin.dscalar.nii', minute_str));
    cifti_write(cifti_mode_between, output_filename_mode_between);
    fprintf('Saved mode consensus CIFTI file across subjects: %s\n', output_filename_mode_between);

    % Compute and save consensus assignments across subjects (Maximum Probability)
    [~, max_prob_idx_between] = max(probs, [], 2);
    consensus_max_prob_between = sorted_unique_networks(max_prob_idx_between);

    cifti_max_prob_between = cifti_template;
    cifti_max_prob_between.cdata = consensus_max_prob_between;
    output_filename_max_prob_between = fullfile(outfolder, sprintf('consensus_max_prob_between_subjects_%smin.dscalar.nii', minute_str));
    cifti_write(cifti_max_prob_between, output_filename_max_prob_between);
    fprintf('Saved maximum likelihood consensus CIFTI file across subjects: %s\n', output_filename_max_prob_between);

    % Compute and save consensus assignments across subjects (Thresholding)
    %threshold_between = 0.6; % Adjust as needed
    [max_probs_between, max_prob_idx_between] = max(probs, [], 2);
    consensus_threshold_between = zeros(num_grayordinates, 1); % Initialize with zeros for "uncertain"
    above_threshold_between = max_probs_between >= threshold_between;
    consensus_threshold_between(above_threshold_between) = sorted_unique_networks(max_prob_idx_between(above_threshold_between));

    cifti_threshold_between = cifti_template;
    cifti_threshold_between.cdata = consensus_threshold_between;
    output_filename_threshold_between = fullfile(outfolder, sprintf('consensus_threshold_%.0fperc_between_subjects_%smin.dscalar.nii', threshold_between*100, minute_str));
    cifti_write(cifti_threshold_between, output_filename_threshold_between);
    fprintf('Saved thresholded consensus CIFTI file across subjects: %s\n', output_filename_threshold_between);

    %% Generate Plots

    % Create figures folder if it doesn't exist
    figures_folder = fullfile(outfolder, 'figures');
    if ~exist(figures_folder, 'dir')
        mkdir(figures_folder);
    end

    % Within-subject entropy plots
    for s = 1:num_subjects
        entropy_within = subject_data(s).entropy_within;
        num_unique_networks = subject_data(s).num_unique_networks;

        % Entropy histogram
        figure;
        histogram(entropy_within, 'BinWidth', 0.1);
        title(sprintf('Within-Subject Entropy Distribution for Subject %s (%s min)', subject_data(s).id, minute_str), 'Interpreter', 'none');
        xlabel('Entropy');
        ylabel('Number of Grayordinates');
        figure_filename = fullfile(figures_folder, sprintf('subject_%s_entropy_within_histogram_%smin.png', subject_data(s).id, minute_str));
        saveas(gcf, figure_filename);
        close(gcf);

        % Unique networks histogram
        figure;
        histogram(num_unique_networks, 'BinWidth', 1);
        title(sprintf('Within-Subject Number of Unique Networks for Subject %s (%s min)', subject_data(s).id, minute_str), 'Interpreter', 'none');
        xlabel('Number of Unique Networks');
        ylabel('Number of Grayordinates');
        figure_filename_unique = fullfile(figures_folder, sprintf('subject_%s_unique_networks_histogram_%smin.png', subject_data(s).id, minute_str));
        saveas(gcf, figure_filename_unique);
        close(gcf);
    end

    % Between-subject entropy plot
    figure;
    histogram(entropy_between, 'BinWidth', 0.1);
    title(sprintf('Between-Subject Entropy Distribution (%s min)', minute_str));
    xlabel('Entropy');
    ylabel('Number of Grayordinates');
    figure_filename_between = fullfile(figures_folder, sprintf('entropy_between_histogram_%smin.png', minute_str));
    saveas(gcf, figure_filename_between);
    close(gcf);

    % Between-subject unique networks plot
    figure;
    histogram(num_unique_networks_between, 'BinWidth', 1);
    title(sprintf('Between-Subject Number of Unique Networks (%s min)', minute_str));
    xlabel('Number of Unique Networks');
    ylabel('Number of Grayordinates');
    figure_filename_unique_between = fullfile(figures_folder, sprintf('unique_networks_between_histogram_%smin.png', minute_str));
    saveas(gcf, figure_filename_unique_between);
    close(gcf);

    fprintf('All computations and plots are completed for %s minutes.\n', minute_str);
end