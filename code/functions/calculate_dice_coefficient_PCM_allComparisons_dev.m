function calculate_dice_coefficient_PCM_allComparisons_dev( ...
    BASEDIR, ...
    dscalarswithassignments1, ...  % .conc file listing dscalars (ExpData)
    dscalarswithassignments2, ...  % .conc file listing dscalars (RefData)
    minutecomparisons1, ...        % .conc file listing minute labels for each dscalar in list1
    minutecomparisons2, ...        % .conc file listing minute labels for each dscalar in list2
    network_name, ...
    ConfMap, ...
    threshold, ...
    thresholdTarget, ...
    fig_dir, ...
    zeroOption, ...
    skipIfExists, ...              % optional boolean
    subjectID, ...                 % optional string (for CSV output)
    saveCSV, ...                   % optional boolean: whether to save a single CSV
    saveTXT, ...                   % optional boolean: whether to save the .txt files
    doWhole, ...                   % new boolean: compute whole-brain metrics?
    doCortical, ...                % new boolean: compute cortical metrics?
    doSubcortical, ...                % new boolean: compute subcortical metrics?
    metricsStr, ...
    outCSVbasename )
%
% -------------------------------------------------------------------------
% Example usage:
%  calculate_dice_coefficient_PCM_allComparisons_dev( ...
%      '/some/baseDir', ...
%      'myExpDScalars.conc', ...
%      'myRefDScalars.conc', ...
%      'myExpMinutes.conc', ...
%      'myRefMinutes.conc', ...
%      'MyNetwork', ...           % network_name
%      0, ...                     % ConfMap=0 => multi-network
%      5, ...                     % threshold
%      'both', ...                % thresholdTarget
%      '/path/to/figs', ...       % fig_dir
%      2, ...                     % zeroOption
%      false, ...                 % skipIfExists
%      'subj123', ...             % subjectID
%      true, ...                  % saveCSV
%      false, ...                 % saveTXT
%      true, ...                  % doWhole
%      false, ...                 % doCortical
%      false );                   % doSubcortical
%
% This call would only compute WHOLE-BRAIN metrics (no cortical/subcort),
% which can be considerably faster if you only need whole-brain results.
% 1) default missing arguments
if nargin < 12 || isempty(skipIfExists)
    skipIfExists = false;
end
if nargin < 13 || isempty(subjectID)
    subjectID = 'UnknownSubj';
end
if nargin < 14 || isempty(saveCSV)
    saveCSV = true;
end
if nargin < 15 || isempty(saveTXT)
    saveTXT = false;
end
if nargin < 16 || isempty(doWhole)
    doWhole = true;
end
if nargin < 17 || isempty(doCortical)
    doCortical = true;
end
if nargin < 18 || isempty(doSubcortical)
    doSubcortical = true;
end
if nargin < 19 || isempty(metricsStr)
    metricsStr = 'all';  % or however you handle it
end
if nargin < 20 || isempty(outCSVbasename)
    outCSVbasename = ''; % means use the old default naming
end


% Add needed paths (customize for your environment)
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'));

% Output directory
network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
if ~exist(network_folder, 'dir'), mkdir(network_folder); end

% Info about zeroOption
switch zeroOption
    case 1, disp('Zero handling: NO ACTION (zeros remain).');
    case 2, disp('Zero handling: REMOVING zeros before partition_distance.');
    case 3, disp('Zero handling: RELABELING zeros -> maxVal+1 before partition_distance.');
    otherwise, error('zeroOption must be 1, 2, or 3.');
end

if ConfMap
    disp("Hard code warning: running ConfMap (2-network binarization).");
else
    disp("Hard code warning: running multi-network code (~15 networks).");
end

% 2) Read .conc lists
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

minute_list1  = importdata(minutecomparisons1);
minute_list2  = importdata(minutecomparisons2);

if length(dscalar_list1) ~= length(minute_list1)
    error('dscalar_list1 and minute_list1 must have the same number of lines.');
end
if length(dscalar_list2) ~= length(minute_list2)
    error('dscalar_list2 and minute_list2 must have the same number of lines.');
end

% Brainstructures
corticalROIs = {'CORTEX_LEFT','CORTEX_RIGHT'};
subcorticalROIs = {'ACCUMBENS_LEFT','ACCUMBENS_RIGHT','AMYGDALA_LEFT','AMYGDALA_RIGHT','BRAIN_STEM',...
    'CAUDATE_LEFT','CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT','DIENCEPHALON_VENTRAL_RIGHT',...
    'CEREBELLUM_LEFT','CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT','HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT',...
    'PALLIDUM_RIGHT','PUTAMEN_LEFT','PUTAMEN_RIGHT','THALAMUS_LEFT','THALAMUS_RIGHT'};

% Prepare to build CSV rows
masterCSV = {};

