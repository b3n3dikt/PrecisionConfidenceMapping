function calculate_dice_coefficient(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, fig_dir)

% Check if fig_dir is provided as an input
if nargin < 4 || isempty(fig_dir)
    fig_dir = [BASEDIR '/figures/DiceCoefficient'];
end

mkdir(fig_dir);

%fig_dir='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined/testing'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//RefData-70m/sub-1003601_ses-combined_mode_map_rep100.conc'
%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//ExpData-70m/sub-1003601_ses-combined_successful_percent_holdout-50.conc'
%addpath(genpath('/projects/standard/faird/ramirezj/code/internal/HighField'))
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
%addpath(genpath('/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/read_write_cifti/'));

addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'))
WB_DIR = '/common/software/install/migrated/workbench/1.5.0/bin_rh_linux64';


% Load the dscalar file lists
dscalar_list1 = load_dscalar_list(dscalarswithassignments1);
dscalar_list2 = load_dscalar_list(dscalarswithassignments2);

% Check if the lists have the same length
if length(dscalar_list1) ~= length(dscalar_list2)
    error('The two dscalar lists do not have the same number of files.');
end
num_permutations = length(dscalar_list1); % Total number of comparisons
tempscalar = dscalar_list1{1};
tmpdscalar = cifti_read(tempscalar);
tmpdata = tmpdscalar.cdata;
num_networks=length(unique(tmpdata));
DC = zeros(num_networks, num_permutations);
cDC = zeros(num_networks, num_permutations);

for s = 1:length(dscalar_list1)

    dscalar1 = dscalar_list1{s};
    dscalar2 = dscalar_list2{s};

    % Load data and perform analysis
    Mdscalar = cifti_read(dscalar1);
    Mdata = Mdscalar.cdata;

    Cdscalar = cifti_read(dscalar2);
    Cdata = Cdscalar.cdata;

    unique_networks = unique([Mdata; Cdata]);
    % Initialize a cell array to store the vectors
    network_vectors_dscalar1 = cell(length(unique_networks), 1);
    network_vectors_dscalar2 = cell(length(unique_networks), 1);
 
    for i = 1:length(unique_networks)
        j = unique_networks(i);
        % Create a logical vector for the current network
        dscalar1_net = (Mdata == j);
        
        % Convert logical vector to double (0's and 1's)
        dscalar1_net = double(dscalar1_net);
        
        % Store the vector in the cell array
        network_vectors_dscalar1{i} = dscalar1_net;
        
        dscalar2_net = (Cdata == j);
        
        % Convert logical vector to double (0's and 1's)
        dscalar2_net = double(dscalar2_net);
        
        % Store the vector in the cell array
        network_vectors_dscalar2{i} = dscalar2_net;

        cDC(i,s) = continuous_Dice_coefficient(dscalar1_net, dscalar2_net);
        %all_cDice = [cDC];
    
        % Binarize segmentation result
        binary_segmentation_result = zeros(size(dscalar2_net));
        binary_segmentation_result(dscalar2_net > 0.01) = 1;
    
        % Compute Dice coefficient
        DC(i,s) = Dice_coefficient(dscalar1_net, binary_segmentation_result);
        %all_Dice = [DC];
    end

end

% Calculate averages and standard deviations across permutations if more than one permutation
if num_permutations > 1
    avg_cDC = mean(cDC, 2);
    std_cDC = std(cDC, 0, 2);
    avg_DC = mean(DC, 2);
    std_DC = std(DC, 0, 2);
else
    avg_cDC = cDC;
    std_cDC = zeros(size(cDC));  % Standard deviation is zero when there's only one permutation
    avg_DC = DC;
    std_DC = zeros(size(DC));  % Standard deviation is zero when there's only one permutation
end

% Write results to files
writematrix(avg_DC, fullfile(fig_dir, 'Average_DiceCoefficient.txt'));
writematrix(std_DC, fullfile(fig_dir, 'STDEV_DiceCoefficient.txt'));
writematrix(DC, fullfile(fig_dir, 'DiceCoefficientsMatrix.txt'));


% function segmentation_result = simulate_probabilistic_segmentation(start, end_)
%     [x, y] = meshgrid(linspace(start, end_, 100), linspace(start, end_, 100));
%     d = sqrt(x .^ 2 + y .^ 2);
%     mu = 0.0;
%     sigma = 2.0;
%     segmentation_result = exp(-((d - mu) .^ 2) / (2.0 * sigma ^ 2));
%     segmentation_result(segmentation_result < 0.01) = 0;
% end
% 
% function cDC = continuous_Dice_coefficient(A_binary, B_probability_map)
%     AB = A_binary .* B_probability_map;
%     c = sum(AB(:)) / max(nnz(AB), 1);
%     cDC = 2 * sum(AB(:)) / (c * sum(A_binary(:)) + sum(B_probability_map(:)));
% end
% 
% function DC = Dice_coefficient(A_binary, B_binary)
%     AB = A_binary .* B_binary;
%     DC = 2 * sum(AB(:)) / (sum(A_binary(:)) + sum(B_binary(:)));
% end