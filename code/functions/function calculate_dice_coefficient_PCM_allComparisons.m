function calculate_dice_coefficient_PCM_allComparisons( ...
             BASEDIR, ...
             dscalarswithassignments1, ...  % .conc file listing dscalars (ExpData, for example)
             dscalarswithassignments2, ...  % .conc file listing dscalars (RefData, for example)
             minutecomparisons1, ...        % .conc file listing the minute labels for each dscalar in list1
             minutecomparisons2, ...        % .conc file listing the minute labels for each dscalar in list2
             network_name, ...
             ConfMap, ...
             threshold, ...
             thresholdTarget, ...
             fig_dir, ...
             zeroOption )
%--------------------------------------------------------------------------
% calculate_dice_coefficient_PCM_allComparisons
%
% This function extends your "Code #1" logic to run *all pairwise comparisons*
% between two sets of dscalars. We also have a parallel list of "minutes"
% for each set, so we can label the outputs (e.g., "5min_with_10min").
%
% Inputs:
%   BASEDIR: Base directory (used if you need it for path-related reasons).
%   dscalarswithassignments1: Path to a .conc file listing set #1 of
%                             dscalars (e.g., ExpData).
%   dscalarswithassignments2: Path to a .conc file listing set #2 of
%                             dscalars (e.g., RefData).
%   minutecomparisons1:       Path to a .conc file listing the "minutes"
%                             for each dscalar in set #1 (e.g. 2, 5, 10...).
%   minutecomparisons2:       Path to a .conc file listing the "minutes"
%                             for each dscalar in set #2.
%   network_name:             Network name (e.g. "All").
%   ConfMap:                  If 1 => handle confidence-map style data
%                             (binarize + conf dice). Else => partition_distance logic.
%   threshold:                Numeric threshold value.
%   thresholdTarget:          'both', 'dscalar1', or 'dscalar2'.
%   fig_dir:                  Base folder in which to store results.
%   zeroOption:               How to handle zeros:
%                                1 => do nothing
%                                2 => remove zero-labeled indices
%                                3 => relabel zeros => maxVal+1
%--------------------------------------------------------------------------
%
% Output:
%   In subfolders of:
%       fig_dir/[network_name]-thresh-[threshold]/
%   For each measure (DC_whole, cDC_whole, etc.), a subfolder is created,
%   and for each comparison (e.g. 5min vs 10min), a .txt file is written
%   with the corresponding metrics.
%
% Example usage:
%   calculate_dice_coefficient_PCM_allComparisons('/base/dir', ...
%       'dscalars_group1.conc', 'dscalars_group2.conc', ...
%       'minutes_group1.conc', 'minutes_group2.conc', ...
%       'All', 0, 0, 'both', '/figs', 2);
%--------------------------------------------------------------------------

%% ----------------- 1) PREPARE DIRECTORIES, PATHS, ETC. ------------------
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))

% Path to Workbench, if needed:
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64'; %#ok<NASGU>
% (Adjust if you need to call Workbench commands; otherwise this might be unused.)

% Create main output folder (e.g. "fig_dir/All-thresh-0"):
network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
if ~exist(network_folder, 'dir')
    mkdir(network_folder);
end

% Print zero-handling strategy
switch zeroOption
    case 1
        disp('Zero handling: NO ACTION (zeros remain).')
    case 2
        disp('Zero handling: REMOVING zeros before partition_distance.')
    case 3
        disp('Zero handling: RELABELING zeros -> maxVal+1 before partition_distance.')
    otherwise
        error('zeroOption must be 1, 2, or 3.');
end

% Hard-coded # of networks
if ConfMap
    disp("Hard code warning, running ConfMap (2 networks?).") 
    num_networks = 1;  %#ok<NASGU>  % Typically for confidence maps
else
    disp("Hard code warning, running on network dscalar map (assuming 15 networks?).") 
    num_networks = 15; %#ok<NASGU>  % For typical network partitions
end

%% ----------------- 2) READ IN THE LISTS OF DSCALARS & MINUTES -----------
% We parse the .conc files for dscalars for group #1 and group #2
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

% Parse the minute .conc files
minute_list1  = importdata(minutecomparisons1);  % e.g. [5; 10; 15; ...]
minute_list2  = importdata(minutecomparisons2);