% 3) NESTED LOOPS: all pairs (i, j)
for i = 1:length(dscalar_list1)
    for j = 1:length(dscalar_list2)

        minutes_i = minute_list1(i);
        minutes_j = minute_list2(j);

        % skipIfExists check
        if skipIfExists
            out_label = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);
            test_folder = fullfile(network_folder, 'DC_whole');
            test_file   = fullfile(test_folder, ['DC_whole_' out_label]);
            if exist(test_file, 'file')
                fprintf('Skipping pair %d vs %d because output already exists.\n',...
                        minutes_i, minutes_j);
                continue;
            end
        end

        % ---- Load the dscalars
        Mdscalar = cifti_read(dscalar_list1{i});
        Mdata    = Mdscalar.cdata;
        Cdscalar = cifti_read(dscalar_list2{j});
        Cdata    = Cdscalar.cdata;

        % Build masks
        cortical_mask    = create_region_mask(Mdscalar, corticalROIs);
        subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);

        % Apply threshold
        switch lower(thresholdTarget)
            case 'both'
                Mdata(Mdata < threshold) = 0;
                Cdata(Cdata < threshold) = 0;
            case 'dscalar1'
                Mdata(Mdata < threshold) = 0;
            case 'dscalar2'
                Cdata(Cdata < threshold) = 0;
            otherwise
                error('Invalid thresholdTarget (must be both/dscalar1/dscalar2).');
        end
        % --- NEW: Option to save zero-masked CIFTIs ---
        % --- NEW: Option to save zero-masked CIFTIs with full structure ---
        save_nonzero_cifti = true;  % Hard-coded option (set to true to enable saving)

        if save_nonzero_cifti
            % For saving, we want to keep the full cifti dimension.
            % Create a mask that is true only where both Mdata and Cdata are nonzero.
            full_mask = (Mdata ~= 0) & (Cdata ~= 0);
            
            % Create full-length arrays (same dimensions as the original thresholded data)
            Mdata_full = zeros(size(Mdata));
            Cdata_full = zeros(size(Cdata));
            
            % Copy values only in positions where both data arrays are nonzero.
            Mdata_full(full_mask) = Mdata(full_mask);
            Cdata_full(full_mask) = Cdata(full_mask);
            
            % Construct filenames using subjectID, exp minute, ref minute and threshold.
            exp_min = minutes_i;
            ref_min = minutes_j;
            filename_exp = fullfile(network_folder, sprintf('%s_Zero_masked_networks_%d_%d_%g_exp.dscalar.nii', subjectID, exp_min, ref_min, threshold));
            filename_ref = fullfile(network_folder, sprintf('%s_Zero_masked_networks_%d_%d_%g_ref.dscalar.nii', subjectID, exp_min, ref_min, threshold));
            
            % Create new CIFTI structures (reuse header info from original Mdscalar and Cdscalar)
            Mdscalar_zero = Mdscalar;
            Mdscalar_zero.cdata = Mdata_full;
            Cdscalar_zero = Cdscalar;
            Cdscalar_zero.cdata = Cdata_full;
            
            % Remove metadata (or problematic fields) to avoid concatenation issues.
            if isfield(Mdscalar_zero, 'metadata')
                Mdscalar_zero.metadata = [];
            end
            if isfield(Cdscalar_zero, 'metadata')
                Cdscalar_zero.metadata = [];
            end

            % Save the CIFTI files (assuming cifti_write is available on your MATLAB path)
            ciftisave(Mdscalar_zero, filename_exp);
            ciftisave(Cdscalar_zero, filename_ref);
            
            fprintf('Saved zero-masked CIFTI files:\n%s\n%s\n', filename_exp, filename_ref);
        end

        % Initialize (so we don't accidentally reuse old values if doWhole= false)
        DC_whole_val=[];   cDC_whole_val=[];
        TP_whole_val=[];   TN_whole_val=[]; FP_whole_val=[]; FN_whole_val=[];
        PPV_whole_val=[];  PPVcorr_Jeffreys_val=[]; PPVcorr_d1d2_val=[]; PPVcorr_bayes_val=[];
        NPV_whole_val=[];  TPR_whole_val=[]; TNR_whole_val=[]; FPR_whole_val=[]; FNR_whole_val=[];
        MCC_whole_val=[];  muI_whole_val=[]; VIn_whole_val=[]; MIn_whole_val=[];

        DC_cort_val=[];    cDC_cort_val=[];
        TP_cort_val=[];    TN_cort_val=[]; FP_cort_val=[]; FN_cort_val=[];
        PPV_cort_val=[];   PPVcorr_Jeffreys_cort_val=[]; PPVcorr_d1d2_cort_val=[]; PPVcorr_bayes_cort_val=[];
        NPV_cort_val=[];   TPR_cort_val=[]; TNR_cort_val=[]; FPR_cort_val=[]; FNR_cort_val=[];
        MCC_cort_val=[];   muI_cort_val=[]; VIn_cort_val=[]; MIn_cort_val=[];

        DC_sub_val=[];     cDC_sub_val=[];
        TP_sub_val=[];     TN_sub_val=[]; FP_sub_val=[]; FN_sub_val=[];
        PPV_sub_val=[];    PPVcorr_Jeffreys_sub_val=[]; PPVcorr_d1d2_sub_val=[]; PPVcorr_bayes_sub_val=[];
        NPV_sub_val=[];    TPR_sub_val=[]; TNR_sub_val=[]; FPR_sub_val=[]; FNR_sub_val=[];
        MCC_sub_val=[];    muI_sub_val=[]; VIn_sub_val=[]; MIn_sub_val=[];

        % ========== WHOLE-BRAIN ==========
        if doWhole
            if ConfMap
                [DC_whole_val, cDC_whole_val, ...
                 TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
                 PPV_whole_val, PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
                 NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
                 FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
                 muI_whole_val, VIn_whole_val, MIn_whole_val] ...
                     = compute_confmap_stats(Mdata, Cdata, zeroOption);
            else
                [DC_whole_val, cDC_whole_val, ...
                 TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
                 PPV_whole_val, PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
                 NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
                 FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
                 muI_whole_val, VIn_whole_val, MIn_whole_val] ...
                     = compute_network_stats(Mdata, Cdata, zeroOption);
            end
        end

        % ========== CORTICAL ==========
        if doCortical
            idxCort = (cortical_mask == 1);
            Mdata_cort = Mdata(idxCort);
            Cdata_cort = Cdata(idxCort);

            [DC_cort_val, cDC_cort_val, ...
             TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
             PPV_cort_val, PPVcorr_Jeffreys_cort_val, PPVcorr_d1d2_cort_val, PPVcorr_bayes_cort_val, ...
             NPV_cort_val, TPR_cort_val, TNR_cort_val, FPR_cort_val, FNR_cort_val, MCC_cort_val, ...
             muI_cort_val, VIn_cort_val, MIn_cort_val] ...
                 = compute_network_stats(Mdata_cort, Cdata_cort, zeroOption);
        end

        % ========== SUBCORTICAL ==========
        if doSubcortical
            idxSub = (subcortical_mask == 1);
            Mdata_sub = Mdata(idxSub);
            Cdata_sub = Cdata(idxSub);

            [DC_sub_val, cDC_sub_val, ...
             TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
             PPV_sub_val, PPVcorr_Jeffreys_sub_val, PPVcorr_d1d2_sub_val, PPVcorr_bayes_sub_val, ...
             NPV_sub_val, TPR_sub_val, TNR_sub_val, FPR_sub_val, FNR_sub_val, MCC_sub_val, ...
             muI_sub_val, VIn_sub_val, MIn_sub_val] ...
                 = compute_network_stats(Mdata_sub, Cdata_sub, zeroOption);
        end

        % ------------------- SAVE RESULTS -------------------
        label_forTXT = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);

        % (A) .txt subfolders if saveTXT==true
        if saveTXT
            save_measures_to_disk(network_folder, ...
                minutes_i, minutes_j, ...
                DC_whole_val,    cDC_whole_val, ...
                DC_cort_val,     cDC_cort_val, ...
                DC_sub_val,      cDC_sub_val, ...
                TP_whole_val,    TN_whole_val,  FP_whole_val,  FN_whole_val, ...
                TP_cort_val,     TN_cort_val,   FP_cort_val,   FN_cort_val, ...
                TP_sub_val,      TN_sub_val,    FP_sub_val,    FN_sub_val, ...
                PPV_whole_val,   PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
                NPV_whole_val,   TPR_whole_val,  TNR_whole_val, FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
                PPV_cort_val,    PPVcorr_Jeffreys_cort_val, PPVcorr_d1d2_cort_val, PPVcorr_bayes_cort_val, ...
                NPV_cort_val,    TPR_cort_val,   TNR_cort_val, FPR_cort_val, FNR_cort_val, MCC_cort_val, ...
                PPV_sub_val,     PPVcorr_Jeffreys_sub_val, PPVcorr_d1d2_sub_val, PPVcorr_bayes_sub_val, ...
                NPV_sub_val,     TPR_sub_val,    TNR_sub_val,  FPR_sub_val, FNR_sub_val, MCC_sub_val, ...
                muI_whole_val,   VIn_whole_val,  MIn_whole_val, ...
                muI_cort_val,    VIn_cort_val,   MIn_cort_val, ...
                muI_sub_val,     VIn_sub_val,    MIn_sub_val);
        end

        % (B) Build CSV rows if saveCSV==true
        if saveCSV
            if ConfMap
                % Single scalar stats => skip or do partial
                % (If you want to incorporate doWhole/doCortical/doSubcortical logic here, you can.)
                % Example: only store doWhole if doWhole is true, etc.
                if doWhole && ~isempty(DC_whole_val)
                    netLabel = 'ConfMap';
                    measureList = {
                        'DC_whole', DC_whole_val;
                        'cDC_whole', cDC_whole_val;
                        'TP_whole', TP_whole_val;
                        'TN_whole', TN_whole_val;
                        % etc...
                    };
                    for mm = 1:size(measureList,1)
                        mName  = measureList{mm,1};
                        mValue = measureList{mm,2};
                        if ~isempty(mValue)
                            newRow = {
                                subjectID, threshold, mName, netLabel, ...
                                minutes_i, minutes_j, mValue
                            };
                            masterCSV = [masterCSV; newRow]; %#ok<AGROW>
                        end
                    end
                end
                % If doCortical, doSubcortical is relevant, add them similarly.
            else
                % Multi-network approach => measureList is bigger
                % Only fill the arrays for the region if doWhole/doCortical/doSubcortical is true
                measureList = {
                    % ---- Whole ----
                    'DC_whole', DC_whole_val;
                    'cDC_whole', cDC_whole_val;
                    'TP_whole', TP_whole_val;
                    'TN_whole', TN_whole_val;
                    'FP_whole', FP_whole_val;
                    'FN_whole', FN_whole_val;
                    'TPR_whole', TPR_whole_val;
                    'TNR_whole', TNR_whole_val;
                    'FPR_whole', FPR_whole_val;
                    'FNR_whole', FNR_whole_val;
                    'NPV_whole', NPV_whole_val;
                    'PPV_whole', PPV_whole_val;
                    'PPVcorr_Jeffreys_whole', PPVcorr_Jeffreys_val;
                    'PPVcorr_d1d2_whole',     PPVcorr_d1d2_val;
                    'PPVcorr_bayes_whole',   PPVcorr_bayes_val;
                    'MCC_whole', MCC_whole_val;
                    'muI_whole', muI_whole_val;
                    'VIn_whole', VIn_whole_val;
                    'MIn_whole', MIn_whole_val;

                    % ---- Cortical ----
                    'DC_cort', DC_cort_val;
                    'cDC_cort', cDC_cort_val;
                    'TP_cort', TP_cort_val;
                    'TN_cort', TN_cort_val;
                    'FP_cort', FP_cort_val;
                    'FN_cort', FN_cort_val;
                    'TPR_cort', TPR_cort_val;
                    'TNR_cort', TNR_cort_val;
                    'FPR_cort', FPR_cort_val;
                    'FNR_cort', FNR_cort_val;
                    'NPV_cort', NPV_cort_val;
                    'PPV_cort', PPV_cort_val;
                    'PPVcorr_Jeffreys_cort', PPVcorr_Jeffreys_cort_val;
                    'PPVcorr_d1d2_cort', PPVcorr_d1d2_cort_val;
                    'PPVcorr_bayes_cort', PPVcorr_bayes_cort_val;
                    'MCC_cort', MCC_cort_val;
                    'muI_cort', muI_cort_val;
                    'VIn_cort', VIn_cort_val;
                    'MIn_cort', MIn_cort_val;

                    % ---- Subcortical ----
                    'DC_sub', DC_sub_val;
                    'cDC_sub', cDC_sub_val;
                    'TP_sub', TP_sub_val;
                    'TN_sub', TN_sub_val;
                    'FP_sub', FP_sub_val;
                    'FN_sub', FN_sub_val;
                    'TPR_sub', TPR_sub_val;
                    'TNR_sub', TNR_sub_val;
                    'FPR_sub', FPR_sub_val;
                    'FNR_sub', FNR_sub_val;
                    'NPV_sub', NPV_sub_val;
                    'PPV_sub', PPV_sub_val;
                    'PPVcorr_Jeffreys_sub', PPVcorr_Jeffreys_sub_val;
                    'PPVcorr_d1d2_sub', PPVcorr_d1d2_sub_val;
                    'PPVcorr_bayes_sub', PPVcorr_bayes_sub_val;
                    'MCC_sub', MCC_sub_val;
                    'muI_sub', muI_sub_val;
                    'VIn_sub', VIn_sub_val;
                    'MIn_sub', MIn_sub_val
                };

                fixed_labels = [1,2,3,5,7,8,9,10,11,12,13,14,15,16,18];
                label_names  = {'DMN','Vis','FP','DAN','VAN','Sal','CO','SMd','SMl','Aud','Tpole','MTL','PMN','PON','SCAN'};
                if length(label_names) ~= length(fixed_labels)
                    error('label_names vs fixed_labels mismatch in length!');
                end

                for mm = 1:size(measureList,1)
                    metricName = measureList{mm,1};
                    metricVals = measureList{mm,2};  % could be length=15 or empty

                    if isempty(metricVals)
                        % This measure wasn't computed => skip
                        continue;
                    end

                    % Some are single scalar (like muI_whole if partition_distance is a single val).
                    % If it's length>1, we assume multi-network vector:
                    if length(metricVals) > 1
                        for netIdx = 1:length(fixed_labels)
                            netLabel = label_names{netIdx};
                            val = metricVals(netIdx);
                            newRow = {
                                subjectID, threshold, metricName, netLabel, ...
                                minutes_i, minutes_j, val
                            };
                            masterCSV = [masterCSV; newRow]; %#ok<AGROW>
                        end
                    elseif length(metricVals) == 1
                        % Single-scalar measure
                        netLabel = 'WholeBrainOrSingleVal'; 
                        % or you can parse 'whole', 'cort', 'sub' from metricName if you like
                        val = metricVals(1);
                        newRow = {
                            subjectID, threshold, metricName, netLabel, ...
                            minutes_i, minutes_j, val
                        };
                        masterCSV = [masterCSV; newRow]; %#ok<AGROW>
                    else
                        % length=0 => skip
                        continue;
                    end
                end
            end
        end
    end
