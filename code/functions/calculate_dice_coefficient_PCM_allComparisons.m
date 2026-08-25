function calculate_dice_coefficient_PCM_allComparisons( ...
    BASEDIR, ...
    dscalarswithassignments1, ...  % .conc file listing dscalars (ExpData)
    dscalarswithassignments2, ...  % .conc file listing dscalars (RefData)
    minutecomparisons1, ...        % .conc file listing the minute labels for each dscalar in list1
    minutecomparisons2, ...        % .conc file listing the minute labels for each dscalar in list2
    network_name, ...
    ConfMap, ...
    threshold, ...
    thresholdTarget, ...
    fig_dir, ...
    zeroOption, ...
    skipIfExists )  %# <-- (OPTIONAL) new boolean param

%--------------------------------------------------------------------------
% calculate_dice_coefficient_PCM_allComparisons
%
% This function extends your "Code #1" logic to run *all pairwise comparisons*
% between two sets of dscalars. For ConfMap == 1, it uses the single-network
% confidence-map approach (binarizes the data). For ConfMap == 0, it does
% partition_distance on the entire vector to get MuI, VIn, MIn, then enumerates
% each unique label to compute DC, cDC, TP, TN, FP, FN, PPV, NPV, TPR, TNR,
% FPR, FNR, plus now MCC, matching the logic from your Code #1 exactly.
%
% 1) If ConfMap == 1 => single-network confidence-map approach.
% 2) If ConfMap == 0 => multi-network approach, enumerating each label, etc.
%
% The new skipIfExists input is a boolean: if true, we skip any (ExpMin,RefMin)
% that already has output files on disk. Otherwise we recompute from scratch.
% A parallel list of "minutes" for each set is read from minutecomparisons1
% and minutecomparisons2, so filenames can include "5min_with_10min" etc.
%
% Outputs:
%   In subfolders of:
%       fig_dir/[network_name]-thresh-[threshold]/
%   For each measure (DC_whole, cDC_whole, TP_whole, etc.), a subfolder is
%   created, and for each pair (e.g. 5min vs 10min), a .txt file is written
%   containing either one row per network label or a single value (if ConfMap=1).
%
%--------------------------------------------------------------------------

%% ----------------- 1) PREPARE DIRECTORIES, PATHS, ETC. ------------------
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'));

if nargin < 12
    % If skipIfExists wasn't provided, default to false
    skipIfExists = false;
end

WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64'; %#ok<NASGU>

network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
if ~exist(network_folder, 'dir')
    mkdir(network_folder);
end

switch zeroOption
    case 1, disp('Zero handling: NO ACTION (zeros remain).');
    case 2, disp('Zero handling: REMOVING zeros before partition_distance.');
    case 3, disp('Zero handling: RELABELING zeros -> maxVal+1 before partition_distance.');
    otherwise, error('zeroOption must be 1, 2, or 3.');
end

if ConfMap
    disp("Hard code warning, running ConfMap (2 networks?).");
else
    disp("Hard code warning, running network dscalar code (assuming ~15 networks?).");
end

%% ----------------- 2) READ IN THE LISTS OF DSCALARS & MINUTES -----------
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

corticalROIs = {'CORTEX_LEFT','CORTEX_RIGHT'};
subcorticalROIs = {'ACCUMBENS_LEFT','ACCUMBENS_RIGHT','AMYGDALA_LEFT','AMYGDALA_RIGHT','BRAIN_STEM',...
    'CAUDATE_LEFT','CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT','DIENCEPHALON_VENTRAL_RIGHT',...
    'CEREBELLUM_LEFT','CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT','HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT',...
    'PALLIDUM_RIGHT','PUTAMEN_LEFT','PUTAMEN_RIGHT','THALAMUS_LEFT','THALAMUS_RIGHT'};

