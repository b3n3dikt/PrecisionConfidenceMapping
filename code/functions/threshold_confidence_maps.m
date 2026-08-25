function threshold_confidence_maps(FIGDIR, percent_holdout, threshold_value, make_individuals)
% threshold_confidence_maps(FIGDIR, percent_holdout, threshold_value, make_individuals)
%
% Combined all-network map + optional individual network binary maps + dlabels.
%
% Outputs per threshold T (T = sprintf('%g', threshold_value)):
%   FIGDIR/Thresholded-T/PCM_confidence_map_to_bin_all-networks_thresh-T.dscalar.nii
%   FIGDIR/Thresholded-T/PCM_confidence_map_to_bin_all-networks_thresh-T.dlabel.nii
%   FIGDIR/Thresholded-T/Individual_Networks/network-<ABBR>.dscalar.nii  (0/1)
%   FIGDIR/Thresholded-T/Individual_Networks/network-<ABBR>.dlabel.nii
%   FIGDIR/Thresholded-T/Individual_Networks/label-<ABBR>.txt
%
% Notes:
% - Strict thresholding (> threshold_value). So threshold=0 means "any nonzero probability".
% - Combined dlabel uses Gordon_labels_with_scan.txt.
% - Individual dlabels use one-label txt files with label key = 1 and correct RGBA.

    if nargin < 4 || isempty(make_individuals)
        make_individuals = true;
    end

    % -------------------------------------------------------
    % Resolve paths relative to this file's location.
    % addpath calls are handled by MATLAB_ADDPATH in config.sh.
    % wb_command is on PATH via `module load workbench`.
    % -------------------------------------------------------
    this_fn  = mfilename('fullpath');
    fn_dir   = fileparts(this_fn);           % code/functions/
    pcm_root = fileparts(fileparts(fn_dir)); % PCM_standalone/

    % Resolve wb_command via the shell PATH (module load workbench must have run).
    % exist(...,'file') only checks MATLAB's path, not the system PATH, so we
    % use 'which' instead to verify the command is actually reachable.
    [wb_status, wb_resolved] = system('which wb_command 2>/dev/null');
    if wb_status == 0
        wb_command = strtrim(wb_resolved);
    else
        wb_command = '';
    end

    gordon_txt = fullfile(pcm_root, 'template_matching', 'support_files', 'Gordon_labels_with_scan.txt');

    % Network names matching the probability map filenames produced by the TM step.
    % Indices 4, 6, 17 are unassigned networks and are excluded by network_indices.
    network_names = {'DMN','Vis','FP','','DAN','','VAN','Sal','CO','SMd','SMl','Aud','Tpole','MTL','PMN','PON','','SCAN'};

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
    % Grayordinate count: derive from data instead of assuming human 91282, so this
    % works for any species/mesh (e.g. macaque cortex-only 56522). Do a first pass
    % over network_indices to find any existing probability map and read its size;
    % every other map is expected to match it exactly.
    % -------------------------------------------------------
    n_grey = [];
    for i = network_indices
        fpath = fullfile(FIGDIR, ...
            sprintf('Probability_Maps_across_perms_TM_Percent_holdout_%s_network_probability.dscalar.nii', network_names{i}));
        if exist(fpath, 'file')
            n_grey = numel(cifti_read(fpath).cdata);
            break
        end
    end
    if isempty(n_grey)
        error('No network probability maps found in %s; cannot determine grayordinate count.', FIGDIR);
    end

    % -------------------------------------------------------
    % Matrices (grayordinates x networks)
    % -------------------------------------------------------
    probability_matrix = zeros(n_grey, 18, 'single');
    thresholded_matrix = zeros(n_grey, 18, 'single');

    % -------------------------------------------------------
    % Read and threshold per-network probability maps
    % IMPORTANT: strict thresholding so threshold=0 excludes zeros
    % -------------------------------------------------------
    clear dscalar
    for i = network_indices
        name = network_names{i};

        fpath = fullfile(FIGDIR, ...
            sprintf('Probability_Maps_across_perms_TM_Percent_holdout_%s_network_probability.dscalar.nii', name));

        if ~exist(fpath, 'file')
            warning('Missing %s (network %d). Filling zeros.', fpath, i);
            data_vec = zeros(n_grey,1,'single');
        else
            dscalar = cifti_read(fpath);
            data_vec = single(dscalar.cdata);
            if numel(data_vec) ~= n_grey
                error('Unexpected cdata length for %s: got %d, expected %d.', fpath, numel(data_vec), n_grey);
            end
        end

        probability_matrix(:,i) = data_vec;

        temp = data_vec;
        temp(temp >  threshold_value) = i;
        temp(temp <= threshold_value) = 0;
        thresholded_matrix(:,i) = temp;
    end

    % Keep only selected network columns
    thresholded_matrix = thresholded_matrix(:, network_indices);
    probability_matrix = probability_matrix(:, network_indices);

    % -------------------------------------------------------
    % Tie-break: keep highest probability at overlaps
    % -------------------------------------------------------
    for rr = 1:size(thresholded_matrix,1)
        candidates = find(thresholded_matrix(rr,:) ~= 0);
        if numel(candidates) > 1
            rawvals = probability_matrix(rr, candidates);
            [~, bestIdx] = max(rawvals);
            bestCol = candidates(bestIdx);
            thresholded_matrix(rr, setdiff(candidates, bestCol)) = 0;
        end
    end

    combined_map = sum(thresholded_matrix, 2);

    % -------------------------------------------------------
    % Output dirs
    % -------------------------------------------------------
    thresh_str = sprintf('%g', threshold_value);
    outdir = fullfile(FIGDIR, ['Thresholded-' thresh_str]);
    if ~exist(outdir, 'dir'), mkdir(outdir); end

    if ~exist('dscalar','var')
        error('No input dscalar was successfully read; cannot write outputs with correct CIFTI metadata.');
    end

    out_cifti = dscalar;

    % -------------------------------------------------------
    % Save combined map (dscalar)
    % -------------------------------------------------------
    out_cifti.cdata = combined_map;
    out_dscalar = fullfile(outdir, ['PCM_confidence_map_to_bin_all-networks_thresh-' thresh_str '.dscalar.nii']);
    ciftisave(out_cifti, out_dscalar);

    fprintf('Saved combined map: %s\n', out_dscalar);
    fprintf('Nonzero vertices: %d / %d\n', nnz(combined_map), numel(combined_map));

    % -------------------------------------------------------
    % Convert combined map to dlabel (Gordon table)
    % -------------------------------------------------------
    if ~isempty(wb_command)
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
        warning('wb_command not found on PATH (skipping combined .dlabel conversion). Is workbench module loaded?');
    end

    % -------------------------------------------------------
    % Save individual networks (binary 0/1) + dlabel (label key = 1)
    % -------------------------------------------------------
    if make_individuals
        ind_dir = fullfile(outdir, 'Individual_Networks');
        if ~exist(ind_dir, 'dir'), mkdir(ind_dir); end

        if ~exist(wb_command, 'file')
            warning('wb_command not found on PATH. Will write .txt + .dscalar but skip .dlabel conversion. Is workbench module loaded?');
            do_dlabel = false;
        else
            do_dlabel = true;
        end

        for i = network_indices
            this_abbr = abbr{i};
            label_name = network_names{i};

            % Binary per-network map: 1 where combined_map == i, else 0
            ind_map = zeros(n_grey, 1, 'single');
            ind_map(combined_map == i) = 1;

            % Save per-network dscalar
            out_cifti_i = out_cifti;
            out_cifti_i.cdata = ind_map;

            dsc_path = fullfile(ind_dir, sprintf('network-%s.dscalar.nii', this_abbr));
            ciftisave(out_cifti_i, dsc_path);

            % Write label txt with label key = 1 (not i)
            txt_path = fullfile(ind_dir, sprintf('label-%s.txt', this_abbr));
            fid = fopen(txt_path, 'w');
            if fid < 0
                error('Could not open %s for writing.', txt_path);
            end
            fprintf(fid, '%s\n', label_name);
            fprintf(fid, '%d\t%d\t%d\t%d\t%d\n', 1, rgba(i,1), rgba(i,2), rgba(i,3), rgba(i,4));
            fclose(fid);

            % Convert to dlabel
            if do_dlabel
                [~, root_name] = fileparts(dsc_path); % strips .nii only; still has ".dscalar"
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

    fprintf('Done threshold=%s for directory=%s\n', thresh_str, FIGDIR);
end