% Ensure alignment
if length(dscalar_list1) ~= length(minute_list1)
    error('dscalar_list1 and minute_list1 must have the same number of lines.');
end
if length(dscalar_list2) ~= length(minute_list2)
    error('dscalar_list2 and minute_list2 must have the same number of lines.');
end

% Region definitions for masking
corticalROIs = {'CORTEX_LEFT','CORTEX_RIGHT'};
subcorticalROIs = {'ACCUMBENS_LEFT','ACCUMBENS_RIGHT','AMYGDALA_LEFT','AMYGDALA_RIGHT','BRAIN_STEM',...
    'CAUDATE_LEFT','CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT','DIENCEPHALON_VENTRAL_RIGHT',...
    'CEREBELLUM_LEFT','CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT','HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT',...
    'PALLIDUM_RIGHT','PUTAMEN_LEFT','PUTAMEN_RIGHT','THALAMUS_LEFT','THALAMUS_RIGHT'};

%% ----------------- 3) NESTED LOOPS: ALL PAIRS OF DSCALARS (i, j) ---------
for i = 1:length(dscalar_list1)
    for j = 1:length(dscalar_list2)
        
        % a) Identify the minutes for labeling output files
        minutes_i = minute_list1(i);
        minutes_j = minute_list2(j);
        
        % b) Load the .dscalar data
        dscalar1_path = dscalar_list1{i};
        dscalar2_path = dscalar_list2{j};
        
        % Read in the data
        Mdscalar = cifti_read(dscalar1_path);
        Mdata    = Mdscalar.cdata;   % Nx1
        Cdscalar = cifti_read(dscalar2_path);
        Cdata    = Cdscalar.cdata;   % Nx1
        
        % c) Build cortical & subcortical masks
        cortical_mask    = create_region_mask(Mdscalar, corticalROIs);
        subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
        
        % d) Apply threshold if requested
        switch lower(thresholdTarget)
            case 'both'
                Mdata(Mdata < threshold) = 0;
                Cdata(Cdata < threshold) = 0;
            case 'dscalar1'
                Mdata(Mdata < threshold) = 0;
            case 'dscalar2'
                Cdata(Cdata < threshold) = 0;
            otherwise
                error('Invalid thresholdTarget. Choose ''both'', ''dscalar1'', or ''dscalar2''.');
        end
        
        %=================================================
        % WHOLE-BRAIN
        %=================================================
        if ConfMap
            [DC_whole_val, cDC_whole_val, ...
             TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
             PPV_whole_val, NPV_whole_val, ...
             muI_whole_val, VIn_whole_val, MIn_whole_val] ...
               = compute_confmap_stats(Mdata, Cdata, zeroOption);
        else
            [DC_whole_val, cDC_whole_val, ...
             TP_whole_val, TN_whole_val, FP_whole_val, FN_whole_val, ...
             PPV_whole_val, NPV_whole_val, ...
             muI_whole_val, VIn_whole_val, MIn_whole_val] ...
               = compute_network_stats(Mdata, Cdata, zeroOption);
        end
        
        %=================================================
        % CORTICAL
        %=================================================
        Mdata_cortical = Mdata .* cortical_mask;
        Cdata_cortical = Cdata .* cortical_mask;
        
        if ConfMap
            [DC_cort_val, cDC_cort_val, ...
             TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
             PPV_cort_val, NPV_cort_val, ...
             muI_cort_val, VIn_cort_val, MIn_cort_val] ...
               = compute_confmap_stats(Mdata_cortical, Cdata_cortical, zeroOption);
        else
            [DC_cort_val, cDC_cort_val, ...
             TP_cort_val, TN_cort_val, FP_cort_val, FN_cort_val, ...
             PPV_cort_val, NPV_cort_val, ...
             muI_cort_val, VIn_cort_val, MIn_cort_val] ...
               = compute_network_stats(Mdata_cortical, Cdata_cortical, zeroOption);
        end
        
        %=================================================
        % SUBCORTICAL
        %=================================================
        Mdata_subcortical = Mdata .* subcortical_mask;
        Cdata_subcortical = Cdata .* subcortical_mask;
        
        if ConfMap
            [DC_sub_val, cDC_sub_val, ...
             TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
             PPV_sub_val, NPV_sub_val, ...
             muI_sub_val, VIn_sub_val, MIn_sub_val] ...
               = compute_confmap_stats(Mdata_subcortical, Cdata_subcortical, zeroOption);
        else
            [DC_sub_val, cDC_sub_val, ...
             TP_sub_val, TN_sub_val, FP_sub_val, FN_sub_val, ...
             PPV_sub_val, NPV_sub_val, ...
             muI_sub_val, VIn_sub_val, MIn_sub_val] ...
               = compute_network_stats(Mdata_subcortical, Cdata_subcortical, zeroOption);
        end
        
        %=================================================
        % e) SAVE results to disk
        %=================================================
        save_measures_to_disk(network_folder, ...
            minutes_i, minutes_j, ...
            DC_whole_val,    cDC_whole_val, ...
            DC_cort_val,     cDC_cort_val, ...
            DC_sub_val,      cDC_sub_val, ...
            TP_whole_val,    TN_whole_val,  FP_whole_val,  FN_whole_val, ...
            TP_cort_val,     TN_cort_val,   FP_cort_val,   FN_cort_val, ...
            TP_sub_val,      TN_sub_val,    FP_sub_val,    FN_sub_val, ...
            PPV_whole_val,   NPV_whole_val, ...
            PPV_cort_val,    NPV_cort_val, ...
            PPV_sub_val,     NPV_sub_val,  ...
            muI_whole_val,   VIn_whole_val, MIn_whole_val, ...
            muI_cort_val,    VIn_cort_val,  MIn_cort_val, ...
            muI_sub_val,     VIn_sub_val,   MIn_sub_val);
        
    end % j