end


% 4) Write out CSV if saveCSV
if saveCSV
    colNames = {'Subject','Threshold','Metric','Network','ExpMin','RefMin','Value'};
    T = cell2table(masterCSV, 'VariableNames', colNames);

    if isempty(outCSVbasename)
        % Old naming scheme if user gave no custom name
        outCSV = fullfile(network_folder, ...
            sprintf('%s_metrics_thresh_%g.csv', subjectID, threshold));
    else
        % If user gave a name, incorporate it
        outCSV = fullfile(network_folder, ...
            sprintf('%s_thresh_%g.csv', outCSVbasename, threshold));
    end

    writetable(T, outCSV);
    fprintf('CSV saved to: %s\n', outCSV);
end

end % main

% =========================================================================
% ========================= SUPPORT FUNCTIONS ==============================
% =========================================================================

function outList = load_dscalar_list(filepath)
    outList = importdata(filepath);
    if ischar(outList)
        outList = {outList};
    end
end


function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, ...
          PPV_val, PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
          NPV_val, TPR_val, TNR_val, FPR_val, FNR_val, MCC_val, ...
          muI_val, VIn_val, MIn_val] = compute_confmap_stats(Mdata, Cdata, zeroOption)

    % Binarize predictions
    Mdata_bin = (Mdata > 0);
    % For Cdata, assume it is also binarized if needed

    cDC_val = continuous_Dice_coefficient(Mdata_bin, Cdata);
    DC_val  = Dice_coefficient(Mdata_bin, Cdata);

    [~, tm, ~] = map_network_changes(Cdata, Mdata_bin);
    % 2x2 matrix => row=old(0/1), col=new(0/1)
    TP = tm(2,2);  TN = tm(1,1);
    FP = tm(1,2);  FN = tm(2,1);

    TP_val = TP; TN_val = TN; FP_val = FP; FN_val = FN;

    PPV_val = TP/(TP+FP+eps);

    % Jeffreys
    alpha_J=0.5; beta_J=0.5;
    PPVcorr_Jeffreys_val = (TP + alpha_J)/((TP+FP)+alpha_J+beta_J+eps);

    % d1/d2
    d1_size = sum(Mdata_bin(:));
    d2_size = sum(Cdata(:));
    ratio_d1d2 = d1_size/(d2_size+eps);
    factor_d1d2=100.0; offset=0.5;
    alpha_d1d2 = ratio_d1d2*factor_d1d2 + offset;
    beta_d1d2  = (1-ratio_d1d2)*factor_d1d2 + offset;
    PPVcorr_d1d2_val = (TP+alpha_d1d2)/((TP+FP)+alpha_d1d2+beta_d1d2+eps);
        
    prior_percent = 0.05; % 5 percent of network size
    prior_strength = d2_size * prior_percent;

    size_ratio = d1_size / (d2_size + eps);
    offset = 0.5;

    alpha_bayes = size_ratio * prior_strength + offset;
    beta_bayes = (1 - size_ratio) * prior_strength + offset;

    PPVcorr_bayes_val = (TP + alpha_bayes) / ((TP + FP) + alpha_bayes + beta_bayes + eps);

    NPV_val = TN/(TN+FN+eps);
    TPR_val = TP/(TP+FN+eps);
    TNR_val = TN/(TN+FP+eps);
    FPR_val = FP/(FP+TN+eps);
    FNR_val = FN/(FN+TP+eps);

    MCC_val = compute_MCC(TP, TN, FP, FN);

    % Single-value placeholders
    muI_val=0; VIn_val=0; MIn_val=0;
