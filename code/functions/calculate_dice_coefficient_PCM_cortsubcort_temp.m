function calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, thresholdTarget, fig_dir)

corticalROIs = {'CORTEX_LEFT', 'CORTEX_RIGHT'};
subcorticalROIs = {'ACCUMBENS_LEFT', 'ACCUMBENS_RIGHT','AMYGDALA_LEFT', 'AMYGDALA_RIGHT','BRAIN_STEM','CAUDATE_LEFT', 'CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT', 'DIENCEPHALON_VENTRAL_RIGHT','CEREBELLUM_LEFT', 'CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT', 'HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT', 'PALLIDUM_RIGHT','PUTAMEN_LEFT', 'PUTAMEN_RIGHT','THALAMUS_LEFT', 'THALAMUS_RIGHT'};

% Check if fig_dir is provided as an input
if nargin < 8 || isempty(fig_dir)
    fig_dir = [BASEDIR '/figures/DiceCoefficient'];
end

mkdir(fig_dir);

% Add necessary paths
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
%for mutual information calc
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))

% Load the dscalar file lists
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

% Check if the lists have the same length
if length(dscalar_list1) ~= length(dscalar_list2)
    error('The two dscalar lists do not have the same number of files.');
end
num_permutations = length(dscalar_list1); % Total number of comparisons

% Initialize results arrays
if ConfMap
    disp("Hard code warning,running ConfMap assuming 2 networks") 

    num_networks = 1; % Assuming there are 15 networks
else
   disp("Hard code warning,running on network dscalar map assuming 15 networks") 

    num_networks = 15; % Assuming there are 15 networks
end
DC_whole = zeros(num_networks, num_permutations);
cDC_whole = zeros(num_networks, num_permutations);
DC_cortical = zeros(num_networks, num_permutations);
cDC_cortical = zeros(num_networks, num_permutations);
DC_subcortical = zeros(num_networks, num_permutations);
cDC_subcortical = zeros(num_networks, num_permutations);

TruePositive_whole = zeros(num_networks, num_permutations);
TrueNegative_whole = zeros(num_networks, num_permutations);
FalsePositive_whole = zeros(num_networks, num_permutations);
FalseNegative_whole = zeros(num_networks, num_permutations);
PPV_whole = zeros(num_networks, num_permutations);
NPV_whole = zeros(num_networks, num_permutations);

TruePositive_cortical = zeros(num_networks, num_permutations);
TrueNegative_cortical = zeros(num_networks, num_permutations);
FalsePositive_cortical = zeros(num_networks, num_permutations);
FalseNegative_cortical = zeros(num_networks, num_permutations);
PPV_cortical = zeros(num_networks, num_permutations);
NPV_cortical = zeros(num_networks, num_permutations);

TruePositive_subcortical = zeros(num_networks, num_permutations);
TrueNegative_subcortical = zeros(num_networks, num_permutations);
FalsePositive_subcortical = zeros(num_networks, num_permutations);
FalseNegative_subcortical = zeros(num_networks, num_permutations);
PPV_subcortical = zeros(num_networks, num_permutations);
NPV_subcortical = zeros(num_networks, num_permutations);

