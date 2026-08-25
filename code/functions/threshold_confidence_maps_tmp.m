function threshold_confidence_maps(FIGDIR, percent_holdout, threshold_value)
    % thresholds + binarizes .dscalar probability maps in one directory
    % DOES NOT DO ANY mutual info or second directory comparison

    % -------------------------------------------------------
    % Setup paths & load network_names
    % -------------------------------------------------------
    load('/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat');
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/gifti/'));
    addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/'));
    wb_command = '/projects/standard/faird/shared/code/external/utilities/workbench/1.5.0/workbench/bin_rh_linux64/wb_command';

    % Indices of the networks you care about
    network_indices = [1,2,3,5,7:16,18];  % Adjust as needed

    % Probability & thresholded placeholders
    probability_matrix = zeros(91282, 18, 'single');
    thresholded_matrix = zeros(91282, 18, 'single');

    % -------------------------------------------------------
    % Loop networks
    % -------------------------------------------------------
    for i = network_indices
        name = network_names{i};  % e.g. 'DMN'
        % Probability map name
        fpath = fullfile(FIGDIR, ...
             sprintf('Probability_Maps_across_perms_TM_Percent_holdout_%s_network_probability.dscalar.nii', name));

        % If file missing, fill with zeros
        if ~exist(fpath, 'file')
            warning('Network "%s" not found in %s. Filling with zeros.', name, fpath);
            data_vec = zeros(91282,1,'single');
        else
            % read it
            dscalar = cifti_read(fpath);
            data_vec = dscalar.cdata;
        end

        % store raw probability
        probability_matrix(:,i) = data_vec;

        % apply threshold => if above threshold_value, keep "i", else 0
        temp = data_vec;
        temp(temp >= threshold_value) = i;
        temp(temp < threshold_value)  = 0;
        thresholded_matrix(:,i) = temp;
    end

    % keep only your network_indices columns
    thresholded_matrix = thresholded_matrix(:, network_indices);
    probability_matrix = probability_matrix(:, network_indices);

    % -------------------------------------------------------
    % tie-break step: if a vertex gets assigned >1 network,
    % keep only the one with highest probability
    % -------------------------------------------------------
    for rr = 1:size(thresholded_matrix,1)
        nonzeros = find(thresholded_matrix(rr,:) ~= 0);
        if numel(nonzeros) > 1
            rawvals = probability_matrix(rr, nonzeros);
            [~, bestIdx] = max(rawvals);
            bestNetwork = nonzeros(bestIdx);
            % set the others to zero
            thresholded_matrix(rr, setdiff(nonzeros,bestNetwork)) = 0;
        end
    end

    % -------------------------------------------------------
    % Summation => confidence map (each vertex is sum of assigned networks)
    % Actually, after the tie-break, each vertex is assigned at most one network
    % so summation is basically 0 or that network index. But well keep the code.
    % -------------------------------------------------------
    combined_map = sum(thresholded_matrix,2);

    % Create output subfolder
    thresh_str = sprintf('%g', threshold_value); % e.g. "0.5"
    outdir = fullfile(FIGDIR, ['Thresholded-' thresh_str]);
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    % Reuse the last-read dscalar just to keep a template for writing
    % If none was read, we can just create a new CIFTI struct.
    if exist('dscalar','var')
        out_cifti = dscalar;
        out_cifti.cdata = combined_map;
    else
        % If we truly had no real file, create minimal structure
        out_cifti.cdata = combined_map;
        out_cifti.diminfo{1}.length = 91282;
        out_cifti.diminfo{1}.maps = [];  % etc. for basic coverage
    end

    % Output name
    outname = fullfile(outdir, ['PCM_confidence_map_to_bin_all-networks_thresh-' thresh_str '.dscalar.nii']);
    ciftisave(out_cifti, outname);

    fprintf('Done threshold=%.2f for directory=%s\n', threshold_value, FIGDIR);
end