end

function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, ...
          PPV_val, PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
          NPV_val, TPR_val, TNR_val, FPR_val, FNR_val, MCC_val, ...
          muI_val, VIn_val, MIn_val] = compute_network_stats(Mdata, Cdata, zeroOption)

    [Mdata_pd, Cdata_pd] = handleZerosForPartition(Mdata, Cdata, zeroOption);
    muI_val = MutualInformation(Mdata_pd, Cdata_pd);
    [VIn_val, MIn_val] = partition_distance(Mdata_pd, Cdata_pd);

    fixed_labels = [1,2,3,5,7,8,9,10,11,12,13,14,15,16,18];
    nLabels = length(fixed_labels);

    DC_val  = nan(nLabels,1); cDC_val=nan(nLabels,1);
    TP_val=nan(nLabels,1); TN_val=nan(nLabels,1); FP_val=nan(nLabels,1); FN_val=nan(nLabels,1);
    PPV_val=nan(nLabels,1);
    PPVcorr_Jeffreys_val=nan(nLabels,1);
    PPVcorr_d1d2_val=nan(nLabels,1);
    PPVcorr_bayes_val=nan(nLabels,1);
    NPV_val=nan(nLabels,1); TPR_val=nan(nLabels,1); TNR_val=nan(nLabels,1);
    FPR_val=nan(nLabels,1); FNR_val=nan(nLabels,1);
    MCC_val=nan(nLabels,1);

    totalGrey=numel(Cdata);

    for idx=1:nLabels
        lbl = fixed_labels(idx);
        d1_net = double(Mdata==lbl);
        d2_net = double(Cdata==lbl);
        if ~any(d1_net(:)), continue; end

        cDC_val(idx)= continuous_Dice_coefficient(d1_net, d2_net);
        bin_seg= double(d1_net>0.01);
        DC_val(idx)= Dice_coefficient(bin_seg, d2_net);

        [~, tm, ~] = map_network_changes(d2_net, bin_seg);
        TP=tm(2,2); TN=tm(1,1); FP=tm(1,2); FN=tm(2,1);
        TP_val(idx)=TP; TN_val(idx)=TN; FP_val(idx)=FP; FN_val(idx)=FN;

        PPV_val(idx)=TP/(TP+FP+eps);
        
        d1_size=sum(d1_net(:)); d2_size=sum(d2_net(:));
        ratio_d1d2= d1_size/(d2_size+eps);
        factor_d1d2=100.0; offset=0.5;
        alpha_d1d2= ratio_d1d2*factor_d1d2+ offset;
        beta_d1d2= (1-ratio_d1d2)*factor_d1d2+ offset;
        PPVcorr_d1d2_val(idx)= (TP+alpha_d1d2)/((TP+FP)+alpha_d1d2+beta_d1d2+eps);

        prior_percent = 0.05; % 5 percent of network size
        prior_strength = d2_size * prior_percent;

        size_ratio = d1_size / (d2_size + eps);
        offset = 0.5;

        alpha_bayes = size_ratio * prior_strength + offset;
        beta_bayes = (1 - size_ratio) * prior_strength + offset;

        PPVcorr_bayes_val(idx) = (TP + alpha_bayes) / ((TP + FP) + alpha_bayes + beta_bayes + eps);

        prior_number = prior_percent * (d2_size + eps);
        alpha_J=prior_number; beta_J=prior_number;
        PPVcorr_Jeffreys_val(idx)= (TP+alpha_J)/((TP+FP)+alpha_J+beta_J+eps);


        NPV_val(idx)= TN/(TN+FN+eps);
        TPR_val(idx)= TP/(TP+FN+eps);
        TNR_val(idx)= TN/(TN+FP+eps);
        FPR_val(idx)= FP/(FP+TN+eps);
        FNR_val(idx)= FN/(FN+TP+eps);

        MCC_val(idx)= compute_MCC(TP,TN,FP,FN);
    end
