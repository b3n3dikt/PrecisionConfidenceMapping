function threshold_confidence_maps_priority_and_individuals(FIGDIR, threshold_value, make_individuals, priority)
% threshold_confidence_maps_priority_and_individuals(FIGDIR, threshold_value, make_individuals, priority)
%
% Combined all-network map + optional individual network binary maps + dlabels,
% with optional PRIORITY tie-break.
%
% - If PRIORITY is empty or [], ties break by max probability (default).
% - If PRIORITY is provided, and multiple networks pass threshold at a vertex,
%   the earliest network in PRIORITY that is present WINS (even if lower probability).
%
% Output folder:
%   - No priority:   FIGDIR/Thresholded-<T>/
%   - With priority: FIGDIR/Thresholded-<T>_<TAG>_priority/
%
% Where T = sprintf('%g', threshold_value) and TAG is derived from priority.

    if nargin < 3 || isempty(make_individuals)
        make_individuals = true;
    end
    if nargin < 4
        priority = [];
    end

    % -------------------------------------------------------
    % Setup paths & load network_names
    % -------------------------------------------------------
    load('/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat');
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
    addpath(genpath('/projects/standard/faird/shared/code/external/utilities/gifti/'));
    addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/'));

    wb_command = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64/wb_command';
    gordon_txt = '/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/Gordon_labels_with_scan.txt';

    % -------------------------------------------------------
    % Networks you care about
    % -------------------------------------------------------
    network_indices = [1,2,3,5,7:16,18];

    % -------------------------------------------------------
    % Abbreviations for filenames (network ID -> short name)
    % -------------------------------------------------------
    abbr = cell(1,18);
    abbr{1}  = 'DMN';
    abbr{2}  = 'VIS';
    abbr{3}  = 'FPN';
    abbr{4}  = 'UN4';
    abbr{5}  = 'DAN';
    abbr{6}  = 'UN6';
    abbr{7}  = 'VAN';
    abbr{8}  = 'SAL';
    abbr{9}  = 'CO';
    abbr{10} = 'SMD';
    abbr{11} = 'SML';
    abbr{12} = 'AUD';
    abbr{13} = 'TP';
    abbr{14} = 'MTL';
    abbr{15} = 'PMN';
    abbr{16} = 'PO';
    abbr{17} = 'UN17';
    abbr{18} = 'SCAN';
    for ii = 1:18
        if isempty(abbr{ii})
            abbr{ii} = sprintf('NET%d', ii);
        end
    end

    % -------------------------------------------------------
    % RGBA (your table)
    % -------------------------------------------------------
    rgba = zeros(18,4);
    rgba(1,:)  = [255 0   0   255];
    rgba(2,:)  = [0   0   140 255];
    rgba(3,:)  = [253 253 0   255];
    rgba(4,:)  = [63  63  63  255];
    rgba(5,:)  = [1   203 1   255];
    rgba(6,:)  = [63  63  63  255];
    rgba(7,:)  = [0   153 153 255];
    rgba(8,:)  = [0   0   0   255];
    rgba(9,:)  = [75  0   152 255];
    rgba(10,:) = [52  254 253 255];
    rgba(11,:) = [254 126 1   255];
    rgba(12,:) = [152 51  254 255];
    rgba(13,:) = [0   51  102 255];
    rgba(14,:) = [50  254 51  255];
    rgba(15,:) = [0   1   253 255];
    rgba(16,:) = [253 253 202 255];
    rgba(17,:) = [63  63  63  255];
    rgba(18,:) = [143 0   105 255];

    % -------------------------------------------------------
    % Determine output folder name
    % -------------------------------------------------------
    thresh_str = sprintf('%g', threshold_value);
    ptag = make_priority_tag(priority, network_names, abbr);

    if isempty(ptag)
        outdir = fullfile(FIGDIR, ['Thresholded-' thresh_str]);
    else
        outdir = fullfile(FIGDIR, sprintf('Thresholded-%s_%s_priority', thresh_str, ptag));
    end
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    % -------------------------------------------------------
    % Matrices
    % -------------------------------------------------------
    probability_matrix = zeros(91282, 18, 'single');
    thresholded_matrix = zeros(91282, 18, 'single');

    % -------------------------------------------------------
    % Read + strict threshold
    % IMPORTANT: strict thresholding so threshold=0 excludes zeros
    % -------------------------------------------------------
    clear dscalar
    for i = network_indices
        name = network_names{i};

        fpath = fullfile(FIGDIR, ...
            sprintf('Probability_Maps_across_perms_TM_Percent_holdout_%s_network_probability.dscalar.nii', name));

        if ~exist(fpath, 'file')
            warning('Missing %s (network %d). Filling zeros.', fpath, i);
            data_vec = zeros(91282,1,'single');
        else
            dscalar = cifti_read(fpath);
            data_vec = single(dscalar.cdata);
            if numel(data_vec) ~= 91282
                error('Unexpected cdata length for %s: got %d, expected 91282.', fpath, numel(data_vec));
            end
        end

        probability_matrix(:,i) = data_vec;

        temp = data_vec;
        temp(temp >  threshold_value) = i;
        temp(temp <= threshold_value) = 0;
        thresholded_matrix(:,i) = temp;
    end

    % subset to requested networks
    thresholded_matrix = thresholded_matrix(:, network_indices);
    probability_matrix = probability_matrix(:, network_indices);

    % -------------------------------------------------------
    % PRIORITY SETUP (map priority -> subset columns)
    % -------------------------------------------------------
    priority_cols = map_priority_to_subset_cols(priority, network_names, network_indices);

    % -------------------------------------------------------
    % Tie-break: priority if present among candidates, else max probability
    % -------------------------------------------------------
    for rr = 1:size(thresholded_matrix,1)
        candidates = find(thresholded_matrix(rr,:) ~= 0);
        if numel(candidates) > 1
            bestCol = [];

            if ~isempty(priority_cols)
                hit = candidates(ismember(candidates, priority_cols));
                if ~isempty(hit)
                    pos = arrayfun(@(c) find(priority_cols == c, 1), hit);
                    [~, minpos] = min(pos);
                    bestCol = hit(minpos);

                    if thresholded_matrix(rr, bestCol) == 0
                        bestCol = [];
                    end
                end
            end

            if isempty(bestCol)
                rawvals = probability_matrix(rr, candidates);
                [~, bestIdx] = max(rawvals);
                bestCol = candidates(bestIdx);
            end

            thresholded_matrix(rr, setdiff(candidates, bestCol)) = 0;
        end
    end

    combined_map = sum(thresholded_matrix, 2);

    % -------------------------------------------------------
    % Save combined dscalar
    % -------------------------------------------------------
    if ~exist('dscalar', 'var')
        error('No input dscalar was successfully read; cannot write outputs with correct CIFTI metadata.');
    end

    out_cifti = dscalar;
    out_cifti.cdata = combined_map;

    out_dscalar = fullfile(outdir, ['PCM_confidence_map_to_bin_all-networks_thresh-' thresh_str '.dscalar.nii']);
    ciftisave(out_cifti, out_dscalar);

    fprintf('Saved combined map: %s\n', out_dscalar);
    fprintf('Nonzero vertices: %d / %d\n', nnz(combined_map), numel(combined_map));

    % -------------------------------------------------------
    % Convert combined dscalar -> dlabel (Gordon table)
    % -------------------------------------------------------
    if exist(wb_command, 'file')
        out_dlabel = fullfile(outdir, ['PCM_confidence_map_to_bin_all-networks_thresh-' thresh_str '.dlabel.nii']);
        cmd = sprintf('"%s" -cifti-label-import "%s" "%s" "%s"', ...
                      wb_command, out_dscalar, gordon_txt, out_dlabel);
        [status, outmsg] = system(cmd);
        if status ~= 0
            warning('wb_command failed for COMBINED map\nCMD:\n%s\nOUTPUT:\n%s', cmd, outmsg);
        else
            fprintf('Saved combined dlabel: %s\n', out_dlabel);
        end
    else
        warning('wb_command not found at: %s (skipping combined .dlabel conversion)', wb_command);
    end

    % -------------------------------------------------------
    % Individual networks (0/1 ds scalars + per-network dlabels)
    % -------------------------------------------------------
    if make_individuals
        ind_dir = fullfile(outdir, 'Individual_Networks');
        if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

        do_dlabel = exist(wb_command, 'file') ~= 0;
        if ~do_dlabel
            warning('wb_command not found at: %s; skipping individual .dlabel conversion.', wb_command);
        end

        for i = network_indices
            this_abbr = abbr{i};
            label_name = network_names{i};

            ind_map = zeros(91282, 1, 'single');
            ind_map(combined_map == i) = 1;

            out_cifti_i = out_cifti;
            out_cifti_i.cdata = ind_map;

            dsc_path = fullfile(ind_dir, sprintf('network-%s.dscalar.nii', this_abbr));
            ciftisave(out_cifti_i, dsc_path);

            txt_path = fullfile(ind_dir, sprintf('label-%s.txt', this_abbr));
            fid = fopen(txt_path, 'w');
            if fid < 0
                error('Could not open %s for writing.', txt_path);
            end
            fprintf(fid, '%s\n', label_name);
            fprintf(fid, '%d\t%d\t%d\t%d\t%d\n', 1, rgba(i,1), rgba(i,2), rgba(i,3), rgba(i,4));
            fclose(fid);

            if do_dlabel
                [~, root_name] = fileparts(dsc_path);
                if endsWith(root_name, '.dscalar')
                    root_name = extractBefore(root_name, '.dscalar');
                end
                dlabel_path = fullfile(ind_dir, sprintf('%s.dlabel.nii', root_name));

                cmd = sprintf('"%s" -cifti-label-import "%s" "%s" "%s"', ...
                              wb_command, dsc_path, txt_path, dlabel_path);
                [status, outmsg] = system(cmd);
                if status ~= 0
                    warning('wb_command failed for %s\nCMD:\n%s\nOUTPUT:\n%s', dsc_path, cmd, outmsg);
                end
            end
        end

        fprintf('Saved individual networks in: %s\n', ind_dir);
    end

    fprintf('Done threshold=%s directory=%s priority_tag=%s\n', thresh_str, FIGDIR, ternary(isempty(ptag),'none',ptag));