%% ----------------- 3) NESTED LOOPS: ALL PAIRS OF DSCALARS (i, j) ---------
for i = 1:length(dscalar_list1)
    for j = 1:length(dscalar_list2)
        
        minutes_i = minute_list1(i);
        minutes_j = minute_list2(j);

        % (Optional) if skipIfExists => check if e.g. DC_whole/DC_whole_5min_with_10min.txt
        if skipIfExists
            out_label = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);
            test_folder = fullfile(network_folder, 'DC_whole');
            test_file   = fullfile(test_folder, ['DC_whole_' out_label]);
            if exist(test_file, 'file')
                fprintf('Skipping %s vs %s because output already exists.\n', ...
                    dscalar_list1{i}, dscalar_list2{j});
                continue;
            end
        end

        % ---- Load the dscalars
        Mdscalar = cifti_read(dscalar_list1{i});
        Mdata    = Mdscalar.cdata;
        Cdscalar = cifti_read(dscalar_list2{j});
        Cdata    = Cdscalar.cdata;

        % build masks
        cortical_mask    = create_region_mask(Mdscalar, corticalROIs);
        subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);

        % apply threshold
        switch lower(thresholdTarget)
            case 'both'
                Mdata(Mdata < threshold) = 0;
                Cdata(Cdata < threshold) = 0;
            case 'dscalar1'
                Mdata(Mdata < threshold) = 0;
            case 'dscalar2'
                Cdata(Cdata < threshold) = 0;
            otherwise
                error('Invalid thresholdTarget.');
        end

        % ============== WHOLE-BRAIN ==============
        if ConfMap
            [DC_whole_val, cDC_whole_val, ...
             TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
             PPV_whole_val, NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
             FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
             muI_whole_val, VIn_whole_val, MIn_whole_val] ...
               = compute_confmap_stats(Mdata, Cdata, zeroOption);
        else
            [DC_whole_val, cDC_whole_val, ...
             TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
             PPV_whole_val, NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
             FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
             muI_whole_val, VIn_whole_val, MIn_whole_val] ...
               = compute_network_stats(Mdata, Cdata, zeroOption);
        end

        % ============== CORTICAL ==============
        Mdata_cort = Mdata .* cortical_mask;
        Cdata_cort = Cdata .* cortical_mask;
        [DC_cort_val, cDC_cort_val, ...
         TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
         PPV_cort_val, NPV_cort_val, TPR_cort_val, TNR_cort_val, ...
         FPR_cort_val, FNR_cort_val, MCC_cort_val, ...
         muI_cort_val, VIn_cort_val, MIn_cort_val] ...
           = compute_network_stats(Mdata_cort, Cdata_cort, zeroOption);

        % ============== SUBCORTICAL ==============
        Mdata_subcort = Mdata .* subcortical_mask;
        Cdata_subcort = Cdata .* subcortical_mask;
        [DC_sub_val, cDC_sub_val, ...
         TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
         PPV_sub_val, NPV_sub_val, TPR_sub_val, TNR_sub_val, ...
         FPR_sub_val, FNR_sub_val, MCC_sub_val, ...
         muI_sub_val, VIn_sub_val, MIn_sub_val] ...
           = compute_network_stats(Mdata_subcort, Cdata_subcort, zeroOption);

        % ============== SAVE to disk ==============
        save_measures_to_disk(network_folder, ...
            minutes_i, minutes_j, ...
            DC_whole_val,    cDC_whole_val, ...
            DC_cort_val,     cDC_cort_val, ...
            DC_sub_val,      cDC_sub_val, ...
            TP_whole_val,    TN_whole_val,  FP_whole_val,  FN_whole_val, ...
            TP_cort_val,     TN_cort_val,   FP_cort_val,   FN_cort_val, ...
            TP_sub_val,      TN_sub_val,    FP_sub_val,    FN_sub_val, ...
            PPV_whole_val,   NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
            FPR_whole_val,   FNR_whole_val, MCC_whole_val, ...
            PPV_cort_val,    NPV_cort_val,  TPR_cort_val,  TNR_cort_val, ...
            FPR_cort_val,    FNR_cort_val,  MCC_cort_val, ...
            PPV_sub_val,     NPV_sub_val,   TPR_sub_val,   TNR_sub_val, ...
            FPR_sub_val,     FNR_sub_val,   MCC_sub_val, ...
            muI_whole_val,   VIn_whole_val, MIn_whole_val, ...
            muI_cort_val,    VIn_cort_val,  MIn_cort_val, ...
            muI_sub_val,     VIn_sub_val,   MIn_sub_val);

    end % for j
end % for i
end % main


% =========================================================================
% =                    SUPPORT FUNCTIONS BELOW                             =
% =========================================================================

function outList = load_dscalar_list(filepath)
    outList = importdata(filepath);
    if ischar(outList)
        outList = {outList};
    end
end

