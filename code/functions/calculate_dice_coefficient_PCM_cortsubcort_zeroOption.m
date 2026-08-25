function calculate_dice_coefficient_PCM_cortsubcort_zeroOption(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, thresholdTarget, fig_dir, zeroOption)
% Calculates dice coefficients (and optionally mutual information) for
% whole brain, cortical, and subcortical regions. Now includes a 'zeroOption'
% parameter to handle zero-labeled vertices in different ways:
%
%   zeroOption = 1 -> Do nothing (zeros remain). partition_distance may fail if zeros exist.
%   zeroOption = 2 -> Mask out zeros before partition_distance (remove them).
%   zeroOption = 3 -> Relabel zeros to 'maxLabel+1', forming a new "dummy" network.

%% ------------------ HANDLE DEFAULTS & PATHS ------------------------------
if nargin < 9 || isempty(zeroOption)
    zeroOption = 1;  % Default = no special zero handling
end

corticalROIs = {'CORTEX_LEFT', 'CORTEX_RIGHT'};
subcorticalROIs = {'ACCUMBENS_LEFT','ACCUMBENS_RIGHT','AMYGDALA_LEFT','AMYGDALA_RIGHT','BRAIN_STEM',...
    'CAUDATE_LEFT','CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT','DIENCEPHALON_VENTRAL_RIGHT',...
    'CEREBELLUM_LEFT','CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT','HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT',...
    'PALLIDUM_RIGHT','PUTAMEN_LEFT','PUTAMEN_RIGHT','THALAMUS_LEFT','THALAMUS_RIGHT'};

% Check if fig_dir is provided as an input
if nargin < 8 || isempty(fig_dir)
    fig_dir = [BASEDIR '/figures/DiceCoefficient'];
end
mkdir(fig_dir);

% Add necessary paths
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
% for mutual information calc
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))

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

%% ------------------ LOAD FILE LISTS --------------------------------------
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

if length(dscalar_list1) ~= length(dscalar_list2)
    error('The two dscalar lists do not have the same number of files.');
end
num_permutations = length(dscalar_list1);

% Initialize results arrays
if ConfMap
    disp("Hard code warning, running ConfMap (2 networks?).") 
    num_networks = 1;
else
    disp("Hard code warning, running on network dscalar map (assuming 15 networks?).") 
    num_networks = 15;
end

DC_whole       = zeros(num_networks, num_permutations);
cDC_whole      = zeros(num_networks, num_permutations);
DC_cortical    = zeros(num_networks, num_permutations);
cDC_cortical   = zeros(num_networks, num_permutations);
DC_subcortical = zeros(num_networks, num_permutations);
cDC_subcortical= zeros(num_networks, num_permutations);

TruePositive_whole  = zeros(num_networks, num_permutations);
TrueNegative_whole  = zeros(num_networks, num_permutations);
FalsePositive_whole = zeros(num_networks, num_permutations);
FalseNegative_whole = zeros(num_networks, num_permutations);
PPV_whole           = zeros(num_networks, num_permutations);
NPV_whole           = zeros(num_networks, num_permutations);

TruePositive_cortical  = zeros(num_networks, num_permutations);
TrueNegative_cortical  = zeros(num_networks, num_permutations);
FalsePositive_cortical = zeros(num_networks, num_permutations);
FalseNegative_cortical = zeros(num_networks, num_permutations);
PPV_cortical           = zeros(num_networks, num_permutations);
NPV_cortical           = zeros(num_networks, num_permutations);

TruePositive_subcortical  = zeros(num_networks, num_permutations);
TrueNegative_subcortical  = zeros(num_networks, num_permutations);
FalsePositive_subcortical = zeros(num_networks, num_permutations);
FalseNegative_subcortical = zeros(num_networks, num_permutations);
PPV_subcortical           = zeros(num_networks, num_permutations);
NPV_subcortical           = zeros(num_networks, num_permutations);