for s = 1:num_permutations

    dscalar1 = dscalar_list1{s};
    dscalar2 = dscalar_list2{s};

    % Load data and perform analysis
    Mdscalar = cifti_read(dscalar1);
    Mdata = Mdscalar.cdata;

    Cdscalar = cifti_read(dscalar2);
    Cdata = Cdscalar.cdata;
    
    % Create masks
    cortical_mask = create_region_mask(Mdscalar, corticalROIs);
    subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
    
    % Apply threshold based on the thresholdTarget
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
                error('Invalid thresholdTarget value. Choose ''both'', ''dscalar1'', or ''dscalar2''.');
        end
    end

    % Whole-brain analysis
    if ConfMap
        disp("running confmap code on whole")
        muI_whole=0;
        VIn_whole=0;
        MIn_whole=0;
        %muI_whole(1,s,1) = MutualInformation(Mdata, Cdata); %Mutual information
        %[VIn_whole(1,s,1), MIn_whole(1,s,1)] = partition_distance(Mdata, Cdata); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

        % Binarize the confidence maps
        Mdata_bin = Mdata > 0;
        Cdata_bin = Cdata > 0;

        % Calculate continuous Dice coefficient (cDC)
        cDC_whole(:, s) = continuous_Dice_coefficient(Mdata, Cdata_bin);

        % Calculate Dice coefficient (DC)
        DC_whole(:, s) = Dice_coefficient(Mdata_bin, Cdata_bin);

        % Get True positive and negatives 
        [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_bin, Cdata_bin);

        TruePositive_whole(:, s) = transition_matrix_full(2,2);
        TrueNegative_whole(:, s) = transition_matrix_full(1,1);
        FalseNegative_whole(:, s) = transition_matrix_full(2,1);
        FalsePositive_whole(:, s) = transition_matrix_full(1,2);

        % Positive Predictive Value
        PPV_whole(:, s) = TruePositive_whole(:, s) / (TruePositive_whole(:, s) + FalsePositive_whole(:, s));
        
        % Negative Predictive Value
        NPV_whole(:, s) = TrueNegative_whole(:, s) / (TrueNegative_whole(:, s) + FalseNegative_whole(:, s));
    else
        disp("running network dscalar code on whole")

        unique_networks_whole = unique([Mdata; Cdata]);
        %min=1;
        
        muI_whole(1,s,1) = MutualInformation(Mdata, Cdata); %Mutual information
        %[VIn_whole(1,s,1), MIn_whole(1,s,1)] = partition_distance(Mdata, Cdata); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)
        Mdatatmp=Mdata+1;
        Cdatatmp=Cdata+1;

        [VIn_whole(1,s,1), MIn_whole(1,s,1)] = partition_distance(Mdatatmp, Cdatatmp); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

        % Initialize a cell array to store the vectors
        network_vectors_dscalar1_whole = cell(length(unique_networks_whole), 1);
        network_vectors_dscalar2_whole = cell(length(unique_networks_whole), 1);

        for i_whole = 1:length(unique_networks_whole)
            j_whole = unique_networks_whole(i_whole);
            % Create a logical vector for the current network
            dscalar1_net_whole = (Mdata == j_whole);
            
            % Convert logical vector to double (0's and 1's)
            dscalar1_net_whole = double(dscalar1_net_whole);
            
            % Store the vector in the cell array
            network_vectors_dscalar1_whole{i_whole} = dscalar1_net_whole;
            
            dscalar2_net_whole = (Cdata == j_whole);
            
            % Convert logical vector to double (0's and 1's)
            dscalar2_net_whole = double(dscalar2_net_whole);
            
            % Store the vector in the cell array
            network_vectors_dscalar2_whole{i_whole} = dscalar2_net_whole;

            cDC_whole(i_whole, s) = continuous_Dice_coefficient(dscalar1_net_whole, dscalar2_net_whole);
        
            % Binarize segmentation result
            binary_segmentation_result_whole = zeros(size(dscalar2_net_whole));
            binary_segmentation_result_whole(dscalar2_net_whole > 0.01) = 1;
        
            % Compute Dice coefficient
            DC_whole(i_whole, s) = Dice_coefficient(dscalar1_net_whole, binary_segmentation_result_whole);

            % Get True positive and negatives 
            [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net_whole, binary_segmentation_result_whole);

            TruePositive_whole(i_whole, s) = transition_matrix_full(2,2);
            TrueNegative_whole(i_whole, s) = transition_matrix_full(1,1);
            FalseNegative_whole(i_whole, s) = transition_matrix_full(2,1);
            FalsePositive_whole(i_whole, s) = transition_matrix_full(1,2);

            % Positive Predictive Value
            PPV_whole(i_whole, s) = TruePositive_whole(i_whole, s) / (TruePositive_whole(i_whole, s) + FalsePositive_whole(i_whole, s));
            
            % Negative Predictive Value
            NPV_whole(i_whole, s) = TrueNegative_whole(i_whole, s) / (TrueNegative_whole(i_whole, s) + FalseNegative_whole(i_whole, s));
        end
    end

    % Cortical analysis
    Mdata_cortical = Mdata .* cortical_mask;
    Cdata_cortical = Cdata .* cortical_mask;
    
    if ConfMap
        disp("running confmap code on cortical")
        muI_cortical= 0; %Mutual information
        VIn_cortical=0;
        MIn_cortical=0;
        % Binarize the confidence maps
        Mdata_cortical_bin = Mdata_cortical > 0;
        Cdata_cortical_bin = Cdata_cortical > 0;

        % Calculate continuous Dice coefficient (cDC)
        cDC_cortical(:, s) = continuous_Dice_coefficient(Mdata_cortical, Cdata_cortical_bin);

        % Calculate Dice coefficient (DC)
        DC_cortical(:, s) = Dice_coefficient(Mdata_cortical_bin, Cdata_cortical_bin);

        % Get True positive and negatives 
        [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_cortical_bin, Cdata_cortical_bin);

        TruePositive_cortical(:, s) = transition_matrix_full(2,2);
        TrueNegative_cortical(:, s) = transition_matrix_full(1,1);
        FalseNegative_cortical(:, s) = transition_matrix_full(2,1);
        FalsePositive_cortical(:, s) = transition_matrix_full(1,2);

        % Positive Predictive Value
        PPV_cortical(:, s) = TruePositive_cortical(:, s) / (TruePositive_cortical(:, s) + FalsePositive_cortical(:, s));
        
        % Negative Predictive Value
        NPV_cortical(:, s) = TrueNegative_cortical(:, s) / (TrueNegative_cortical(:, s) + FalseNegative_cortical(:, s));
    else
        disp("running network dscalar code on cortical")
        nonZero_Mdata_cortical=Mdata_cortical;
        nonZero_Mdata_cortical(nonZero_Mdata_cortical == 0) = []; % Exclude zeros

        nonZero_Cdata_cortical=Cdata_cortical;
        nonZero_Cdata_cortical(nonZero_Cdata_cortical == 0) = []; % Exclude zeros

        muI_cortical(1,s,1) = MutualInformation(nonZero_Mdata_cortical, nonZero_Cdata_cortical); %Mutual information
        %[VIn_cortical(1,s,1), MIn_cortical(1,s,1)] = partition_distance(nonZero_Mdata_cortical, nonZero_Cdata_cortical); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)
        nonZero_Mdata_corticaltmp=nonZero_Mdata_cortical+1;
        nonZero_Cdata_corticaltmp=nonZero_Cdata_cortical+1;

        [VIn_cortical(1,s,1), MIn_cortical(1,s,1)] = partition_distance(nonZero_Mdata_corticaltmp, nonZero_Cdata_corticaltmp); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

        unique_networks_cortical = unique([Mdata_cortical; Cdata_cortical]);
        unique_networks_cortical(unique_networks_cortical == 0) = []; % Exclude zeros

        % Initialize a cell array to store the vectors
        network_vectors_dscalar1_cortical = cell(length(unique_networks_cortical), 1);
        network_vectors_dscalar2_cortical = cell(length(unique_networks_cortical), 1);

        for i_cortical = 1:length(unique_networks_cortical)
            j_cortical = unique_networks_cortical(i_cortical);
            % Create a logical vector for the current network
            dscalar1_net_cortical = (Mdata_cortical == j_cortical);
            
            % Convert logical vector to double (0's and 1's)
            dscalar1_net_cortical = double(dscalar1_net_cortical);
            
            % Store the vector in the cell array
            network_vectors_dscalar1_cortical{i_cortical} = dscalar1_net_cortical;
            
            dscalar2_net_cortical = (Cdata_cortical == j_cortical);
            
            % Convert logical vector to double (0's and 1's)
            dscalar2_net_cortical = double(dscalar2_net_cortical);
            
            % Store the vector in the cell array
            network_vectors_dscalar2_cortical{i_cortical} = dscalar2_net_cortical;

            cDC_cortical(i_cortical, s) = continuous_Dice_coefficient(dscalar1_net_cortical, dscalar2_net_cortical);
        
            % Binarize segmentation result
            binary_segmentation_result_cortical = zeros(size(dscalar2_net_cortical));
            binary_segmentation_result_cortical(dscalar2_net_cortical > 0.01) = 1;
        
            % Compute Dice coefficient
            DC_cortical(i_cortical, s) = Dice_coefficient(dscalar1_net_cortical, binary_segmentation_result_cortical);

            % Get True positive and negatives 
            [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net_cortical, binary_segmentation_result_cortical);

            TruePositive_cortical(i_cortical, s) = transition_matrix_full(2,2);
            TrueNegative_cortical(i_cortical, s) = transition_matrix_full(1,1);
            FalseNegative_cortical(i_cortical, s) = transition_matrix_full(2,1);
            FalsePositive_cortical(i_cortical, s) = transition_matrix_full(1,2);

            % Positive Predictive Value
            PPV_cortical(i_cortical, s) = TruePositive_cortical(i_cortical, s) / (TruePositive_cortical(i_cortical, s) + FalsePositive_cortical(i_cortical, s));
            
            % Negative Predictive Value
            NPV_cortical(i_cortical, s) = TrueNegative_cortical(i_cortical, s) / (TrueNegative_cortical(i_cortical, s) + FalseNegative_cortical(i_cortical, s));
        end
    end

    % Subcortical analysis
    Mdata_subcortical = Mdata .* subcortical_mask;
    Cdata_subcortical = Cdata .* subcortical_mask;
    
    if ConfMap
        disp("running confmap code on subcortical")
        muI_subcortical= 0; %Mutual information
        VIn_subcortical=0;
        MIn_subcortical=0;
        % Binarize the confidence maps
        Mdata_subcortical_bin = Mdata_subcortical > 0;
        Cdata_subcortical_bin = Cdata_subcortical > 0;

        % Calculate continuous Dice coefficient (cDC)
        cDC_subcortical(:, s) = continuous_Dice_coefficient(Mdata_subcortical, Cdata_subcortical_bin);

        % Calculate Dice coefficient (DC)
        DC_subcortical(:, s) = Dice_coefficient(Mdata_subcortical_bin, Cdata_subcortical_bin);

        % Get True positive and negatives 
        [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_subcortical_bin, Cdata_subcortical_bin);

        TruePositive_subcortical(:, s) = transition_matrix_full(2,2);
        TrueNegative_subcortical(:, s) = transition_matrix_full(1,1);
        FalseNegative_subcortical(:, s) = transition_matrix_full(2,1);
        FalsePositive_subcortical(:, s) = transition_matrix_full(1,2);

        % Positive Predictive Value
        PPV_subcortical(:, s) = TruePositive_subcortical(:, s) / (TruePositive_subcortical(:, s) + FalsePositive_subcortical(:, s));
        
        % Negative Predictive Value
        NPV_subcortical(:, s) = TrueNegative_subcortical(:, s) / (TrueNegative_subcortical(:, s) + FalseNegative_subcortical(:, s));
    else
        disp("running network dscalar code on subcortical")
        nonZero_Mdata_subcortical=Mdata_subcortical;
        nonZero_Mdata_subcortical(nonZero_Mdata_subcortical == 0) = []; % Exclude zeros

        nonZero_Cdata_subcortical=Cdata_subcortical;
        nonZero_Cdata_subcortical(nonZero_Cdata_subcortical == 0) = []; % Exclude zeros

        muI_subcortical(1,s,1) = MutualInformation(nonZero_Mdata_subcortical, nonZero_Cdata_subcortical); %Mutual information
        [VIn_subcortical(1,s,1), MIn_subcortical(1,s,1)] = partition_distance(nonZero_Mdata_subcortical, nonZero_Cdata_subcortical); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

        %muI_subcortical(1,s,1) = MutualInformation(Mdata_subcortical, Cdata_subcortical); %Mutual information
        %[VIn_subcortical(1,s,1), MIn_subcortical(1,s,1)] = partition_distance(Mdata_subcortical, Cdata_subcortical); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

        unique_networks_subcortical = unique([Mdata_subcortical; Cdata_subcortical]);
        unique_networks_subcortical(unique_networks_subcortical == 0) = []; % Exclude zeros

        % Initialize a cell array to store the vectors
        network_vectors_dscalar1_subcortical = cell(length(unique_networks_subcortical), 1);
        network_vectors_dscalar2_subcortical = cell(length(unique_networks_subcortical), 1);

        for i_subcortical = 1:length(unique_networks_subcortical)
            j_subcortical = unique_networks_subcortical(i_subcortical);
            % Create a logical vector for the current network
            dscalar1_net_subcortical = (Mdata_subcortical == j_subcortical);
            
            % Convert logical vector to double (0's and 1's)
            dscalar1_net_subcortical = double(dscalar1_net_subcortical);
            
            % Store the vector in the cell array
            network_vectors_dscalar1_subcortical{i_subcortical} = dscalar1_net_subcortical;
            
            dscalar2_net_subcortical = (Cdata_subcortical == j_subcortical);
            
            % Convert logical vector to double (0's and 1's)
            dscalar2_net_subcortical = double(dscalar2_net_subcortical);
            
            % Store the vector in the cell array
            network_vectors_dscalar2_subcortical{i_subcortical} = dscalar2_net_subcortical;

            cDC_subcortical(i_subcortical, s) = continuous_Dice_coefficient(dscalar1_net_subcortical, dscalar2_net_subcortical);
        
            % Binarize segmentation result
            binary_segmentation_result_subcortical = zeros(size(dscalar2_net_subcortical));
            binary_segmentation_result_subcortical(dscalar2_net_subcortical > 0.01) = 1;
        
            % Compute Dice coefficient
            DC_subcortical(i_subcortical, s) = Dice_coefficient(dscalar1_net_subcortical, binary_segmentation_result_subcortical);

            % Get True positive and negatives 
            [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net_subcortical, binary_segmentation_result_subcortical);

            TruePositive_subcortical(i_subcortical, s) = transition_matrix_full(2,2);
            TrueNegative_subcortical(i_subcortical, s) = transition_matrix_full(1,1);
            FalseNegative_subcortical(i_subcortical, s) = transition_matrix_full(2,1);
            FalsePositive_subcortical(i_subcortical, s) = transition_matrix_full(1,2);

            % Positive Predictive Value
            PPV_subcortical(i_subcortical, s) = TruePositive_subcortical(i_subcortical, s) / (TruePositive_subcortical(i_subcortical, s) + FalsePositive_subcortical(i_subcortical, s));
            
            % Negative Predictive Value
            NPV_subcortical(i_subcortical, s) = TrueNegative_subcortical(i_subcortical, s) / (TrueNegative_subcortical(i_subcortical, s) + FalseNegative_subcortical(i_subcortical, s));
        end
    end