end

function [Cx_out, Cy_out] = handleZerosForPartition(Cx, Cy, zeroOption)
    switch zeroOption
        case 1
            Cx_out=Cx; Cy_out=Cy;
        case 2
            mask=(Cx~=0)&(Cy~=0);
            Cx_out=Cx(mask);
            Cy_out=Cy(mask);
        case 3
            maxVal=max([Cx(:);Cy(:)]);
            newLabel=maxVal+1;
            Cx_out=Cx; Cy_out=Cy;
            Cx_out(Cx_out==0)= newLabel;
            Cy_out(Cy_out==0)= newLabel;
        otherwise
            error('zeroOption must be 1,2,or3');
    end
end

function MCC_val= compute_MCC(TP,TN,FP,FN)
    numerator=(TP.*TN)-(FP.*FN);
    denominator= sqrt((TP+FP).*(TP+FN).*(TN+FP).*(TN+FN)+eps);
    MCC_val= numerator./denominator;
end

function val=Dice_coefficient(segA, segB)
    A= segA>0.5; B= segB>0.5;
    inter=sum(A(:)&B(:));
    denom=sum(A(:))+sum(B(:));
    val=2*inter/(denom+eps);
end

function val= continuous_Dice_coefficient(x,y)
    val=(2*sum(min(x(:),y(:))))/(sum(x(:))+sum(y(:))+eps);