%% ------------------ MAIN LOOP -------------------------------------------
for s = 1:num_permutations

    dscalar1 = dscalar_list1{s};
    dscalar2 = dscalar_list2{s};

    % Load data
    Mdscalar = cifti_read(dscalar1);
    Mdata = Mdscalar.cdata;  % Nx1
    Cdscalar = cifti_read(dscalar2);
    Cdata = Cdscalar.cdata;  % Nx1
    
    % Create masks
    cortical_mask    = create_region_mask(Mdscalar, corticalROIs);
    subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
    
    % Apply threshold
    if nargin >= 7 && ~isempty(threshold)
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
    end

    %% =============== ZERO HANDLING FOR WHOLE-BRAIN ===============
    % If we're going to use partition_distance on Mdata, Cdata:
    if ~ConfMap
        % Depending on zeroOption, do nothing/mask/relabel:
        [Mdata_whole, Cdata_whole] = handleZerosForPartition(Mdata, Cdata, zeroOption);
    else
        % ConfMap blocks do not typically call partition_distance,
        % so we skip specialized zero-handling.
        Mdata_whole = Mdata;
        Cdata_whole = Cdata;
    end
    
    %% ------------------ WHOLE-BRAIN ANALYSIS ---------------------
    if ConfMap
        disp("Running confmap code on WHOLE...")

        % Binarize confidence maps
        Mdata_bin = (Mdata > 0);
        Cdata_bin = (Cdata > 0);

        % cDC
        cDC_whole(:, s) = continuous_Dice_coefficient(Mdata, Cdata_bin);

        % DC
        DC_whole(:, s)  = Dice_coefficient(Mdata_bin, Cdata_bin);

        % map_network_changes
        [~, transition_matrix_full, ~] = map_network_changes(Mdata_bin, Cdata_bin);
        TruePositive_whole(:, s)  = transition_matrix_full(2,2);
        TrueNegative_whole(:, s)  = transition_matrix_full(1,1);
        FalseNegative_whole(:, s) = transition_matrix_full(2,1);
        FalsePositive_whole(:, s) = transition_matrix_full(1,2);

        PPV_whole(:, s) = TruePositive_whole(:, s) ./ (TruePositive_whole(:, s) + FalsePositive_whole(:, s));
        NPV_whole(:, s) = TrueNegative_whole(:, s) ./ (TrueNegative_whole(:, s) + FalseNegative_whole(:, s));

        % (Mutual information calls are commented out in your code)

    else
        disp("Running network dscalar code on WHOLE...")

        % We do partition_distance etc. with Mdata_whole, Cdata_whole
        muI_whole(1,s,1) = MutualInformation(Mdata_whole, Cdata_whole);
        [VIn_whole(1,s,1), MIn_whole(1,s,1)] = partition_distance(Mdata_whole, Cdata_whole);

        unique_networks_whole = unique([Mdata; Cdata]); 
        for i_whole = 1:length(unique_networks_whole)
            j_whole = unique_networks_whole(i_whole);

            dscalar1_net_whole = double(Mdata == j_whole);
            dscalar2_net_whole = double(Cdata == j_whole);

            cDC_whole(i_whole, s) = continuous_Dice_coefficient(dscalar1_net_whole, dscalar2_net_whole);

            % Binarize for DC
            binary_seg_result_whole = zeros(size(dscalar2_net_whole));
            binary_seg_result_whole(dscalar2_net_whole > 0.01) = 1;
            DC_whole(i_whole, s)  = Dice_coefficient(dscalar1_net_whole, binary_seg_result_whole);

            [~, transition_matrix_full, ~] = map_network_changes(dscalar1_net_whole, binary_seg_result_whole);
            TruePositive_whole(i_whole, s)  = transition_matrix_full(2,2);
            TrueNegative_whole(i_whole, s)  = transition_matrix_full(1,1);
            FalseNegative_whole(i_whole, s) = transition_matrix_full(2,1);
            FalsePositive_whole(i_whole, s) = transition_matrix_full(1,2);

            PPV_whole(i_whole, s) = TruePositive_whole(i_whole, s) ./ (TruePositive_whole(i_whole, s) + FalsePositive_whole(i_whole, s));
            NPV_whole(i_whole, s) = TrueNegative_whole(i_whole, s) ./ (TrueNegative_whole(i_whole, s) + FalseNegative_whole(i_whole, s));
        end
    end

    %% ------------------ CORTICAL ANALYSIS ------------------------
    Mdata_cortical = Mdata .* cortical_mask;
    Cdata_cortical = Cdata .* cortical_mask;

    if ConfMap
        disp("Running confmap code on CORTICAL...")

        % Binarize
        Mdata_cortical_bin = (Mdata_cortical > 0);
        Cdata_cortical_bin = (Cdata_cortical > 0);

        cDC_cortical(:, s) = continuous_Dice_coefficient(Mdata_cortical, Cdata_cortical_bin);
        DC_cortical(:, s)  = Dice_coefficient(Mdata_cortical_bin, Cdata_cortical_bin);

        [~, transition_matrix_full, ~] = map_network_changes(Mdata_cortical_bin, Cdata_cortical_bin);
        TruePositive_cortical(:, s)  = transition_matrix_full(2,2);
        TrueNegative_cortical(:, s)  = transition_matrix_full(1,1);
        FalseNegative_cortical(:, s) = transition_matrix_full(2,1);
        FalsePositive_cortical(:, s) = transition_matrix_full(1,2);

        PPV_cortical(:, s) = TruePositive_cortical(:, s) ./ (TruePositive_cortical(:, s) + FalsePositive_cortical(:, s));
        NPV_cortical(:, s) = TrueNegative_cortical(:, s) ./ (TrueNegative_cortical(:, s) + FalseNegative_cortical(:, s));

    else
        disp("Running network dscalar code on CORTICAL...")

        % If zeroOption=2 or 3, apply same zero handling for partition_distance:
        [Mdata_cortical_forPD, Cdata_cortical_forPD] = handleZerosForPartition(Mdata_cortical, Cdata_cortical, zeroOption);

        muI_cortical(1,s,1) = MutualInformation(Mdata_cortical_forPD, Cdata_cortical_forPD);
        [VIn_cortical(1,s,1), MIn_cortical(1,s,1)] = partition_distance(Mdata_cortical_forPD, Cdata_cortical_forPD);

        unique_networks_cortical = unique([Mdata_cortical; Cdata_cortical]);
        unique_networks_cortical(unique_networks_cortical == 0) = []; 

        for i_cortical = 1:length(unique_networks_cortical)
            j_cortical = unique_networks_cortical(i_cortical);

            d1_cortical = double(Mdata_cortical == j_cortical);
            d2_cortical = double(Cdata_cortical == j_cortical);

            cDC_cortical(i_cortical, s) = continuous_Dice_coefficient(d1_cortical, d2_cortical);

            bin_seg_result_cort = zeros(size(d2_cortical));
            bin_seg_result_cort(d2_cortical > 0.01) = 1;
            DC_cortical(i_cortical, s) = Dice_coefficient(d1_cortical, bin_seg_result_cort);

            [~, transition_matrix_full, ~] = map_network_changes(d1_cortical, bin_seg_result_cort);
            TruePositive_cortical(i_cortical, s)  = transition_matrix_full(2,2);
            TrueNegative_cortical(i_cortical, s)  = transition_matrix_full(1,1);
            FalseNegative_cortical(i_cortical, s) = transition_matrix_full(2,1);
            FalsePositive_cortical(i_cortical, s) = transition_matrix_full(1,2);

            PPV_cortical(i_cortical, s) = TruePositive_cortical(i_cortical, s) ./ (TruePositive_cortical(i_cortical, s) + FalsePositive_cortical(i_cortical, s));
            NPV_cortical(i_cortical, s) = TrueNegative_cortical(i_cortical, s) ./ (TrueNegative_cortical(i_cortical, s) + FalseNegative_cortical(i_cortical, s));
        end
    end

    %% ------------------ SUBCORTICAL ANALYSIS ---------------------
    Mdata_subcortical = Mdata .* subcortical_mask;
    Cdata_subcortical = Cdata .* subcortical_mask;

    if ConfMap
        disp("Running confmap code on SUBCORTICAL...")

        Mdata_subcortical_bin = (Mdata_subcortical > 0);
        Cdata_subcortical_bin = (Cdata_subcortical > 0);

        cDC_subcortical(:, s) = continuous_Dice_coefficient(Mdata_subcortical, Cdata_subcortical_bin);
        DC_subcortical(:, s)  = Dice_coefficient(Mdata_subcortical_bin, Cdata_subcortical_bin);

        [~, transition_matrix_full, ~] = map_network_changes(Mdata_subcortical_bin, Cdata_subcortical_bin);
        TruePositive_subcortical(:, s)  = transition_matrix_full(2,2);
        TrueNegative_subcortical(:, s)  = transition_matrix_full(1,1);
        FalseNegative_subcortical(:, s) = transition_matrix_full(2,1);
        FalsePositive_subcortical(:, s) = transition_matrix_full(1,2);

        PPV_subcortical(:, s) = TruePositive_subcortical(:, s) ./ (TruePositive_subcortical(:, s) + FalsePositive_subcortical(:, s));
        NPV_subcortical(:, s) = TrueNegative_subcortical(:, s) ./ (TrueNegative_subcortical(:, s) + FalseNegative_subcortical(:, s));

    else
        disp("Running network dscalar code on SUBCORTICAL...")

        [Mdata_subcortical_forPD, Cdata_subcortical_forPD] = handleZerosForPartition(Mdata_subcortical, Cdata_subcortical, zeroOption);

        muI_subcortical(1,s,1) = MutualInformation(Mdata_subcortical_forPD, Cdata_subcortical_forPD);
        [VIn_subcortical(1,s,1), MIn_subcortical(1,s,1)] = partition_distance(Mdata_subcortical_forPD, Cdata_subcortical_forPD);

        unique_networks_subcortical = unique([Mdata_subcortical; Cdata_subcortical]);
        unique_networks_subcortical(unique_networks_subcortical == 0) = [];

        for i_subcortical = 1:length(unique_networks_subcortical)
            j_subcortical = unique_networks_subcortical(i_subcortical);

            d1_subcort = double(Mdata_subcortical == j_subcortical);
            d2_subcort = double(Cdata_subcortical == j_subcortical);

            cDC_subcortical(i_subcortical, s) = continuous_Dice_coefficient(d1_subcort, d2_subcort);

            bin_seg_result_sub = zeros(size(d2_subcort));
            bin_seg_result_sub(d2_subcort > 0.01) = 1;
            DC_subcortical(i_subcortical, s) = Dice_coefficient(d1_subcort, bin_seg_result_sub);

            [~, transition_matrix_full, ~] = map_network_changes(d1_subcort, bin_seg_result_sub);
            TruePositive_subcortical(i_subcortical, s)  = transition_matrix_full(2,2);
            TrueNegative_subcortical(i_subcortical, s)  = transition_matrix_full(1,1);
            FalseNegative_subcortical(i_subcortical, s) = transition_matrix_full(2,1);
            FalsePositive_subcortical(i_subcortical, s) = transition_matrix_full(1,2);

            PPV_subcortical(i_subcortical, s) = TruePositive_subcortical(i_subcortical, s) ./ (TruePositive_subcortical(i_subcortical, s) + FalsePositive_subcortical(i_subcortical, s));
            NPV_subcortical(i_subcortical, s) = TrueNegative_subcortical(i_subcortical, s) ./ (TrueNegative_subcortical(i_subcortical, s) + FalseNegative_subcortical(i_subcortical, s));
        end
    end