end

% ========================= Helper functions =========================

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function ptag = make_priority_tag(priority, network_names, abbr)
    % Create short readable tag for folder name
    ptag = '';

    if isempty(priority)
        return
    end
    if ischar(priority) || isstring(priority)
        priority = cellstr(priority);
    end

    if isnumeric(priority)
        ids = priority(:)';
        parts = arrayfun(@(x) sprintf('%s', num_or_abbr(x, abbr)), ids, 'UniformOutput', false);
        ptag = strjoin(parts, '-');
        ptag = sanitize_tag(ptag);
        return
    end

    if iscell(priority)
        % If names, keep the provided names but sanitize
        parts = cellfun(@(s) sanitize_tag(char(s)), priority, 'UniformOutput', false);
        ptag = strjoin(parts, '-');
        ptag = sanitize_tag(ptag);
        return
    end
end

function s = num_or_abbr(id, abbr)
    if id >= 1 && id <= numel(abbr) && ~isempty(abbr{id})
        s = abbr{id};
    else
        s = sprintf('%d', id);
    end
end

function tag = sanitize_tag(tag)
    % Keep folder-name friendly characters
    tag = regexprep(tag, '[^A-Za-z0-9\-]+', '');
    if isempty(tag)
        tag = 'priority';
    end
end

function priority_cols = map_priority_to_subset_cols(priority, network_names, network_indices)
    % Returns subset-column indices (1..numel(network_indices))
    priority_cols = [];

    if isempty(priority)
        return
    end

    if ischar(priority) || isstring(priority)
        priority = cellstr(priority);
    end

    if isnumeric(priority)
        [tf, loc] = ismember(priority(:)', network_indices);
        priority_cols = loc(tf);
        priority_cols = unique(priority_cols, 'stable');
        return
    end

    if iscell(priority)
        ids = zeros(1, numel(priority));
        for k = 1:numel(priority)
            idx = find(strcmpi(priority{k}, network_names), 1);
            if isempty(idx)
                error('Priority name "%s" not found in network_names.', priority{k});
            end
            ids(k) = idx;
        end
        [tf, loc] = ismember(ids, network_indices);
        priority_cols = loc(tf);
        priority_cols = unique(priority_cols, 'stable');
        return
    end

    error('priority must be numeric IDs, a string/char, or a cell array of strings.');
end