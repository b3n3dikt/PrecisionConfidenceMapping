function [cmd] = plot_surface_and_subcorticals_parcellation(dscalar, BASEDIR, lowercolor, uppercolor, lowerthresh, upperthresh, colorscheme)

%clear all
% STANDALONE PCM: Removed hardcoded addpath calls and hardcoded wb_command.
% All paths computed relative to this file's location.
this_fn = mfilename('fullpath');
[fn_dir, ~] = fileparts(this_fn);
pcm_root    = fileparts(fileparts(fn_dir));
fig_dir     = fullfile(pcm_root, 'deps', 'figure_maker');
conte69_dir = fullfile(pcm_root, 'deps', 'Conte69_surfaces');
wb_command  = 'wb_command';
% open random dscalar that has correct dimensions for given dataset
%define minutes
%dscalar='/panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/figures/AllPerms/Probability_Maps_100_perm_TM_Split_half-1_Aud_network_probability.dscalar.nii';

%BASEDIR='/panfs/jay/groups/34/yaco0006/shared/projects/NSD/analyses/TemplateMatching/rest_scans/sub-01/ses-combined/figures'
%lowerthresh=0.01
%upperthresh=1
%colorscheme=[ 'ROY-BIG-BL' ]
threshold_image=[ 'TRUE' ]; % shift # set TRUE if you want to exclude data outside/inside thresholds, palette is assumed to be Power Colors.  If true, scene file will use RBG colors.
% threshold_lower=${1}; shift # lower threshold for color palette
% threshold_upper=${1}; shift # upper threshold for color palettethreshold_inout=${1}; shift # Threshold set "inside" or "outside"
% threshold_inout=${1}; shift # Threshold set "inside" or "outside"

% 
% MIN='80min';
% SES='combined';
% TASK='restMENORDICrmnoisevols';
% KERNEL='2.5';
% %SES2='MESE'
% SUB='1007001';
% % load data
% cd(['/home/smnelson/shared/projects/PrecBaby/adult_comparison/reliability_maps/sub-' SUB '/task-' TASK '/smoothing' KERNEL])
% load(['rel_val_matrix_sub-' SUB '_ses-' SES '_smoothing' KERNEL '.mat']);
%input=['rel_val_sub-' SUB '_ses-' SES '_smoothing' KERNEL '_split_half.txt'];
%rel_val=readtable(input);
%all_rel_val=table2array(rel_val);
%avg_val=nanmean(all_rel_val(:,2,:),3);
%%
%example_dscalar = cifti_read(['/home/miran045/shared/projects/WashU_Nordic/reliability_maps/test.dscalar.nii']);
example_dscalar = cifti_read(dscalar);


% The full path to the dscalar file
% The full path to the dscalar file
% The full path to the dscalar file

% Split the path into folder path and file name with extension
[folderPath, fileName, ext] = fileparts(dscalar);

% Since fileparts only captures '.nii' as the extension for files with double extensions,
% we concatenate it with the part of the fileName that includes '.dscalar' to reconstruct
% the full extension.
ext = strcat('.dscalar', ext);

% Extract the base file name without '.dscalar.nii'
baseFileName = fileName(1:end-length('.dscalar'));
dscalar_name = strcat(baseFileName, ext);


% cd(['/home/smnelson/shared/projects/PrecBaby/dconns_reliability_maps/shuffled_runs/sub-' SUB '/ses-' SES '/smoothing' num2str(KERNEL)])
% load(['rel_val_matrix_sub-' SUB '_ses-' SES '_smoothing' num2str(KERNEL) '.mat'])
% add data to dscalar - pick highest amount of minutes and average over 100
% permutations
%example_dscalar.cdata=squeeze(nanmean(all_rel_val(:,2,:),3));
%example_dscalar.cdata=all_rel_val;

%dscalar_name=['sub-' SUB '_task-' TASK '_rel_map_' MIN '.dscalar.nii'];
%cifti_write(example_dscalar, dscalar_name);

%%
% STANDALONE PCM: paths computed relative to this file (see top of function)
settings.path{1} = fullfile(fig_dir, 'make_dscalar_pics_v9.4.sh');
settings.path{2} = fullfile(fig_dir, 'MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene');
settings.path{3} = fullfile(fig_dir, 'MSC01_template_scene_subcort_scalar_MSI_abspaths.scene');
settings.path{4} = wb_command;
settings.path{5} = fullfile(conte69_dir, 'Conte69.L.very_inflated.32k_fs_LR.surf.gii');
settings.path{6} = fullfile(conte69_dir, 'Conte69.R.very_inflated.32k_fs_LR.surf.gii');

make_subcortical_images = 'TRUE';
%pics_code_path = '/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.3.sh';
    pics_code_path = settings.path{1}; % path to figure_maker bash script.
 
%pics_folder = '/home/miran045/shared/projects/WashU_Nordic/MSC02_precision/whole_brain_map/restMErmnoisevols';
%pics_folder = pwd;
pics_folder = BASEDIR;
%scalar_name = [pics_folder '/' dscalar_name;];
scalar_name = dscalar;
output_name = [BASEDIR '/' baseFileName]
output_name = dscalar_name(1:end-12);

%cmd = [pics_code_path ' ' scalar_name ' ' output_name '_fig ' pics_folder ' FALSE 0 0.8 JET256 FALSE 0 0 THRESHOLD_TEST_SHOW_OUTSIDE TRUE  ' make_subcortical_images ' png 8 118 TRUE ' settings.path{4} ' ' settings.path{2} ' ' settings.path{3} ' ' settings.path{5} ' ' settings.path{6}];
cmd = [pics_code_path ' ' scalar_name ' ' output_name '_fig ' pics_folder ' FALSE ' num2str(lowercolor) ' ' num2str(uppercolor) ' ' colorscheme ' ' threshold_image ' ' num2str(lowerthresh) ' ' num2str(upperthresh) ' THRESHOLD_TEST_SHOW_INSIDE TRUE  ' make_subcortical_images ' png 8 118 TRUE ' settings.path{4} ' ' settings.path{2} ' ' settings.path{3} ' ' settings.path{5} ' ' settings.path{6}];
disp(cmd);
system(cmd);