end

function [transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Mdata, Cdata)
    unique_networks= unique([Mdata(:); Cdata(:)]);
    transition_matrix= zeros(length(unique_networks));
    transition_matrix_full= zeros(length(unique_networks));
    network_to_index= containers.Map(unique_networks,1:length(unique_networks));
    for i=1:length(Mdata)
        m_idx= network_to_index(Mdata(i));
        c_idx= network_to_index(Cdata(i));
        if Mdata(i)~=Cdata(i)
            transition_matrix(m_idx,c_idx)= transition_matrix(m_idx,c_idx)+1;
        end
        transition_matrix_full(m_idx,c_idx)= transition_matrix_full(m_idx,c_idx)+1;
    end
end

function save_measures_to_disk(network_folder, ...
    minutes_i, minutes_j, ...
    DC_whole_val, cDC_whole_val, ...
    DC_cort_val, cDC_cort_val, ...
    DC_sub_val, cDC_sub_val, ...
    TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
    TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
    TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
    PPV_whole_val, PPVcorr_Jeffreys_val, PPVcorr_d1d2_val, PPVcorr_bayes_val, ...
    NPV_whole_val, TPR_whole_val, TNR_whole_val, FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
    PPV_cort_val, PPVcorr_Jeffreys_cort_val, PPVcorr_d1d2_cort_val, PPVcorr_bayes_cort_val, ...
    NPV_cort_val, TPR_cort_val, TNR_cort_val, FPR_cort_val, FNR_cort_val, MCC_cort_val, ...
    PPV_sub_val, PPVcorr_Jeffreys_sub_val, PPVcorr_d1d2_sub_val, PPVcorr_bayes_sub_val, ...
    NPV_sub_val, TPR_sub_val, TNR_sub_val, FPR_sub_val, FNR_sub_val, MCC_sub_val, ...
    muI_whole_val, VIn_whole_val, MIn_whole_val, ...
    muI_cort_val, VIn_cort_val, MIn_cort_val, ...
    muI_sub_val, VIn_sub_val, MIn_sub_val)

label = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);

% 1) DC & cDC
subfolder = fullfile(network_folder, 'DC_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(DC_whole_val, fullfile(subfolder, ['DC_whole_' label]));

subfolder = fullfile(network_folder, 'cDC_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(cDC_whole_val, fullfile(subfolder, ['cDC_whole_' label]));

subfolder = fullfile(network_folder, 'DC_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(DC_cort_val, fullfile(subfolder, ['DC_cortical_' label]));

subfolder = fullfile(network_folder, 'cDC_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(cDC_cort_val, fullfile(subfolder, ['cDC_cortical_' label]));

subfolder = fullfile(network_folder, 'DC_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(DC_sub_val, fullfile(subfolder, ['DC_subcortical_' label]));

subfolder = fullfile(network_folder, 'cDC_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(cDC_sub_val, fullfile(subfolder, ['cDC_subcortical_' label]));

% 2) Confusion matrix: (TP, TN, FP, FN)
% Re-order so that for measure i, we have (whole,cortical,subcortical).
measure_names = {'TP','TN','FP','FN'};
measure_vals  = {
    % TP has 3 in a row
    TP_whole_val, TP_cort_val, TP_sub_val, ...
    % TN
    TN_whole_val, TN_cort_val, TN_sub_val, ...
    % FP
    FP_whole_val, FP_cort_val, FP_sub_val, ...
    % FN
    FN_whole_val, FN_cort_val, FN_sub_val
};
for idx = 1:length(measure_names)  % measure
    regionNames = {'whole','cortical','subcortical'};
    for r = 1:3
        outvals = measure_vals{(idx-1)*3 + r};
        measName = measure_names{idx};
        subfolder = fullfile(network_folder, [measName '_' regionNames{r}]);
        if ~exist(subfolder, 'dir'), mkdir(subfolder); end
        outpath = fullfile(subfolder, ...
            sprintf('%s_%s_%s', measName, regionNames{r}, label));
        writematrix(outvals, outpath);
    end
end

% 3) PPV, PPVcorr, NPV
subfolder = fullfile(network_folder, 'PPV_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPV_whole_val, fullfile(subfolder, ['PPV_whole_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_Jeffreys_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_Jeffreys_whole_val, fullfile(subfolder, ['PPVcorr_Jeffreys_whole_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_d1d2_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_d1d2_whole_val, fullfile(subfolder, ['PPVcorr_d1d2_whole_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_bayes_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_bayes_whole_val, fullfile(subfolder, ['PPVcorr_bayes_whole_' label]));

subfolder = fullfile(network_folder, 'PPV_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPV_cort_val, fullfile(subfolder, ['PPV_cortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_Jeffreys_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_Jeffreys_cort_val, fullfile(subfolder, ['PPVcorr_Jeffreys_cortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_d1d2_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_d1d2_cort_val, fullfile(subfolder, ['PPVcorr_d1d2_cortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_bayes_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_bayes_cort_val, fullfile(subfolder, ['PPVcorr_bayes_cortical_' label]));

subfolder = fullfile(network_folder, 'PPV_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPV_sub_val, fullfile(subfolder, ['PPV_subcortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_Jeffreys_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_Jeffreys_sub_val, fullfile(subfolder, ['PPVcorr_Jeffreys_subcortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_d1d2_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_d1d2_sub_val, fullfile(subfolder, ['PPVcorr_d1d2_subcortical_' label]));

subfolder = fullfile(network_folder, 'PPVcorr_bayes_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(PPVcorr_bayes_sub_val, fullfile(subfolder, ['PPVcorr_bayes_subcortical_' label]));

subfolder = fullfile(network_folder, 'NPV_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(NPV_whole_val, fullfile(subfolder, ['NPV_whole_' label]));

subfolder = fullfile(network_folder, 'NPV_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(NPV_cort_val, fullfile(subfolder, ['NPV_cortical_' label]));

subfolder = fullfile(network_folder, 'NPV_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(NPV_sub_val, fullfile(subfolder, ['NPV_subcortical_' label]));

% 4) TPR, TNR, FPR, FNR
subfolder = fullfile(network_folder, 'TPR_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TPR_whole_val, fullfile(subfolder, ['TPR_whole_' label]));

subfolder = fullfile(network_folder, 'TPR_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TPR_cort_val, fullfile(subfolder, ['TPR_cortical_' label]));

subfolder = fullfile(network_folder, 'TPR_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TPR_sub_val, fullfile(subfolder, ['TPR_subcortical_' label]));

subfolder = fullfile(network_folder, 'TNR_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TNR_whole_val, fullfile(subfolder, ['TNR_whole_' label]));

subfolder = fullfile(network_folder, 'TNR_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TNR_cort_val, fullfile(subfolder, ['TNR_cortical_' label]));

subfolder = fullfile(network_folder, 'TNR_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(TNR_sub_val, fullfile(subfolder, ['TNR_subcortical_' label]));

subfolder = fullfile(network_folder, 'FPR_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FPR_whole_val, fullfile(subfolder, ['FPR_whole_' label]));

subfolder = fullfile(network_folder, 'FPR_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FPR_cort_val, fullfile(subfolder, ['FPR_cortical_' label]));

subfolder = fullfile(network_folder, 'FPR_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FPR_sub_val, fullfile(subfolder, ['FPR_subcortical_' label]));

subfolder = fullfile(network_folder, 'FNR_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FNR_whole_val, fullfile(subfolder, ['FNR_whole_' label]));

subfolder = fullfile(network_folder, 'FNR_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FNR_cort_val, fullfile(subfolder, ['FNR_cortical_' label]));

subfolder = fullfile(network_folder, 'FNR_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(FNR_sub_val, fullfile(subfolder, ['FNR_subcortical_' label]));

% 5) MCC
subfolder = fullfile(network_folder, 'MCC_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MCC_whole_val, fullfile(subfolder, ['MCC_whole_' label]));

subfolder = fullfile(network_folder, 'MCC_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MCC_cort_val, fullfile(subfolder, ['MCC_cortical_' label]));

subfolder = fullfile(network_folder, 'MCC_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MCC_sub_val, fullfile(subfolder, ['MCC_subcortical_' label]));

% 6) muI, VIn, MIn
subfolder = fullfile(network_folder, 'muI_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(muI_whole_val, fullfile(subfolder, ['muI_whole_' label]));

subfolder = fullfile(network_folder, 'muI_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(muI_cort_val, fullfile(subfolder, ['muI_cortical_' label]));

subfolder = fullfile(network_folder, 'muI_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(muI_sub_val, fullfile(subfolder, ['muI_subcortical_' label]));

subfolder = fullfile(network_folder, 'VIn_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(VIn_whole_val, fullfile(subfolder, ['VIn_whole_' label]));

subfolder = fullfile(network_folder, 'VIn_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(VIn_cort_val, fullfile(subfolder, ['VIn_cortical_' label]));

subfolder = fullfile(network_folder, 'VIn_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(VIn_sub_val, fullfile(subfolder, ['VIn_subcortical_' label]));

subfolder = fullfile(network_folder, 'MIn_whole');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MIn_whole_val, fullfile(subfolder, ['MIn_whole_' label]));

subfolder = fullfile(network_folder, 'MIn_cortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MIn_cort_val, fullfile(subfolder, ['MIn_cortical_' label]));

subfolder = fullfile(network_folder, 'MIn_subcortical');
if ~exist(subfolder, 'dir'), mkdir(subfolder); end
writematrix(MIn_sub_val, fullfile(subfolder, ['MIn_subcortical_' label]));

end