end

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
    avg_muI_whole = muI_whole; 
    std_muI_whole = zeros(size(muI_whole)); 
    avg_VIn_whole = VIn_whole; 
    std_VIn_whole = zeros(size(VIn_whole));     
    avg_MIn_whole = MIn_whole; 
    std_MIn_whole = zeros(size(MIn_whole));     
    avg_cDC_whole = cDC_whole;
    std_cDC_whole = zeros(size(cDC_whole));  % Standard deviation is zero when there's only one permutation
    avg_DC_whole = DC_whole;
    std_DC_whole = zeros(size(DC_whole));  % Standard deviation is zero when there's only one permutation
    
    avg_muI_cortical = muI_cortical; 
    std_muI_cortical = zeros(size(muI_cortical)); 
    avg_VIn_cortical = VIn_cortical; 
    std_VIn_cortical = zeros(size(VIn_cortical));     
    avg_MIn_cortical = MIn_cortical; 
    std_MIn_cortical = zeros(size(MIn_cortical));     
    avg_cDC_cortical = cDC_cortical;
    std_cDC_cortical = zeros(size(cDC_cortical));  % Standard deviation is zero when there's only one permutation
    avg_DC_cortical = DC_cortical;
    std_DC_cortical = zeros(size(DC_cortical));  % Standard deviation is zero when there's only one permutation
    
    avg_muI_subcortical = muI_subcortical; 
    std_muI_subcortical = zeros(size(muI_subcortical)); 
    avg_VIn_subcortical = VIn_subcortical; 
    std_VIn_subcortical = zeros(size(VIn_subcortical));     
    avg_MIn_subcortical = MIn_subcortical; 
    std_MIn_subcortical = zeros(size(MIn_subcortical));     
    avg_cDC_subcortical = cDC_subcortical;
    std_cDC_subcortical = zeros(size(cDC_subcortical));  % Standard deviation is zero when there's only one permutation
    avg_DC_subcortical = DC_subcortical;
    std_DC_subcortical = zeros(size(DC_subcortical));  % Standard deviation is zero when there's only one permutation
end