end % i

end % main function
%--------------------------------------------------------------------------


%% ========================================================================
%%                S U P P O R T   F U N C T I O N S
%% ========================================================================

function outList = load_dscalar_list(filepath)
    % load_dscalar_list: Parses a .conc or text file that lists dscalar paths.
    % Returns a cell array of strings, one per line in the file.
    outList = importdata(filepath);
    if ischar(outList)
        % If there's only one line, importdata returns a single string
        outList = {outList};
    end
end

%function mask = create_region_mask(Mdscalar, regionNames)
%    % create_region_mask:
%    %   In your pipeline, you'd typically check Mdscalar.brainstructure,
%    %   then set mask(...)=1 for relevant ROIs. For demonstration, this
%    %   sets everything =1, meaning no actual sub-selection.
%    
%    % Here is a placeholder that includes everything:
%    N = length(Mdscalar.cdata);
%    mask = zeros(N,1);
%    
%    if ~isempty(regionNames)
%        % Typically you'd do something like:
%        % idx = ismember(Mdscalar.brainstructure, regionNames);
%        % mask(idx) = 1;
%        % But let's make it "all included" as a placeholder:
%        mask(:) = 1; 
%    end
%end

function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, PPV_val, NPV_val, muI_val, VIn_val, MIn_val] = ...
          compute_confmap_stats(Mdata, Cdata, zeroOption)
    % compute_confmap_stats:
    %   For confidence maps, your code #1 binarizes Mdata/Cdata for DC,
    %   and uses continuous_Dice_coefficient for cDC, etc.
    
    % 1) Binarize
    Mdata_bin = (Mdata > 0);
    Cdata_bin = (Cdata > 0);
    
    % 2) Continuous dice
    cDC_val = continuous_Dice_coefficient(Mdata, Cdata_bin);
    
    % 3) Discrete dice
    DC_val  = Dice_coefficient(Mdata_bin, Cdata_bin);
    
    % 4) True/False positives/negatives
    [~, transition_matrix_full, ~] = map_network_changes(Mdata_bin, Cdata_bin);
    TP_val = transition_matrix_full(2,2);
    TN_val = transition_matrix_full(1,1);
    FN_val = transition_matrix_full(2,1);
    FP_val = transition_matrix_full(1,2);
    
    % 5) PPV, NPV
    PPV_val = TP_val / (TP_val + FP_val + eps);
    NPV_val = TN_val / (TN_val + FN_val + eps);
    
    % 6) For confmaps, we typically don't do partition_distance. 
    %    We'll set muI, VIn, MIn to zero (or NaN).
    muI_val = 0;  
    VIn_val = 0;  
    MIn_val = 0;