end

%% ------------------ AVERAGE & SAVE RESULTS ------------------------------
% (Your existing averaging logic remains unchanged below)
% ...
% (Same for writematrix calls, also unchanged.)
% -------------------------------------------------------------------------
% (Start of the block you already have)
% Calculate averages and standard deviations across permutations if more than one permutation
if num_permutations > 1
    avg_muI_whole = mean(muI_whole, 2); 
    std_muI_whole = std(muI_whole); 
    avg_VIn_whole = mean(VIn_whole, 2); 
    std_VIn_whole = std(VIn_whole);     
    avg_MIn_whole = mean(MIn_whole, 2); 
    std_MIn_whole = std(MIn_whole);     
    avg_cDC_whole = mean(cDC_whole, 2);
    std_cDC_whole = std(cDC_whole, 0, 2);
    avg_DC_whole = mean(DC_whole, 2);
    std_DC_whole = std(DC_whole, 0, 2);
    
    avg_muI_cortical = mean(muI_cortical, 2); 
    std_muI_cortical = std(muI_cortical); 
    avg_VIn_cortical = mean(VIn_cortical, 2); 
    std_VIn_cortical = std(VIn_cortical);     
    avg_MIn_cortical = mean(MIn_cortical, 2); 
    std_MIn_cortical = std(MIn_cortical);     
    avg_cDC_cortical = mean(cDC_cortical, 2);
    std_cDC_cortical = std(cDC_cortical, 0, 2);
    avg_DC_cortical = mean(DC_cortical, 2);
    std_DC_cortical = std(DC_cortical, 0, 2);
    
    avg_muI_subcortical = mean(muI_subcortical, 2); 
    std_muI_subcortical = std(muI_subcortical); 
    avg_VIn_subcortical = mean(VIn_subcortical, 2); 
    std_VIn_subcortical = std(VIn_subcortical);     
    avg_MIn_subcortical = mean(MIn_subcortical, 2); 
    std_MIn_subcortical = std(MIn_subcortical);     
    avg_cDC_subcortical = mean(cDC_subcortical, 2);
    std_cDC_subcortical = std(cDC_subcortical, 0, 2);
    avg_DC_subcortical = mean(DC_subcortical, 2);
    std_DC_subcortical = std(DC_subcortical, 0, 2);