function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, ...
          PPV_val, NPV_val, TPR_val, TNR_val, FPR_val, FNR_val, MCC_val, ...
          muI_val, VIn_val, MIn_val] = compute_confmap_stats(Mdata, Cdata, ~)
    Mdata_bin = (Mdata > 0);  % predicted
    % ground-truth => Cdata as-is

    cDC_val = continuous_Dice_coefficient(Mdata_bin, Cdata);
    DC_val  = Dice_coefficient(Mdata_bin, Cdata);

    [~, tm, ~] = map_network_changes(Cdata, Mdata_bin);
    TP = tm(2,2);  TN = tm(1,1);
    FP = tm(1,2);  FN = tm(2,1);

    TP_val = TP(:); TN_val = TN(:);
    FP_val = FP(:); FN_val = FN(:);

    PPV_val = TP / (TP + FP + eps);
    NPV_val = TN / (TN + FN + eps);
    TPR_val = TP / (TP + FN + eps);
    TNR_val = TN / (TN + FP + eps);
    FPR_val = FP / (FP + TN + eps);
    FNR_val = FN / (FN + TP + eps);

    MCC_val = compute_MCC(TP, TN, FP, FN);

    muI_val  = 0;
    VIn_val  = 0;
    MIn_val  = 0;

    DC_val = DC_val(:);
    cDC_val= cDC_val(:);
    PPV_val= PPV_val(:);  NPV_val=NPV_val(:);
    TPR_val= TPR_val(:);  TNR_val=TNR_val(:);
    FPR_val= FPR_val(:);  FNR_val=FNR_val(:);
end

function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, ...
          PPV_val, NPV_val, TPR_val, TNR_val, FPR_val, FNR_val, MCC_val, ...
          muI_val, VIn_val, MIn_val] = compute_network_stats(Mdata, Cdata, zeroOption)

    % -- partition_distance stuff:
    [Mdata_pd, Cdata_pd] = handleZerosForPartition(Mdata, Cdata, zeroOption);
    muI_val = MutualInformation(Mdata_pd, Cdata_pd);
    [VIn_val, MIn_val] = partition_distance(Mdata_pd, Cdata_pd);

    muI_val = muI_val(:);
    VIn_val = VIn_val(:);
    MIn_val = MIn_val(:);

    % -- define the 15 labels we do want:
    fixed_labels = [1,2,3,5,7,8,9,10,11,12,13,14,15,16,18];
    nLabels = length(fixed_labels);

    % init arrays to NaN
    DC_val   = nan(nLabels,1);
    cDC_val  = nan(nLabels,1);
    TP_val   = nan(nLabels,1);
    TN_val   = nan(nLabels,1);
    FP_val   = nan(nLabels,1);
    FN_val   = nan(nLabels,1);
    PPV_val  = nan(nLabels,1);
    NPV_val  = nan(nLabels,1);
    TPR_val  = nan(nLabels,1);
    TNR_val  = nan(nLabels,1);
    FPR_val  = nan(nLabels,1);
    FNR_val  = nan(nLabels,1);
    MCC_val  = nan(nLabels,1);

    for idx = 1:nLabels
        lbl = fixed_labels(idx);
        d1_net = double(Mdata == lbl);  % predicted
        d2_net = double(Cdata == lbl);  % ground-truth

        % =========== NEW: if we never predicted this label => skip => remain NaN
        % user wants "no data => do not penalize or yield 0, just be NaN"
        if ~any(d1_net(:))
            continue;  % keep as NaN
        end

        % compute cDC
        cDC_val(idx) = continuous_Dice_coefficient(d1_net, d2_net);

        % discrete => binarize
        bin_seg = double(d1_net > 0.01);
        DC_val(idx) = Dice_coefficient(bin_seg, d2_net);

        [~, tm, ~] = map_network_changes(d2_net, bin_seg);
        TP = tm(2,2);  TN = tm(1,1);
        FP = tm(1,2);  FN = tm(2,1);

        TP_val(idx) = TP;
        TN_val(idx) = TN;
        FP_val(idx) = FP;
        FN_val(idx) = FN;

        PPV_val(idx) = TP / (TP + FP + eps);
        NPV_val(idx) = TN / (TN + FN + eps);
        TPR_val(idx) = TP / (TP + FN + eps);
        TNR_val(idx) = TN / (TN + FP + eps);
        FPR_val(idx) = FP / (FP + TN + eps);
        FNR_val(idx) = FN / (FN + TP + eps);

        MCC_val(idx) = compute_MCC(TP, TN, FP, FN);
    end
end

function [Cx_out, Cy_out] = handleZerosForPartition(Cx, Cy, zeroOption)
    switch zeroOption
        case 1
            Cx_out = Cx;  Cy_out = Cy;
        case 2
            mask = (Cx ~= 0) & (Cy ~= 0);
            Cx_out = Cx(mask);
            Cy_out = Cy(mask);
        case 3
            maxVal = max([Cx(:); Cy(:)]);
            newLabel = maxVal + 1;
            Cx_out = Cx;  Cy_out = Cy;
            Cx_out(Cx_out == 0) = newLabel;
            Cy_out(Cy_out == 0) = newLabel;
        otherwise
            error('zeroOption must be 1,2,or3');
    end
end