end

function [DC_val, cDC_val, TP_val, TN_val, FP_val, FN_val, PPV_val, NPV_val, muI_val, VIn_val, MIn_val] = ...
          compute_network_stats(Mdata, Cdata, zeroOption)
    % compute_network_stats:
    %   For network-labeled data, we do partition_distance-based logic.
    %   Then compute DC/cDC for each label and typically average or sum them.
    
    % 1) Handle zeros for partition_distance
    [Mdata_pd, Cdata_pd] = handleZerosForPartition(Mdata, Cdata, zeroOption);
    
    % 2) Mutual info, Variation of info, etc.
    muI_val = MutualInformation(Mdata_pd, Cdata_pd);
    [VIn_val, MIn_val] = partition_distance(Mdata_pd, Cdata_pd);
    
    % 3) We find each unique label (except 0), compute DC/cDC, then average.
    unique_labels = unique([Mdata; Cdata]);
    unique_labels(unique_labels == 0) = [];
    
    cDC_list = [];
    DC_list  = [];
    TP_list  = [];
    TN_list  = [];
    FP_list  = [];
    FN_list  = [];
    
    for lbl = unique_labels'
        binA = double(Mdata == lbl);
        binB = double(Cdata == lbl);
        
        cdc = continuous_Dice_coefficient(binA, binB);
        cDC_list(end+1) = cdc; %#ok<AGROW>
        
        binB(binB > 0.01) = 1; % Binarize for discrete DC
        dc = Dice_coefficient(binA, binB);
        DC_list(end+1) = dc; %#ok<AGROW>
        
        [~, transition_matrix_full, ~] = map_network_changes(binA, binB);
        TP_list(end+1) = transition_matrix_full(2,2); %#ok<AGROW>
        TN_list(end+1) = transition_matrix_full(1,1); %#ok<AGROW>
        FN_list(end+1) = transition_matrix_full(2,1); %#ok<AGROW>
        FP_list(end+1) = transition_matrix_full(1,2); %#ok<AGROW>
    end
    
    if isempty(cDC_list)
        cDC_val = 0;
        DC_val  = 0;
        TP_val  = 0; TN_val  = 0; FP_val = 0; FN_val = 0;
    else
        cDC_val = mean(cDC_list);
        DC_val  = mean(DC_list);
        TP_val  = sum(TP_list);
        TN_val  = sum(TN_list);
        FP_val  = sum(FP_list);
        FN_val  = sum(FN_list);
    end
    
    PPV_val = TP_val / (TP_val + FP_val + eps);
    NPV_val = TN_val / (TN_val + FN_val + eps);
end

function [Cx_out, Cy_out] = handleZerosForPartition(Cx, Cy, zeroOption)
    % handleZerosForPartition: deals with zeros in Cx/Cy for partition_distance
    switch zeroOption
        case 1
            Cx_out = Cx;
            Cy_out = Cy;
        case 2
            mask = (Cx ~= 0) & (Cy ~= 0);
            Cx_out = Cx(mask);
            Cy_out = Cy(mask);
        case 3
            maxVal = max([Cx(:); Cy(:)]);
            newLabel = maxVal + 1;
            Cx_out = Cx;
            Cy_out = Cy;
            Cx_out(Cx_out == 0) = newLabel;
            Cy_out(Cy_out == 0) = newLabel;
        otherwise
            error('zeroOption must be 1, 2, or 3.');
    end
end

%function val = Dice_coefficient(A, B)
%    % Dice_coefficient: A, B are binary vectors/matrices
%    val = 2 * sum(A & B) / (sum(A) + sum(B) + eps);
%end

%function val = continuous_Dice_coefficient(A, B)
%    % continuous_Dice_coefficient: one array continuous, the other binary
%   val = 2 * sum(min(A, B)) / (sum(A) + sum(B) + eps);
%end

%function [mapped, transition_matrix_full, transition_matrix_each] = map_network_changes(A, B)
%    % map_network_changes:
%    %   Minimal placeholder that calculates transitions between A & B if they
%    %   are binary. If they are multi-label, you'd do a more complex approach.
%    transition_matrix_full = zeros(2,2);
%    mapped = [];
%    transition_matrix_each = [];
%    
%    A_bin = A > 0;
%    B_bin = B > 0;
%    
%    transition_matrix_full(1,1) = sum(~A_bin & ~B_bin);
%    transition_matrix_full(1,2) = sum(~A_bin &  B_bin);
%    transition_matrix_full(2,1) = sum( A_bin & ~B_bin);
%    transition_matrix_full(2,2) = sum( A_bin &  B_bin);
%end