else
    % (Single-permutation => no averaging needed.)
    avg_muI_whole = muI_whole; 
    std_muI_whole = zeros(size(muI_whole)); 
    avg_VIn_whole = VIn_whole; 
    std_VIn_whole = zeros(size(VIn_whole));     
    avg_MIn_whole = MIn_whole; 
    std_MIn_whole = zeros(size(MIn_whole));     
    avg_cDC_whole = cDC_whole;
    std_cDC_whole = zeros(size(cDC_whole));
    avg_DC_whole = DC_whole;
    std_DC_whole = zeros(size(DC_whole));
    
    avg_muI_cortical = muI_cortical; 
    std_muI_cortical = zeros(size(muI_cortical)); 
    avg_VIn_cortical = VIn_cortical; 
    std_VIn_cortical = zeros(size(VIn_cortical));     
    avg_MIn_cortical = MIn_cortical; 
    std_MIn_cortical = zeros(size(MIn_cortical));     
    avg_cDC_cortical = cDC_cortical;
    std_cDC_cortical = zeros(size(cDC_cortical));
    avg_DC_cortical = DC_cortical;
    std_DC_cortical = zeros(size(DC_cortical));
    
    avg_muI_subcortical = muI_subcortical; 
    std_muI_subcortical = zeros(size(muI_subcortical)); 
    avg_VIn_subcortical = VIn_subcortical; 
    std_VIn_subcortical = zeros(size(VIn_subcortical));     
    avg_MIn_subcortical = MIn_subcortical; 
    std_MIn_subcortical = zeros(size(MIn_subcortical));     
    avg_cDC_subcortical = cDC_subcortical;
    std_cDC_subcortical = zeros(size(cDC_subcortical));
    avg_DC_subcortical = DC_subcortical;
    std_DC_subcortical = zeros(size(DC_subcortical));