function MCC_val = compute_MCC(TP, TN, FP, FN)
    numerator = (TP .* TN) - (FP .* FN);
    denominator = sqrt((TP + FP) .* (TP + FN) .* (TN + FP) .* (TN + FN) + eps);
    MCC_val = numerator ./ denominator;
end

function save_measures_to_disk(network_folder, ...
    minutes_i, minutes_j, ...
    DC_whole_val, cDC_whole_val, ...
    DC_cort_val, cDC_cort_val, ...
    DC_sub_val, cDC_sub_val, ...
    TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
    TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
    TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
    PPV_whole_val, NPV_whole_val, TPR_whole_val, TNR_whole_val, ...
    FPR_whole_val, FNR_whole_val, MCC_whole_val, ...
    PPV_cort_val, NPV_cort_val, TPR_cort_val, TNR_cort_val, ...
    FPR_cort_val, FNR_cort_val, MCC_cort_val, ...
    PPV_sub_val, NPV_sub_val, TPR_sub_val, TNR_sub_val, ...
    FPR_sub_val, FNR_sub_val, MCC_sub_val, ...
    muI_whole_val, VIn_whole_val, MIn_whole_val, ...
    muI_cort_val, VIn_cort_val, MIn_cort_val, ...
    muI_sub_val, VIn_sub_val, MIn_sub_val)

    label = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);

    %% ---------- DC_whole / cDC_whole -----------
    subfolder = fullfile(network_folder, 'DC_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DC_whole_' label]);
    writematrix(DC_whole_val, outpath);

    subfolder = fullfile(network_folder, 'cDC_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['cDC_whole_' label]);
    writematrix(cDC_whole_val, outpath);

    %% ---------- DC_cortical / cDC_cortical -----------
    subfolder = fullfile(network_folder, 'DC_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DC_cortical_' label]);
    writematrix(DC_cort_val, outpath);

    subfolder = fullfile(network_folder, 'cDC_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['cDC_cortical_' label]);
    writematrix(cDC_cort_val, outpath);

    %% ---------- DC_subcortical / cDC_subcortical -----------
    subfolder = fullfile(network_folder, 'DC_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DC_subcortical_' label]);
    writematrix(DC_sub_val, outpath);

    subfolder = fullfile(network_folder, 'cDC_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['cDC_subcortical_' label]);
    writematrix(cDC_sub_val, outpath);

    %% ---------- TP, TN, FP, FN -----------
    measure_names = {'TP', 'TN', 'FP', 'FN'};
    measure_vals  = {TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
                     TP_cort_val,  TN_cort_val,  FP_cort_val,  FN_cort_val, ...
                     TP_sub_val,   TN_sub_val,   FP_sub_val,   FN_sub_val};
    for idx = 1:length(measure_names)
        region = {'whole','cortical','subcortical'};
        for r = 1:length(region)
            folder = fullfile(network_folder, [measure_names{idx} '_' region{r}]);
            if ~exist(folder, 'dir'), mkdir(folder); end
            outpath = fullfile(folder, [measure_names{idx} '_' region{r} '_' label]);
            writematrix(measure_vals{(idx-1)*3 + r}, outpath);
        end
    end

    %% ---------- PPV, NPV -----------
    subfolder = fullfile(network_folder, 'PPV_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(PPV_whole_val, fullfile(subfolder, ['PPV_whole_' label]));

    subfolder = fullfile(network_folder, 'PPV_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(PPV_cort_val, fullfile(subfolder, ['PPV_cortical_' label]));

    subfolder = fullfile(network_folder, 'PPV_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(PPV_sub_val, fullfile(subfolder, ['PPV_subcortical_' label]));

    subfolder = fullfile(network_folder, 'NPV_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(NPV_whole_val, fullfile(subfolder, ['NPV_whole_' label]));

    subfolder = fullfile(network_folder, 'NPV_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(NPV_cort_val, fullfile(subfolder, ['NPV_cortical_' label]));

    subfolder = fullfile(network_folder, 'NPV_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(NPV_sub_val, fullfile(subfolder, ['NPV_subcortical_' label]));

    %% ---------- TPR, TNR, FPR, FNR -----------
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

    %% ---------- MCC -----------
    subfolder = fullfile(network_folder, 'MCC_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(MCC_whole_val, fullfile(subfolder, ['MCC_whole_' label]));

    subfolder = fullfile(network_folder, 'MCC_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(MCC_cort_val, fullfile(subfolder, ['MCC_cortical_' label]));

    subfolder = fullfile(network_folder, 'MCC_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    writematrix(MCC_sub_val, fullfile(subfolder, ['MCC_subcortical_' label]));

    %% ---------- muI, VIn, MIn -----------
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