%function MI = MutualInformation(X, Y)
%    % Minimal placeholder for your real mutual information code
%    MI = 0.0;  % For demonstration, set to 0 or see your actual implementation
%end

%function [VIn, MIn] = partition_distance(X, Y)
%    % Minimal placeholder for variation of information / mutual information distance
%    VIn = 0.0; 
%    MIn = 0.0;
%end


%% ------------------------------------------------------------------------
function save_measures_to_disk(network_folder, ...
                               minutes_i, minutes_j, ...
                               DC_whole_val,    cDC_whole_val, ...
                               DC_cort_val,     cDC_cort_val, ...
                               DC_sub_val,      cDC_sub_val, ...
                               TP_whole_val,    TN_whole_val,  FP_whole_val,  FN_whole_val, ...
                               TP_cort_val,     TN_cort_val,   FP_cort_val,   FN_cort_val, ...
                               TP_sub_val,      TN_sub_val,    FP_sub_val,    FN_sub_val, ...
                               PPV_whole_val,   NPV_whole_val, ...
                               PPV_cort_val,    NPV_cort_val,  ...
                               PPV_sub_val,     NPV_sub_val,   ...
                               muI_whole_val,   VIn_whole_val, MIn_whole_val, ...
                               muI_cort_val,    VIn_cort_val,  MIn_cort_val,  ...
                               muI_sub_val,     VIn_sub_val,   MIn_sub_val)
    % save_measures_to_disk:
    %   Writes each measure to a separate subfolder named, for example,
    %   "DC_whole", "cDC_whole", "TP_whole", etc. The file name includes
    %   the minutes, e.g. "DiceCoefficientsMatrix_whole_5min_with_10min.txt"
    
    label = sprintf('%dmin_with_%dmin.txt', minutes_i, minutes_j);

    % ========== DC_whole ==========
    subfolder = fullfile(network_folder, 'DC_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DiceCoefficientsMatrix_whole_' label]);
    writematrix(DC_whole_val, outpath);

    % ========== cDC_whole ==========
    subfolder = fullfile(network_folder, 'cDC_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['continuousDiceCoefficientsMatrix_whole_' label]);
    writematrix(cDC_whole_val, outpath);

    % ========== DC_cortical ==========
    subfolder = fullfile(network_folder, 'DC_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DiceCoefficientsMatrix_cortical_' label]);
    writematrix(DC_cort_val, outpath);

    % ========== cDC_cortical ==========
    subfolder = fullfile(network_folder, 'cDC_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['continuousDiceCoefficientsMatrix_cortical_' label]);
    writematrix(cDC_cort_val, outpath);

    % ========== DC_subcortical ==========
    subfolder = fullfile(network_folder, 'DC_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['DiceCoefficientsMatrix_subcortical_' label]);
    writematrix(DC_sub_val, outpath);

    % ========== cDC_subcortical ==========
    subfolder = fullfile(network_folder, 'cDC_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['continuousDiceCoefficientsMatrix_subcortical_' label]);
    writematrix(cDC_sub_val, outpath);

    % ======= TruePositive_whole =======
    subfolder = fullfile(network_folder, 'TP_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TruePositive_whole_' label]);
    writematrix(TP_whole_val, outpath);

    % ======= TrueNegative_whole =======
    subfolder = fullfile(network_folder, 'TN_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TrueNegative_whole_' label]);
    writematrix(TN_whole_val, outpath);

    % ======= FalsePositive_whole =======
    subfolder = fullfile(network_folder, 'FP_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalsePositive_whole_' label]);
    writematrix(FP_whole_val, outpath);

    % ======= FalseNegative_whole =======
    subfolder = fullfile(network_folder, 'FN_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalseNegative_whole_' label]);
    writematrix(FN_whole_val, outpath);

    % ======= TruePositive_cortical =======
    subfolder = fullfile(network_folder, 'TP_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TruePositive_cortical_' label]);
    writematrix(TP_cort_val, outpath);

    % ======= TrueNegative_cortical =======
    subfolder = fullfile(network_folder, 'TN_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TrueNegative_cortical_' label]);
    writematrix(TN_cort_val, outpath);

    % ======= FalsePositive_cortical =======
    subfolder = fullfile(network_folder, 'FP_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalsePositive_cortical_' label]);
    writematrix(FP_cort_val, outpath);

    % ======= FalseNegative_cortical =======
    subfolder = fullfile(network_folder, 'FN_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalseNegative_cortical_' label]);
    writematrix(FN_cort_val, outpath);

    % ======= TruePositive_subcortical =======
    subfolder = fullfile(network_folder, 'TP_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TruePositive_subcortical_' label]);
    writematrix(TP_sub_val, outpath);

    % ======= TrueNegative_subcortical =======
    subfolder = fullfile(network_folder, 'TN_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['TrueNegative_subcortical_' label]);
    writematrix(TN_sub_val, outpath);

    % ======= FalsePositive_subcortical =======
    subfolder = fullfile(network_folder, 'FP_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalsePositive_subcortical_' label]);
    writematrix(FP_sub_val, outpath);

    % ======= FalseNegative_subcortical =======
    subfolder = fullfile(network_folder, 'FN_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['FalseNegative_subcortical_' label]);
    writematrix(FN_sub_val, outpath);

    % ========== PPV_whole ==========
    subfolder = fullfile(network_folder, 'PPV_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['PPV_whole_' label]);
    writematrix(PPV_whole_val, outpath);

    % ========== NPV_whole ==========
    subfolder = fullfile(network_folder, 'NPV_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['NPV_whole_' label]);
    writematrix(NPV_whole_val, outpath);

    % ========== PPV_cortical ==========
    subfolder = fullfile(network_folder, 'PPV_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['PPV_cortical_' label]);
    writematrix(PPV_cort_val, outpath);

    % ========== NPV_cortical ==========
    subfolder = fullfile(network_folder, 'NPV_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['NPV_cortical_' label]);
    writematrix(NPV_cort_val, outpath);

    % ========== PPV_subcortical ==========
    subfolder = fullfile(network_folder, 'PPV_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['PPV_subcortical_' label]);
    writematrix(PPV_sub_val, outpath);

    % ========== NPV_subcortical ==========
    subfolder = fullfile(network_folder, 'NPV_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['NPV_subcortical_' label]);
    writematrix(NPV_sub_val, outpath);

    % ========== muI_whole ==========
    subfolder = fullfile(network_folder, 'muI_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['muI_whole_' label]);
    writematrix(muI_whole_val, outpath);

    % ========== VIn_whole ==========
    subfolder = fullfile(network_folder, 'VIn_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['VIn_whole_' label]);
    writematrix(VIn_whole_val, outpath);

    % ========== MIn_whole ==========
    subfolder = fullfile(network_folder, 'MIn_whole');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['MIn_whole_' label]);
    writematrix(MIn_whole_val, outpath);

    % ========== muI_cortical ==========
    subfolder = fullfile(network_folder, 'muI_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['muI_cortical_' label]);
    writematrix(muI_cort_val, outpath);

    % ========== VIn_cortical ==========
    subfolder = fullfile(network_folder, 'VIn_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['VIn_cortical_' label]);
    writematrix(VIn_cort_val, outpath);

    % ========== MIn_cortical ==========
    subfolder = fullfile(network_folder, 'MIn_cortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['MIn_cortical_' label]);
    writematrix(MIn_cort_val, outpath);

    % ========== muI_subcortical ==========
    subfolder = fullfile(network_folder, 'muI_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['muI_subcortical_' label]);
    writematrix(muI_sub_val, outpath);

    % ========== VIn_subcortical ==========
    subfolder = fullfile(network_folder, 'VIn_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['VIn_subcortical_' label]);
    writematrix(VIn_sub_val, outpath);

    % ========== MIn_subcortical ==========
    subfolder = fullfile(network_folder, 'MIn_subcortical');
    if ~exist(subfolder, 'dir'), mkdir(subfolder); end
    outpath = fullfile(subfolder, ['MIn_subcortical_' label]);
    writematrix(MIn_sub_val, outpath);

end