% Write results to files
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
% if num_permutations > 1
%     avg_muI_whole=mean(muI_whole,2); 
%     std_muI_whole=std(muI_whole,2); 
%     avg_VIn_whole=mean(VIn_whole,2); 
%     std_VIn_whole=std(VIn_whole,2);     
%     avg_MIn_whole=mean(MIn_whole,2); 
%     std_MIn_whole=std(MIn_whole,2);     
%     avg_cDC_whole = mean(cDC_whole, 2);
%     std_cDC_whole = std(cDC_whole, 0, 2);
%     avg_DC_whole = mean(DC_whole, 2);
%     std_DC_whole = std(DC_whole, 0, 2);
% 
%     avg_muI_cortical=mean(muI_cortical,2); 
%     std_muI_cortical=std(muI_cortical,2); 
%     avg_VIn_cortical=mean(VIn_cortical,2); 
%     std_VIn_cortical=std(VIn_cortical,2);     
%     avg_MIn_cortical=mean(MIn_cortical,2); 
%     std_MIn_cortical=std(MIn_cortical,2);     
%     avg_cDC_cortical = mean(cDC_cortical, 2);
%     std_cDC_cortical = std(cDC_cortical, 0, 2);
%     avg_DC_cortical = mean(DC_cortical, 2);
%     std_DC_cortical = std(DC_cortical, 0, 2);
% 
%     avg_muI_subcortical=mean(muI_subcortical,2); 
%     std_muI_subcortical=std(muI_subcortical,2); 
%     avg_VIn_subcortical=mean(VIn_subcortical,2); 
%     std_VIn_subcortical=std(VIn_subcortical,2);     
%     avg_MIn_subcortical=mean(MIn_subcortical,2); 
%     std_MIn_subcortical=std(MIn_subcortical,2);     
%     avg_cDC_subcortical = mean(cDC_subcortical, 2);
%     std_cDC_subcortical = std(cDC_subcortical, 0, 2);
%     avg_DC_subcortical = mean(DC_subcortical, 2);
%     std_DC_subcortical = std(DC_subcortical, 0, 2);
% else
%     avg_muI_whole=muI_whole; 
%     std_muI_whole=zeros(size(muI_whole)); 
%     avg_VIn_whole=VIn_whole; 
%     std_VIn_whole=zeros(size(VIn_whole));     
%     avg_MIn_whole=MIn_whole; 
%     std_MIn_whole=zeros(size(MIn_whole));     
%     avg_cDC_whole = cDC_whole;
%     std_cDC_whole = zeros(size(cDC_whole));  % Standard deviation is zero when there's only one permutation
%     avg_DC_whole = DC_whole;
%     std_DC_whole = zeros(size(DC_whole));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_cortical = cDC_cortical;
%     std_cDC_cortical = zeros(size(cDC_cortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_cortical = DC_cortical;
%     std_DC_cortical = zeros(size(DC_cortical));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_subcortical = cDC_subcortical;
%     std_cDC_subcortical = zeros(size(cDC_subcortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_subcortical = DC_subcortical;
%     std_DC_subcortical = zeros(size(DC_subcortical));  % Standard deviation is zero when there's only one permutation
% end
% 
% % Write results to files
% network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
% mkdir(network_folder);
% 
% % Whole-brain results
% writematrix(avg_DC_whole, fullfile(network_folder, 'Average_DiceCoefficient_whole.txt'));
% writematrix(std_DC_whole, fullfile(network_folder, 'STDEV_DiceCoefficient_whole.txt'));
% writematrix(DC_whole, fullfile(network_folder, 'DiceCoefficientsMatrix_whole.txt'));
% writematrix(avg_cDC_whole, fullfile(network_folder, 'Average_continuousDiceCoefficient_whole.txt'));
% writematrix(std_cDC_whole, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_whole.txt'));
% writematrix(cDC_whole, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_whole.txt'));
% writematrix(TruePositive_whole, fullfile(network_folder, 'TruePositive_whole.txt'));
% writematrix(TrueNegative_whole, fullfile(network_folder, 'TrueNegative_whole.txt'));
% writematrix(FalsePositive_whole, fullfile(network_folder, 'FalsePositive_whole.txt'));
% writematrix(FalseNegative_whole, fullfile(network_folder, 'FalseNegative_whole.txt'));
% writematrix(PPV_whole, fullfile(network_folder, 'PPV_whole.txt'));
% writematrix(NPV_whole, fullfile(network_folder, 'NPV_whole.txt'));
% 
% % Cortical results
% writematrix(avg_DC_cortical, fullfile(network_folder, 'Average_DiceCoefficient_cortical.txt'));
% writematrix(std_DC_cortical, fullfile(network_folder, 'STDEV_DiceCoefficient_cortical.txt'));
% writematrix(DC_cortical, fullfile(network_folder, 'DiceCoefficientsMatrix_cortical.txt'));
% writematrix(avg_cDC_cortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_cortical.txt'));
% writematrix(std_cDC_cortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_cortical.txt'));
% writematrix(cDC_cortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_cortical.txt'));
% writematrix(TruePositive_cortical, fullfile(network_folder, 'TruePositive_cortical.txt'));
% writematrix(TrueNegative_cortical, fullfile(network_folder, 'TrueNegative_cortical.txt'));
% writematrix(FalsePositive_cortical, fullfile(network_folder, 'FalsePositive_cortical.txt'));
% writematrix(FalseNegative_cortical, fullfile(network_folder, 'FalseNegative_cortical.txt'));
% writematrix(PPV_cortical, fullfile(network_folder, 'PPV_cortical.txt'));
% writematrix(NPV_cortical, fullfile(network_folder, 'NPV_cortical.txt'));
% 
% % Subcortical results
% writematrix(avg_DC_subcortical, fullfile(network_folder, 'Average_DiceCoefficient_subcortical.txt'));
% writematrix(std_DC_subcortical, fullfile(network_folder, 'STDEV_DiceCoefficient_subcortical.txt'));
% writematrix(DC_subcortical, fullfile(network_folder, 'DiceCoefficientsMatrix_subcortical.txt'));
% writematrix(avg_cDC_subcortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_subcortical.txt'));
% writematrix(std_cDC_subcortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_subcortical.txt'));
% writematrix(cDC_subcortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_subcortical.txt'));
% writematrix(TruePositive_subcortical, fullfile(network_folder, 'TruePositive_subcortical.txt'));
% writematrix(TrueNegative_subcortical, fullfile(network_folder, 'TrueNegative_subcortical.txt'));
% writematrix(FalsePositive_subcortical, fullfile(network_folder, 'FalsePositive_subcortical.txt'));
% writematrix(FalseNegative_subcortical, fullfile(network_folder, 'FalseNegative_subcortical.txt'));
% writematrix(PPV_subcortical, fullfile(network_folder, 'PPV_subcortical.txt'));
% writematrix(NPV_subcortical, fullfile(network_folder, 'NPV_subcortical.txt'));

%end

% function mask = create_region_mask(dt, ROIs)
%     % Initialize mask with zeros
%     mask = zeros(size(dt.cdata, 1), 1);
% 
%     % Loop through each region of interest
%     for i = 1:length(ROIs)
%         region_name = ROIs{i};
%         found = false; % Flag to check if the region is found
% 
%         % Find the model corresponding to the current region
%         for j = 1:length(dt.diminfo{1,1}.models)
%             model = dt.diminfo{1,1}.models{j,1};
%             if strcmp(model.struct, region_name)
%                 found = true; % Set the flag to true if found
%                 % Create mask for the current region
%                 start_idx = model.start;
%                 count = model.count;
% 
%                 % Debugging statements
%                 disp(['Processing region: ' region_name]);
%                 disp(['start_idx: ' num2str(start_idx) ', count: ' num2str(count)]);
% 
%                 % Check if the indices are within bounds
%                 if start_idx + count - 1 > length(mask)
%                     error('Index exceeds matrix dimensions.');
%                 end
% 
%                 mask(start_idx:start_idx + count - 1) = 1;
%                 break; % Exit the loop once the region is found
%             end
%         end
% 
%         % If the region is not found, throw an error or warning
%         if ~found
%             warning(['Region not found: ' region_name]);
%         end
%     end
% end


% function calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, thresholdTarget, fig_dir)
% 
% corticalROIs = {'CORTEX_LEFT', 'CORTEX_RIGHT'};
% subcorticalROIs = {'ACCUMBENS_LEFT', 'ACCUMBENS_RIGHT','AMYGDALA_LEFT', 'AMYGDALA_RIGHT','BRAIN_STEM','CAUDATE_LEFT', 'CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT', 'DIENCEPHALON_VENTRAL_RIGHT','CEREBELLUM_LEFT', 'CEREBELLUM_RIGHT','HIPPOCAMPUS_LEFT', 'HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT', 'PALLIDUM_RIGHT','PUTAMEN_LEFT', 'PUTAMEN_RIGHT','THALAMUS_LEFT', 'THALAMUS_RIGHT'};
% 
% % Check if fig_dir is provided as an input
% if nargin < 8 || isempty(fig_dir)
%     fig_dir = [BASEDIR '/figures/DiceCoefficient'];
% end
% 
% mkdir(fig_dir);
% 
% % Add necessary paths
% addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
% addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
% WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
% 
% % Load the dscalar file lists
% dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
% dscalar_list2 = load_dscalar_list(dscalarswithassignments2);
% 
% % Check if the lists have the same length
% if length(dscalar_list1) ~= length(dscalar_list2)
%     error('The two dscalar lists do not have the same number of files.');
% end
% num_permutations = length(dscalar_list1); % Total number of comparisons
% 
% % Initialize results arrays
% DC_whole = zeros(1, num_permutations);
% cDC_whole = zeros(1, num_permutations);
% DC_cortical = zeros(1, num_permutations);
% cDC_cortical = zeros(1, num_permutations);
% DC_subcortical = zeros(1, num_permutations);
% cDC_subcortical = zeros(1, num_permutations);
% 
% TruePositive_whole = zeros(1, num_permutations);
% TrueNegative_whole = zeros(1, num_permutations);
% FalsePositive_whole = zeros(1, num_permutations);
% FalseNegative_whole = zeros(1, num_permutations);
% PPV_whole = zeros(1, num_permutations);
% NPV_whole = zeros(1, num_permutations);
% 
% TruePositive_cortical = zeros(1, num_permutations);
% TrueNegative_cortical = zeros(1, num_permutations);
% FalsePositive_cortical = zeros(1, num_permutations);
% FalseNegative_cortical = zeros(1, num_permutations);
% PPV_cortical = zeros(1, num_permutations);
% NPV_cortical = zeros(1, num_permutations);
% 
% TruePositive_subcortical = zeros(1, num_permutations);
% TrueNegative_subcortical = zeros(1, num_permutations);
% FalsePositive_subcortical = zeros(1, num_permutations);
% FalseNegative_subcortical = zeros(1, num_permutations);
% PPV_subcortical = zeros(1, num_permutations);
% NPV_subcortical = zeros(1, num_permutations);
% 
% for s = 1:length(dscalar_list1)
% 
%     dscalar1 = dscalar_list1{s};
%     dscalar2 = dscalar_list2{s};
% 
%     % Load data and perform analysis
%     Mdscalar = cifti_read(dscalar1);
%     Mdata = Mdscalar.cdata;
% 
%     Cdscalar = cifti_read(dscalar2);
%     Cdata = Cdscalar.cdata;
% 
%     % Create masks
%     cortical_mask = create_region_mask(Mdscalar, corticalROIs);
%     subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
% 
%     % Apply threshold based on the thresholdTarget
%     if nargin >= 7 && ~isempty(threshold)
%         switch lower(thresholdTarget)
%             case 'both'
%                 Mdata(Mdata < threshold) = 0;
%                 Cdata(Cdata < threshold) = 0;
%             case 'dscalar1'
%                 Mdata(Mdata < threshold) = 0;
%             case 'dscalar2'
%                 Cdata(Cdata < threshold) = 0;
%             otherwise
%                 error('Invalid thresholdTarget value. Choose ''both'', ''dscalar1'', or ''dscalar2''.');
%         end
%     end
% 
%     % Whole-brain analysis
%     if ConfMap
%         disp("running confmap code on whole")
% 
%         % Binarize the confidence maps
%         Mdata_bin = Mdata > 0;
%         Cdata_bin = Cdata > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_whole(s) = continuous_Dice_coefficient(Mdata, Cdata_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_whole(s) = Dice_coefficient(Mdata_bin, Cdata_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_bin, Cdata_bin);
% 
%         %TruePositive_whole(s) = transition_matrix_full(2,2);
%         %TrueNegative_whole(s) = transition_matrix_full(1,1);
%         %FalseNegative_whole(s) = transition_matrix_full(2,1);
%         %FalsePositive_whole(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         %PPV_whole(s) = TruePositive_whole(s) / (TruePositive_whole(s) + FalsePositive_whole(s));
% 
%         % Negative Predictive Value
%         %NPV_whole(s) = TrueNegative_whole(s) / (TrueNegative_whole(s) + FalseNegative_whole(s));
%     else
%         disp("running network dscalar code on whole")
% 
%         unique_networks = unique([Mdata; Cdata]);
% 
%         % Initialize a cell array to store the vectors
%         network_vectors_dscalar1 = cell(length(unique_networks), 1);
%         network_vectors_dscalar2 = cell(length(unique_networks), 1);
% 
%         for i = 1:length(unique_networks)
%             j = unique_networks(i);
%             % Create a logical vector for the current network
%             dscalar1_net = (Mdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar1_net = double(dscalar1_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar1{i} = dscalar1_net;
% 
%             dscalar2_net = (Cdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar2_net = double(dscalar2_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar2{i} = dscalar2_net;
% 
%             cDC_whole(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
% 
%             % Binarize segmentation result
%             binary_segmentation_result = zeros(size(dscalar2_net));
%             binary_segmentation_result(dscalar2_net > 0.01) = 1;
% 
%             % Compute Dice coefficient
%             DC_whole(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
% 
%             % Get True positive and negatives 
%             [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net, binary_segmentation_result);
% 
%             TruePositive_whole(i) = transition_matrix_full(2,2);
%             TrueNegative_whole(i) = transition_matrix_full(1,1);
%             FalseNegative_whole(i) = transition_matrix_full(2,1);
%             FalsePositive_whole(i) = transition_matrix_full(1,2);
% 
%             % Positive Predictive Value
%             PPV_whole(i) = TruePositive_whole(i) / (TruePositive_whole(i) + FalsePositive_whole(i));
% 
%             % Negative Predictive Value
%             NPV_whole(i) = TrueNegative_whole(i) / (TrueNegative_whole(i) + FalseNegative_whole(i));
% 
%         end
%     end
% 
%     % Cortical analysis
%     Mdata_cortical = Mdata .* cortical_mask;
%     Cdata_cortical = Cdata .* cortical_mask;
% 
%     if ConfMap
%         disp("running confmap code on cortical")
% 
%         % Binarize the confidence maps
%         Mdata_cortical_bin = Mdata_cortical > 0;
%         Cdata_cortical_bin = Cdata_cortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_cortical(s) = continuous_Dice_coefficient(Mdata_cortical, Cdata_cortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_cortical(s) = Dice_coefficient(Mdata_cortical_bin, Cdata_cortical_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_cortical_bin, Cdata_cortical_bin);
% 
%         TruePositive_cortical(s) = transition_matrix_full(2,2);
%         TrueNegative_cortical(s) = transition_matrix_full(1,1);
%         FalseNegative_cortical(s) = transition_matrix_full(2,1);
%         FalsePositive_cortical(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         PPV_cortical(s) = TruePositive_cortical(s) / (TruePositive_cortical(s) + FalsePositive_cortical(s));
% 
%         % Negative Predictive Value
%         NPV_cortical(s) = TrueNegative_cortical(s) / (TrueNegative_cortical(s) + FalseNegative_cortical(s));
%      else
%         disp("running network dscalar code on cortical")
% 
%         unique_networks = unique([Mdata_cortical; Cdata_cortical]);
% 
%         % Initialize a cell array to store the vectors
%         network_vectors_dscalar1 = cell(length(unique_networks), 1);
%         network_vectors_dscalar2 = cell(length(unique_networks), 1);
% 
%         for i = 1:length(unique_networks)
%             j = unique_networks(i);
%             % Create a logical vector for the current network
%             dscalar1_net = (Mdata_cortical == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar1_net = double(dscalar1_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar1{i} = dscalar1_net;
% 
%             dscalar2_net = (Cdata_cortical == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar2_net = double(dscalar2_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar2{i} = dscalar2_net;
% 
%             cDC_cortical(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
% 
%             % Binarize segmentation result
%             binary_segmentation_result = zeros(size(dscalar2_net));
%             binary_segmentation_result(dscalar2_net > 0.01) = 1;
% 
%             % Compute Dice coefficient
%             DC_cortical(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
% 
%             % Get True positive and negatives 
%             [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net, binary_segmentation_result);
% 
%             TruePositive_cortical(i) = transition_matrix_full(2,2);
%             TrueNegative_cortical(i) = transition_matrix_full(1,1);
%             FalseNegative_cortical(i) = transition_matrix_full(2,1);
%             FalsePositive_cortical(i) = transition_matrix_full(1,2);
% 
%             % Positive Predictive Value
%             PPV_cortical(i) = TruePositive_cortical(i) / (TruePositive_cortical(i) + FalsePositive_cortical(i));
% 
%             % Negative Predictive Value
%             NPV_cortical(i) = TrueNegative_cortical(i) / (TrueNegative_cortical(i) + FalseNegative_cortical(i));
% 
%         end
%     end
% 
% 
%     % Subcortical analysis
%     Mdata_subcortical = Mdata .* subcortical_mask;
%     Cdata_subcortical = Cdata .* subcortical_mask;
% 
%     if ConfMap
%         disp("running confmap code on subcortical")
%         % Binarize the confidence maps
%         Mdata_subcortical_bin = Mdata_subcortical > 0;
%         Cdata_subcortical_bin = Cdata_subcortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_subcortical(s) = continuous_Dice_coefficient(Mdata_subcortical, Cdata_subcortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_subcortical(s) = Dice_coefficient(Mdata_subcortical_bin, Cdata_subcortical_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_subcortical_bin, Cdata_subcortical_bin);
% 
%         TruePositive_subcortical(s) = transition_matrix_full(2,2);
%         TrueNegative_subcortical(s) = transition_matrix_full(1,1);
%         FalseNegative_subcortical(s) = transition_matrix_full(2,1);
%         FalsePositive_subcortical(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         PPV_subcortical(s) = TruePositive_subcortical(s) / (TruePositive_subcortical(s) + FalsePositive_subcortical(s));
% 
%         % Negative Predictive Value
%         NPV_subcortical(s) = TrueNegative_subcortical(s) / (TrueNegative_subcortical(s) + FalseNegative_subcortical(s));
% 
%     else
%         disp("running network dscalar code on subcortical")
% 
%         unique_networks = unique([Mdata_subcortical; Cdata_subcortical]);
% 
%         % Initialize a cell array to store the vectors
%         network_vectors_dscalar1 = cell(length(unique_networks), 1);
%         network_vectors_dscalar2 = cell(length(unique_networks), 1);
% 
%         for i = 1:length(unique_networks)
%             j = unique_networks(i);
%             % Create a logical vector for the current network
%             dscalar1_net = (Mdata_subcortical == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar1_net = double(dscalar1_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar1{i} = dscalar1_net;
% 
%             dscalar2_net = (Cdata_subcortical == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar2_net = double(dscalar2_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar2{i} = dscalar2_net;
% 
%             cDC_subcortical(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
% 
%             % Binarize segmentation result
%             binary_segmentation_result = zeros(size(dscalar2_net));
%             binary_segmentation_result(dscalar2_net > 0.01) = 1;
% 
%             % Compute Dice coefficient
%             DC_subcortical(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
% 
%             % Get True positive and negatives 
%             [transition_matrix, transition_matrix_full, ~] = map_network_changes(dscalar1_net, binary_segmentation_result);
% 
%             TruePositive_subcortical(i) = transition_matrix_full(2,2);
%             TrueNegative_subcortical(i) = transition_matrix_full(1,1);
%             FalseNegative_subcortical(i) = transition_matrix_full(2,1);
%             FalsePositive_subcortical(i) = transition_matrix_full(1,2);
% 
%             % Positive Predictive Value
%             PPV_subcortical(i) = TruePositive_subcortical(i) / (TruePositive_subcortical(i) + FalsePositive_subcortical(i));
% 
%             % Negative Predictive Value
%             NPV_subcortical(i) = TrueNegative_subcortical(i) / (TrueNegative_subcortical(i) + FalseNegative_subcortical(i));
% 
%         end
%     end
% 
% 
% % Calculate averages and standard deviations across permutations if more than one permutation
% if num_permutations > 1
%     avg_cDC_whole = mean(cDC_whole, 2);
%     std_cDC_whole = std(cDC_whole, 0, 2);
%     avg_DC_whole = mean(DC_whole, 2);
%     std_DC_whole = std(DC_whole, 0, 2);
% 
%     avg_cDC_cortical = mean(cDC_cortical, 2);
%     std_cDC_cortical = std(cDC_cortical, 0, 2);
%     avg_DC_cortical = mean(DC_cortical, 2);
%     std_DC_cortical = std(DC_cortical, 0, 2);
% 
%     avg_cDC_subcortical = mean(cDC_subcortical, 2);
%     std_cDC_subcortical = std(cDC_subcortical, 0, 2);
%     avg_DC_subcortical = mean(DC_subcortical, 2);
%     std_DC_subcortical = std(DC_subcortical, 0, 2);
% else
%     avg_cDC_whole = cDC_whole;
%     std_cDC_whole = zeros(size(cDC_whole));  % Standard deviation is zero when there's only one permutation
%     avg_DC_whole = DC_whole;
%     std_DC_whole = zeros(size(DC_whole));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_cortical = cDC_cortical;
%     std_cDC_cortical = zeros(size(cDC_cortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_cortical = DC_cortical;
%     std_DC_cortical = zeros(size(DC_cortical));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_subcortical = cDC_subcortical;
%     std_cDC_subcortical = zeros(size(cDC_subcortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_subcortical = DC_subcortical;
%     std_DC_subcortical = zeros(size(DC_subcortical));  % Standard deviation is zero when there's only one permutation
% end
% 
% % Write results to files
% network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
% mkdir(network_folder);
% 
% % Whole-brain results
% writematrix(avg_DC_whole, fullfile(network_folder, 'Average_DiceCoefficient_whole.txt'));
% writematrix(std_DC_whole, fullfile(network_folder, 'STDEV_DiceCoefficient_whole.txt'));
% writematrix(DC_whole, fullfile(network_folder, 'DiceCoefficientsMatrix_whole.txt'));
% writematrix(avg_cDC_whole, fullfile(network_folder, 'Average_continuousDiceCoefficient_whole.txt'));
% writematrix(std_cDC_whole, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_whole.txt'));
% writematrix(cDC_whole, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_whole.txt'));
% writematrix(TruePositive_whole, fullfile(network_folder, 'TruePositive_whole.txt'));
% writematrix(TrueNegative_whole, fullfile(network_folder, 'TrueNegative_whole.txt'));
% writematrix(FalsePositive_whole, fullfile(network_folder, 'FalsePositive_whole.txt'));
% writematrix(FalseNegative_whole, fullfile(network_folder, 'FalseNegative_whole.txt'));
% writematrix(PPV_whole, fullfile(network_folder, 'PPV_whole.txt'));
% writematrix(NPV_whole, fullfile(network_folder, 'NPV_whole.txt'));
% 
% % Cortical results
% writematrix(avg_DC_cortical, fullfile(network_folder, 'Average_DiceCoefficient_cortical.txt'));
% writematrix(std_DC_cortical, fullfile(network_folder, 'STDEV_DiceCoefficient_cortical.txt'));
% writematrix(DC_cortical, fullfile(network_folder, 'DiceCoefficientsMatrix_cortical.txt'));
% writematrix(avg_cDC_cortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_cortical.txt'));
% writematrix(std_cDC_cortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_cortical.txt'));
% writematrix(cDC_cortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_cortical.txt'));
% writematrix(TruePositive_cortical, fullfile(network_folder, 'TruePositive_cortical.txt'));
% writematrix(TrueNegative_cortical, fullfile(network_folder, 'TrueNegative_cortical.txt'));
% writematrix(FalsePositive_cortical, fullfile(network_folder, 'FalsePositive_cortical.txt'));
% writematrix(FalseNegative_cortical, fullfile(network_folder, 'FalseNegative_cortical.txt'));
% writematrix(PPV_cortical, fullfile(network_folder, 'PPV_cortical.txt'));
% writematrix(NPV_cortical, fullfile(network_folder, 'NPV_cortical.txt'));
% 
% % Subcortical results
% writematrix(avg_DC_subcortical, fullfile(network_folder, 'Average_DiceCoefficient_subcortical.txt'));
% writematrix(std_DC_subcortical, fullfile(network_folder, 'STDEV_DiceCoefficient_subcortical.txt'));
% writematrix(DC_subcortical, fullfile(network_folder, 'DiceCoefficientsMatrix_subcortical.txt'));
% writematrix(avg_cDC_subcortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_subcortical.txt'));
% writematrix(std_cDC_subcortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_subcortical.txt'));
% writematrix(cDC_subcortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_subcortical.txt'));
% writematrix(TruePositive_subcortical, fullfile(network_folder, 'TruePositive_subcortical.txt'));
% writematrix(TrueNegative_subcortical, fullfile(network_folder, 'TrueNegative_subcortical.txt'));
% writematrix(FalsePositive_subcortical, fullfile(network_folder, 'FalsePositive_subcortical.txt'));
% writematrix(FalseNegative_subcortical, fullfile(network_folder, 'FalseNegative_subcortical.txt'));
% writematrix(PPV_subcortical, fullfile(network_folder, 'PPV_subcortical.txt'));
% writematrix(NPV_subcortical, fullfile(network_folder, 'NPV_subcortical.txt'));
% 
% end

% function calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)
% 
% %, corticalROIs, subcorticalROIs)
% 
% corticalROIs = {'CORTEX_LEFT', 'CORTEX_RIGHT'};
% subcorticalROIs = {'ACCUMBENS_LEFT', 'ACCUMBENS_RIGHT','AMYGDALA_LEFT', 'AMYGDALA_RIGHT','BRAIN_STEM','CAUDATE_LEFT', 'CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT', 'DIENCEPHALON_VENTRAL_RIGHT','CERABELLUM_LEFT', 'CERABELLUM_RIGHT','HIPPOCAMPUS_LEFT', 'HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT', 'PALLIDUM_RIGHT','PUTAMEN_LEFT', 'PUTAMEN_RIGHT','THALAMUS_LEFT', 'THALAMUS_RIGHT','CEREBELLUM'};
% 
% % Check if fig_dir is provided as an input
% if nargin < 7 || isempty(fig_dir)
%     fig_dir = [BASEDIR '/figures/DiceCoefficient'];
% end
% disp("this works?")
% mkdir(fig_dir);
% 
% % Add necessary paths
% addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
% addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
% WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
% 
% % Load the dscalar file lists
% dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
% dscalar_list2 = load_dscalar_list(dscalarswithassignments2);
% 
% % Check if the lists have the same length
% if length(dscalar_list1) ~= length(dscalar_list2)
%     error('The two dscalar lists do not have the same number of files.');
% end
% num_permutations = length(dscalar_list1); % Total number of comparisons
% 
% % Initialize results arrays
% DC_whole = zeros(1, num_permutations);
% cDC_whole = zeros(1, num_permutations);
% DC_cortical = zeros(1, num_permutations);
% cDC_cortical = zeros(1, num_permutations);
% DC_subcortical = zeros(1, num_permutations);
% cDC_subcortical = zeros(1, num_permutations);
% 
% TruePositive_whole = zeros(1, num_permutations);
% TrueNegative_whole = zeros(1, num_permutations);
% FalsePositive_whole = zeros(1, num_permutations);
% FalseNegative_whole = zeros(1, num_permutations);
% PPV_whole = zeros(1, num_permutations);
% NPV_whole = zeros(1, num_permutations);
% 
% TruePositive_cortical = zeros(1, num_permutations);
% TrueNegative_cortical = zeros(1, num_permutations);
% FalsePositive_cortical = zeros(1, num_permutations);
% FalseNegative_cortical = zeros(1, num_permutations);
% PPV_cortical = zeros(1, num_permutations);
% NPV_cortical = zeros(1, num_permutations);
% 
% TruePositive_subcortical = zeros(1, num_permutations);
% TrueNegative_subcortical = zeros(1, num_permutations);
% FalsePositive_subcortical = zeros(1, num_permutations);
% FalseNegative_subcortical = zeros(1, num_permutations);
% PPV_subcortical = zeros(1, num_permutations);
% NPV_subcortical = zeros(1, num_permutations);
% 
% for s = 1:length(dscalar_list1)
% 
%     dscalar1 = dscalar_list1{s};
%     dscalar2 = dscalar_list2{s};
% 
%     % Load data and perform analysis
%     Mdscalar = cifti_read(dscalar1);
%     Mdata = Mdscalar.cdata;
% 
%     Cdscalar = cifti_read(dscalar2);
%     Cdata = Cdscalar.cdata;
% 
%     % Create masks
%     cortical_mask = create_region_mask(Mdscalar, corticalROIs);
%     subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
% 
%     % Whole-brain analysis
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata(Mdata < threshold) = 0;
%             Cdata(Cdata < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_bin = Mdata > 0;
%         Cdata_bin = Cdata > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_whole(s) = continuous_Dice_coefficient(Mdata, Cdata_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_whole(s) = Dice_coefficient(Mdata_bin, Cdata_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_bin, Cdata_bin);
% 
%         TruePositive_whole(s) = transition_matrix_full(2,2);
%         TrueNegative_whole(s) = transition_matrix_full(1,1);
%         FalseNegative_whole(s) = transition_matrix_full(2,1);
%         FalsePositive_whole(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         PPV_whole(s) = TruePositive_whole(s) / (TruePositive_whole(s) + FalsePositive_whole(s));
% 
%         % Negative Predictive Value
%         NPV_whole(s) = TrueNegative_whole(s) / (TrueNegative_whole(s) + FalseNegative_whole(s));
%     else
%         unique_networks = unique([Mdata; Cdata]);
% 
%         % Initialize a cell array to store the vectors
%         network_vectors_dscalar1 = cell(length(unique_networks), 1);
%         network_vectors_dscalar2 = cell(length(unique_networks), 1);
% 
%         for i = 1:length(unique_networks)
%             j = unique_networks(i);
%             % Create a logical vector for the current network
%             dscalar1_net = (Mdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar1_net = double(dscalar1_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar1{i} = dscalar1_net;
% 
%             dscalar2_net = (Cdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar2_net = double(dscalar2_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar2{i} = dscalar2_net;
% 
%             cDC_whole(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
% 
%             % Binarize segmentation result
%             binary_segmentation_result = zeros(size(dscalar2_net));
%             binary_segmentation_result(dscalar2_net > 0.01) = 1;
% 
%             % Compute Dice coefficient
%             DC_whole(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
%         end
%     end
% 
%     % Cortical analysis
%     Mdata_cortical = Mdata .* cortical_mask;
%     Cdata_cortical = Cdata .* cortical_mask;
% 
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata_cortical(Mdata_cortical < threshold) = 0;
%             Cdata_cortical(Cdata_cortical < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_cortical_bin = Mdata_cortical > 0;
%         Cdata_cortical_bin = Cdata_cortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_cortical(s) = continuous_Dice_coefficient(Mdata_cortical, Cdata_cortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_cortical(s) = Dice_coefficient(Mdata_cortical_bin, Cdata_cortical_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_cortical_bin, Cdata_cortical_bin);
% 
%         TruePositive_cortical(s) = transition_matrix_full(2,2);
%         TrueNegative_cortical(s) = transition_matrix_full(1,1);
%         FalseNegative_cortical(s) = transition_matrix_full(2,1);
%         FalsePositive_cortical(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         PPV_cortical(s) = TruePositive_cortical(s) / (TruePositive_cortical(s) + FalsePositive_cortical(s));
% 
%         % Negative Predictive Value
%         NPV_cortical(s) = TrueNegative_cortical(s) / (TrueNegative_cortical(s) + FalseNegative_cortical(s));
%     end
% 
%     % Subcortical analysis
%     Mdata_subcortical = Mdata .* subcortical_mask;
%     Cdata_subcortical = Cdata .* subcortical_mask;
% 
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata_subcortical(Mdata_subcortical < threshold) = 0;
%             Cdata_subcortical(Cdata_subcortical < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_subcortical_bin = Mdata_subcortical > 0;
%         Cdata_subcortical_bin = Cdata_subcortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_subcortical(s) = continuous_Dice_coefficient(Mdata_subcortical, Cdata_subcortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_subcortical(s) = Dice_coefficient(Mdata_subcortical_bin, Cdata_subcortical_bin);
% 
%         % Get True positive and negatives 
%         [transition_matrix, transition_matrix_full, ~] = map_network_changes(Mdata_subcortical_bin, Cdata_subcortical_bin);
% 
%         TruePositive_subcortical(s) = transition_matrix_full(2,2);
%         TrueNegative_subcortical(s) = transition_matrix_full(1,1);
%         FalseNegative_subcortical(s) = transition_matrix_full(2,1);
%         FalsePositive_subcortical(s) = transition_matrix_full(1,2);
% 
%         % Positive Predictive Value
%         PPV_subcortical(s) = TruePositive_subcortical(s) / (TruePositive_subcortical(s) + FalsePositive_subcortical(s));
% 
%         % Negative Predictive Value
%         NPV_subcortical(s) = TrueNegative_subcortical(s) / (TrueNegative_subcortical(s) + FalseNegative_subcortical(s));
%     end
% end
% 
% % Calculate averages and standard deviations across permutations if more than one permutation
% if num_permutations > 1
%     avg_cDC_whole = mean(cDC_whole, 2);
%     std_cDC_whole = std(cDC_whole, 0, 2);
%     avg_DC_whole = mean(DC_whole, 2);
%     std_DC_whole = std(DC_whole, 0, 2);
% 
%     avg_cDC_cortical = mean(cDC_cortical, 2);
%     std_cDC_cortical = std(cDC_cortical, 0, 2);
%     avg_DC_cortical = mean(DC_cortical, 2);
%     std_DC_cortical = std(DC_cortical, 0, 2);
% 
%     avg_cDC_subcortical = mean(cDC_subcortical, 2);
%     std_cDC_subcortical = std(cDC_subcortical, 0, 2);
%     avg_DC_subcortical = mean(DC_subcortical, 2);
%     std_DC_subcortical = std(DC_subcortical, 0, 2);
% else
%     avg_cDC_whole = cDC_whole;
%     std_cDC_whole = zeros(size(cDC_whole));  % Standard deviation is zero when there's only one permutation
%     avg_DC_whole = DC_whole;
%     std_DC_whole = zeros(size(DC_whole));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_cortical = cDC_cortical;
%     std_cDC_cortical = zeros(size(cDC_cortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_cortical = DC_cortical;
%     std_DC_cortical = zeros(size(DC_cortical));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_subcortical = cDC_subcortical;
%     std_cDC_subcortical = zeros(size(cDC_subcortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_subcortical = DC_subcortical;
%     std_DC_subcortical = zeros(size(DC_subcortical));  % Standard deviation is zero when there's only one permutation
% end
% 
% % Write results to files
% network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
% mkdir(network_folder);
% 
% % Whole-brain results
% writematrix(avg_DC_whole, fullfile(network_folder, 'Average_DiceCoefficient_whole.txt'));
% writematrix(std_DC_whole, fullfile(network_folder, 'STDEV_DiceCoefficient_whole.txt'));
% writematrix(DC_whole, fullfile(network_folder, 'DiceCoefficientsMatrix_whole.txt'));
% writematrix(avg_cDC_whole, fullfile(network_folder, 'Average_continuousDiceCoefficient_whole.txt'));
% writematrix(std_cDC_whole, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_whole.txt'));
% writematrix(cDC_whole, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_whole.txt'));
% writematrix(TruePositive_whole, fullfile(network_folder, 'TruePositive_whole.txt'));
% writematrix(TrueNegative_whole, fullfile(network_folder, 'TrueNegative_whole.txt'));
% writematrix(FalsePositive_whole, fullfile(network_folder, 'FalsePositive_whole.txt'));
% writematrix(FalseNegative_whole, fullfile(network_folder, 'FalseNegative_whole.txt'));
% writematrix(PPV_whole, fullfile(network_folder, 'PPV_whole.txt'));
% writematrix(NPV_whole, fullfile(network_folder, 'NPV_whole.txt'));
% 
% % Cortical results
% writematrix(avg_DC_cortical, fullfile(network_folder, 'Average_DiceCoefficient_cortical.txt'));
% writematrix(std_DC_cortical, fullfile(network_folder, 'STDEV_DiceCoefficient_cortical.txt'));
% writematrix(DC_cortical, fullfile(network_folder, 'DiceCoefficientsMatrix_cortical.txt'));
% writematrix(avg_cDC_cortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_cortical.txt'));
% writematrix(std_cDC_cortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_cortical.txt'));
% writematrix(cDC_cortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_cortical.txt'));
% writematrix(TruePositive_cortical, fullfile(network_folder, 'TruePositive_cortical.txt'));
% writematrix(TrueNegative_cortical, fullfile(network_folder, 'TrueNegative_cortical.txt'));
% writematrix(FalsePositive_cortical, fullfile(network_folder, 'FalsePositive_cortical.txt'));
% writematrix(FalseNegative_cortical, fullfile(network_folder, 'FalseNegative_cortical.txt'));
% writematrix(PPV_cortical, fullfile(network_folder, 'PPV_cortical.txt'));
% writematrix(NPV_cortical, fullfile(network_folder, 'NPV_cortical.txt'));
% 
% % Subcortical results
% writematrix(avg_DC_subcortical, fullfile(network_folder, 'Average_DiceCoefficient_subcortical.txt'));
% writematrix(std_DC_subcortical, fullfile(network_folder, 'STDEV_DiceCoefficient_subcortical.txt'));
% writematrix(DC_subcortical, fullfile(network_folder, 'DiceCoefficientsMatrix_subcortical.txt'));
% writematrix(avg_cDC_subcortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_subcortical.txt'));
% writematrix(std_cDC_subcortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_subcortical.txt'));
% writematrix(cDC_subcortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_subcortical.txt'));
% writematrix(TruePositive_subcortical, fullfile(network_folder, 'TruePositive_subcortical.txt'));
% writematrix(TrueNegative_subcortical, fullfile(network_folder, 'TrueNegative_subcortical.txt'));
% writematrix(FalsePositive_subcortical, fullfile(network_folder, 'FalsePositive_subcortical.txt'));
% writematrix(FalseNegative_subcortical, fullfile(network_folder, 'FalseNegative_subcortical.txt'));
% writematrix(PPV_subcortical, fullfile(network_folder, 'PPV_subcortical.txt'));
% writematrix(NPV_subcortical, fullfile(network_folder, 'NPV_subcortical.txt'));
% 
% end
% 



% function calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)
% %, corticalROIs, subcorticalROIs)
% 
% corticalROIs = {'CORTEX_LEFT', 'CORTEX_RIGHT'};
% %cortical_roi_mask = create_region_mask(dt, corticalROIs);
% subcorticalROIs = {'ACCUMBENS_LEFT', 'ACCUMBENS_RIGHT','AMYGDALA_LEFT', 'AMYGDALA_RIGHT','BRAIN_STEM','CAUDATE_LEFT', 'CAUDATE_RIGHT','DIENCEPHALON_VENTRAL_LEFT', 'DIENCEPHALON_VENTRAL_RIGHT','CERABELLUM_LEFT', 'CERABELLUM_RIGHT','HIPPOCAMPUS_LEFT', 'HIPPOCAMPUS_RIGHT','PALLIDUM_LEFT', 'PALLIDUM_RIGHT','PUTAMEN_LEFT', 'PUTAMEN_RIGHT','THALAMUS_LEFT', 'THALAMUS_RIGHT'};
% 
% %subcortical_roi_mask = create_region_mask(dt, subcorticalROIs);
% 
% 
% % Check if fig_dir is provided as an input
% if nargin < 7 || isempty(fig_dir)
%     fig_dir = [BASEDIR '/figures/DiceCoefficient'];
% end
% 
% mkdir(fig_dir);
% %network_name='Aud'
% %ConfMap=1
% %threshold=0
% %fig_dir='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/PCMconfmapFigure_testing'
% %dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//RefData-70m/sub-1003601_ses-combined_mode_map_rep100.conc'
% %dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//ExpData-70m/sub-1003601_ses-combined_successful_percent_holdout-50.conc'
% %dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/ExpData-5m/sub-1003601_ses-combined_PCM_network-Aud.conc'
% %dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/RefData-70m/sub-1003601_ses-combined_PCM_network-Aud.conc'
% 
% % Add necessary paths
% addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
% addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
% WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';
% 
% % Load the dscalar file lists
% dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
% dscalar_list2 = load_dscalar_list(dscalarswithassignments2);
% 
% % Check if the lists have the same length
% if length(dscalar_list1) ~= length(dscalar_list2)
%     error('The two dscalar lists do not have the same number of files.');
% end
% num_permutations = length(dscalar_list1); % Total number of comparisons
% 
% % Initialize results arrays
% DC_whole = zeros(1, num_permutations);
% cDC_whole = zeros(1, num_permutations);
% DC_cortical = zeros(1, num_permutations);
% cDC_cortical = zeros(1, num_permutations);
% DC_subcortical = zeros(1, num_permutations);
% cDC_subcortical = zeros(1, num_permutations);
% 
% for s = 1:length(dscalar_list1)
% 
%     dscalar1 = dscalar_list1{s};
%     dscalar2 = dscalar_list2{s};
% 
%     % Load data and perform analysis
%     Mdscalar = cifti_read(dscalar1);
%     Mdata = Mdscalar.cdata;
% 
%     Cdscalar = cifti_read(dscalar2);
%     Cdata = Cdscalar.cdata;
% 
%     % Create masks
%     cortical_mask = create_region_mask(Mdscalar, corticalROIs);
%     subcortical_mask = create_region_mask(Mdscalar, subcorticalROIs);
% 
%     % Whole-brain analysis
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata(Mdata < threshold) = 0;
%             Cdata(Cdata < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_bin = Mdata > 0;
%         Cdata_bin = Cdata > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_whole(s) = continuous_Dice_coefficient(Mdata, Cdata_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_whole(s) = Dice_coefficient(Mdata_bin, Cdata_bin);
%         %Get True positive and negatives 
%         num_networks=length(unique(Cdata_bin));
%         network_stability_all = zeros(num_networks, num_permutations); % Replace num_networks with actual number
%         all_transition_matrices = zeros(num_networks, num_networks, num_permutations);
% 
%         [transition_matrix, transition_matrix_full, network_to_index] = map_network_changes(Mdata_bin, Cdata_bin);
% 
%         TruePositive=transition_matrix_full(2,2);
%         TrueNegative=transition_matrix_full(1,1);
%         FalseNegative=transition_matrix_full(2,1);
%         FalsePositive=transition_matrix_full(1,2);
% 
%         % Network Stability
%         network_stability = diag(transition_matrix_full) ./ sum(transition_matrix_full, 2);
%         PPV=TruePositive/(TruePositive+FalsePositive);%Positive Preductuve Value
% 
%         NPV=TrueNegative/(TrueNegative+FalseNegative); %Negartive preditive value
%     else
%         unique_networks = unique([Mdata; Cdata]);
% 
%         % Initialize a cell array to store the vectors
%         network_vectors_dscalar1 = cell(length(unique_networks), 1);
%         network_vectors_dscalar2 = cell(length(unique_networks), 1);
% 
%         for i = 1:length(unique_networks)
%             j = unique_networks(i);
%             % Create a logical vector for the current network
%             dscalar1_net = (Mdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar1_net = double(dscalar1_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar1{i} = dscalar1_net;
% 
%             dscalar2_net = (Cdata == j);
% 
%             % Convert logical vector to double (0's and 1's)
%             dscalar2_net = double(dscalar2_net);
% 
%             % Store the vector in the cell array
%             network_vectors_dscalar2{i} = dscalar2_net;
% 
%             cDC(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
% 
%             % Binarize segmentation result
%             binary_segmentation_result = zeros(size(dscalar2_net));
%             binary_segmentation_result(dscalar2_net > 0.01) = 1;
% 
%             % Compute Dice coefficient
%             DC(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
%         end
%     end
% 
%     % Cortical analysis
%     Mdata_cortical = Mdata .* cortical_mask;
%     Cdata_cortical = Cdata .* cortical_mask;
% 
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata_cortical(Mdata_cortical < threshold) = 0;
%             Cdata_cortical(Cdata_cortical < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_cortical_bin = Mdata_cortical > 0;
%         Cdata_cortical_bin = Cdata_cortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_cortical(s) = continuous_Dice_coefficient(Mdata_cortical, Cdata_cortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_cortical(s) = Dice_coefficient(Mdata_cortical_bin, Cdata_cortical_bin);
%     end
% 
%     % Subcortical analysis
%     Mdata_subcortical = Mdata .* subcortical_mask;
%     Cdata_subcortical = Cdata .* subcortical_mask;
% 
%     if ConfMap
%         % Apply threshold if provided
%         if nargin >= 6 && ~isempty(threshold)
%             Mdata_subcortical(Mdata_subcortical < threshold) = 0;
%             Cdata_subcortical(Cdata_subcortical < threshold) = 0;
%         end
% 
%         % Binarize the confidence maps
%         Mdata_subcortical_bin = Mdata_subcortical > 0;
%         Cdata_subcortical_bin = Cdata_subcortical > 0;
% 
%         % Calculate continuous Dice coefficient (cDC)
%         cDC_subcortical(s) = continuous_Dice_coefficient(Mdata_subcortical, Cdata_subcortical_bin);
% 
%         % Calculate Dice coefficient (DC)
%         DC_subcortical(s) = Dice_coefficient(Mdata_subcortical_bin, Cdata_subcortical_bin);
%     end
% end
% 
% % Calculate averages and standard deviations across permutations if more than one permutation
% if num_permutations > 1
%     avg_cDC_whole = mean(cDC_whole, 2);
%     std_cDC_whole = std(cDC_whole, 0, 2);
%     avg_DC_whole = mean(DC_whole, 2);
%     std_DC_whole = std(DC_whole, 0, 2);
% 
%     avg_cDC_cortical = mean(cDC_cortical, 2);
%     std_cDC_cortical = std(cDC_cortical, 0, 2);
%     avg_DC_cortical = mean(DC_cortical, 2);
%     std_DC_cortical = std(DC_cortical, 0, 2);
% 
%     avg_cDC_subcortical = mean(cDC_subcortical, 2);
%     std_cDC_subcortical = std(cDC_subcortical, 0, 2);
%     avg_DC_subcortical = mean(DC_subcortical, 2);
%     std_DC_subcortical = std(DC_subcortical, 0, 2);
% else
%     avg_cDC_whole = cDC_whole;
%     std_cDC_whole = zeros(size(cDC_whole));  % Standard deviation is zero when there's only one permutation
%     avg_DC_whole = DC_whole;
%     std_DC_whole = zeros(size(DC_whole));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_cortical = cDC_cortical;
%     std_cDC_cortical = zeros(size(cDC_cortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_cortical = DC_cortical;
%     std_DC_cortical = zeros(size(DC_cortical));  % Standard deviation is zero when there's only one permutation
% 
%     avg_cDC_subcortical = cDC_subcortical;
%     std_cDC_subcortical = zeros(size(cDC_subcortical));  % Standard deviation is zero when there's only one permutation
%     avg_DC_subcortical = DC_subcortical;
%     std_DC_subcortical = zeros(size(DC_subcortical));  % Standard deviation is zero when there's only one permutation
% end
% 
% % Write results to files
% network_folder = fullfile(fig_dir, [network_name '-thresh-' num2str(threshold)]);
% mkdir(network_folder);
% 
% % Whole-brain results
% writematrix(avg_DC_whole, fullfile(network_folder, 'Average_DiceCoefficient_whole.txt'));
% writematrix(std_DC_whole, fullfile(network_folder, 'STDEV_DiceCoefficient_whole.txt'));
% writematrix(DC_whole, fullfile(network_folder, 'DiceCoefficientsMatrix_whole.txt'));
% writematrix(avg_cDC_whole, fullfile(network_folder, 'Average_continuousDiceCoefficient_whole.txt'));
% writematrix(std_cDC_whole, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_whole.txt'));
% writematrix(cDC_whole, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_whole.txt'));
% 
% % Cortical results
% writematrix(avg_DC_cortical, fullfile(network_folder, 'Average_DiceCoefficient_cortical.txt'));
% writematrix(std_DC_cortical, fullfile(network_folder, 'STDEV_DiceCoefficient_cortical.txt'));
% writematrix(DC_cortical, fullfile(network_folder, 'DiceCoefficientsMatrix_cortical.txt'));
% writematrix(avg_cDC_cortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_cortical.txt'));
% writematrix(std_cDC_cortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_cortical.txt'));
% writematrix(cDC_cortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_cortical.txt'));
% 
% % Subcortical results
% writematrix(avg_DC_subcortical, fullfile(network_folder, 'Average_DiceCoefficient_subcortical.txt'));
% writematrix(std_DC_subcortical, fullfile(network_folder, 'STDEV_DiceCoefficient_subcortical.txt'));
% writematrix(DC_subcortical, fullfile(network_folder, 'DiceCoefficientsMatrix_subcortical.txt'));
% writematrix(avg_cDC_subcortical, fullfile(network_folder, 'Average_continuousDiceCoefficient_subcortical.txt'));
% writematrix(std_cDC_subcortical, fullfile(network_folder, 'STDEV_continuousDiceCoefficient_subcortical.txt'));
% writematrix(cDC_subcortical, fullfile(network_folder, 'continuousDiceCoefficientsMatrix_subcortical.txt'));
% 
% end