end

network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
mkdir(network_folder);


% Whole-brain results
writematrix(avg_DC_whole, fullfile(network_folder, 'Average_DiceCoefficient_whole.txt'));
writematrix(std_DC_whole, fullfile(network_folder, 'STDEV_DiceCoefficient_whole.txt'));
writematrix(DC_whole, fullfile(network_folder, 'DiceCoefficientsMatrix_whole.txt'));
writematrix(avg_cDC_whole, fullfile(network_folder, 'Average_continuousDiceCoefficient_whole.txt'));
writematrix(std_cDC_whole, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_whole.txt'));
writematrix(cDC_whole, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_whole.txt'));
writematrix(TruePositive_whole, fullfile(network_folder, 'TruePositive_whole.txt'));
writematrix(TrueNegative_whole, fullfile(network_folder, 'TrueNegative_whole.txt'));
writematrix(FalsePositive_whole, fullfile(network_folder, 'FalsePositive_whole.txt'));
writematrix(FalseNegative_whole, fullfile(network_folder, 'FalseNegative_whole.txt'));
writematrix(PPV_whole, fullfile(network_folder, 'PPV_whole.txt'));
writematrix(NPV_whole, fullfile(network_folder, 'NPV_whole.txt'));
writematrix(avg_muI_whole, fullfile(network_folder, 'Average_muI_whole.txt'));
writematrix(std_muI_whole, fullfile(network_folder, 'STDEV_muI_whole.txt'));
writematrix(muI_whole, fullfile(network_folder, 'muI_Matrix_whole.txt'));
writematrix(avg_VIn_whole, fullfile(network_folder, 'Average_VIn_whole.txt'));
writematrix(std_VIn_whole, fullfile(network_folder, 'STDEV_VIn_whole.txt'));
writematrix(VIn_whole, fullfile(network_folder, 'VIn_Matrix_whole.txt'));
writematrix(avg_MIn_whole, fullfile(network_folder, 'Average_MIn_whole.txt'));
writematrix(std_MIn_whole, fullfile(network_folder, 'STDEV_MIn_whole.txt'));
writematrix(MIn_whole, fullfile(network_folder, 'MIn_Matrix_whole.txt'));

% Cortical results
writematrix(avg_DC_cortical, fullfile(network_folder, 'Average_DiceCoefficient_cortical.txt'));
writematrix(std_DC_cortical, fullfile(network_folder, 'STDEV_DiceCoefficient_cortical.txt'));
writematrix(DC_cortical, fullfile(network_folder, 'DiceCoefficientsMatrix_cortical.txt'));
writematrix(avg_cDC_cortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_cortical.txt'));
writematrix(std_cDC_cortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_cortical.txt'));
writematrix(cDC_cortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_cortical.txt'));
writematrix(TruePositive_cortical, fullfile(network_folder, 'TruePositive_cortical.txt'));
writematrix(TrueNegative_cortical, fullfile(network_folder, 'TrueNegative_cortical.txt'));
writematrix(FalsePositive_cortical, fullfile(network_folder, 'FalsePositive_cortical.txt'));
writematrix(FalseNegative_cortical, fullfile(network_folder, 'FalseNegative_cortical.txt'));
writematrix(PPV_cortical, fullfile(network_folder, 'PPV_cortical.txt'));
writematrix(NPV_cortical, fullfile(network_folder, 'NPV_cortical.txt'));
writematrix(avg_muI_cortical, fullfile(network_folder, 'Average_muI_cortical.txt'));
writematrix(std_muI_cortical, fullfile(network_folder, 'STDEV_muI_cortical.txt'));
writematrix(muI_cortical, fullfile(network_folder, 'muI_Matrix_cortical.txt'));
writematrix(avg_VIn_cortical, fullfile(network_folder, 'Average_VIn_cortical.txt'));
writematrix(std_VIn_cortical, fullfile(network_folder, 'STDEV_VIn_cortical.txt'));
writematrix(VIn_cortical, fullfile(network_folder, 'VIn_Matrix_cortical.txt'));
writematrix(avg_MIn_cortical, fullfile(network_folder, 'Average_MIn_cortical.txt'));
writematrix(std_MIn_cortical, fullfile(network_folder, 'STDEV_MIn_cortical.txt'));
writematrix(MIn_cortical, fullfile(network_folder, 'MIn_Matrix_cortical.txt'));

% Subcortical results
writematrix(avg_DC_subcortical, fullfile(network_folder, 'Average_DiceCoefficient_subcortical.txt'));
writematrix(std_DC_subcortical, fullfile(network_folder, 'STDEV_DiceCoefficient_subcortical.txt'));
writematrix(DC_subcortical, fullfile(network_folder, 'DiceCoefficientsMatrix_subcortical.txt'));
writematrix(avg_cDC_subcortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_subcortical.txt'));
writematrix(std_cDC_subcortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_subcortical.txt'));
writematrix(cDC_subcortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_subcortical.txt'));
writematrix(TruePositive_subcortical, fullfile(network_folder, 'TruePositive_subcortical.txt'));
writematrix(TrueNegative_subcortical, fullfile(network_folder, 'TrueNegative_subcortical.txt'));
writematrix(FalsePositive_subcortical, fullfile(network_folder, 'FalsePositive_subcortical.txt'));
writematrix(FalseNegative_subcortical, fullfile(network_folder, 'FalseNegative_subcortical.txt'));
writematrix(PPV_subcortical, fullfile(network_folder, 'PPV_subcortical.txt'));
writematrix(NPV_subcortical, fullfile(network_folder, 'NPV_subcortical.txt'));
writematrix(avg_muI_subcortical, fullfile(network_folder, 'Average_muI_subcortical.txt'));
writematrix(std_muI_subcortical, fullfile(network_folder, 'STDEV_muI_subcortical.txt'));
writematrix(muI_subcortical, fullfile(network_folder, 'muI_Matrix_subcortical.txt'));
writematrix(avg_VIn_subcortical, fullfile(network_folder, 'Average_VIn_subcortical.txt'));
writematrix(std_VIn_subcortical, fullfile(network_folder, 'STDEV_VIn_subcortical.txt'));
writematrix(VIn_subcortical, fullfile(network_folder, 'VIn_Matrix_subcortical.txt'));
writematrix(avg_MIn_subcortical, fullfile(network_folder, 'Average_MIn_subcortical.txt'));
writematrix(std_MIn_subcortical, fullfile(network_folder, 'STDEV_MIn_subcortical.txt'));
writematrix(MIn_subcortical, fullfile(network_folder, 'MIn_Matrix_subcortical.txt'));

end

%% ------------------ HELPER FUNCTION FOR ZERO HANDLING --------------------
function [Cx_out, Cy_out] = handleZerosForPartition(Cx, Cy, zeroOption)
% Applies one of three methods to handle zeros in Cx and Cy
% for usage with partition_distance or other calls:
%
%   zeroOption = 1: do nothing
%   zeroOption = 2: remove zero-labeled vertices from both vectors
%   zeroOption = 3: relabel zeros to "maxVal+1"

switch zeroOption
    case 1
        % No action
        Cx_out = Cx;
        Cy_out = Cy;
    case 2
        % Remove zero-labeled indices from both
        mask = (Cx ~= 0) & (Cy ~= 0);
        Cx_out = Cx(mask);
        Cy_out = Cy(mask);
    case 3
        % Relabel zeros to new label
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