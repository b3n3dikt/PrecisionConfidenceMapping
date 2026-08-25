
clear all
%ad relavant paths
addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
wb_command='/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command';

% open random dscalar that has correct dimensions for given dataset
%define minutes
MIN='80min';
SES='combined';
TASK='restMENORDICrmnoisevols';
KERNEL='2.5';
%SES2='MESE'
SUB='1007001';
% load data
cd(['/home/smnelson/shared/projects/PrecBaby/adult_comparison/reliability_maps/sub-' SUB '/task-' TASK '/smoothing' KERNEL])
load(['rel_val_matrix_sub-' SUB '_ses-' SES '_smoothing' KERNEL '.mat']);
%input=['rel_val_sub-' SUB '_ses-' SES '_smoothing' KERNEL '_split_half.txt'];
%rel_val=readtable(input);
%all_rel_val=table2array(rel_val);
%avg_val=nanmean(all_rel_val(:,2,:),3);
%%
example_dscalar = cifti_read(['/home/miran045/shared/projects/WashU_Nordic/reliability_maps/test.dscalar.nii']);

% cd(['/home/smnelson/shared/projects/PrecBaby/dconns_reliability_maps/shuffled_runs/sub-' SUB '/ses-' SES '/smoothing' num2str(KERNEL)])
% load(['rel_val_matrix_sub-' SUB '_ses-' SES '_smoothing' num2str(KERNEL) '.mat'])
% add data to dscalar - pick highest amount of minutes and average over 100
% permutations
example_dscalar.cdata=squeeze(nanmean(all_rel_val(:,2,:),3));
%example_dscalar.cdata=all_rel_val;

dscalar_name=['sub-' SUB '_task-' TASK '_rel_map_' MIN '.dscalar.nii'];
cifti_write(example_dscalar, dscalar_name);

%%
settings.path{1}='/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.4.sh';
settings.path{2}='/projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene';  
settings.path{3}='/projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_scalar_MSI_abspaths.scene';
%settings.path{3}='/projects/standard/faird/shared/code/internal/utilities/figure_maker/MSC01_template_scene_subcort_label_MSI.scene'; 
settings.path{4}='/projects/standard/faird/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command'; % workbench command path
settings.path{5}='/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.L.very_inflated.32k_fs_LR.surf.gii';
settings.path{6}='/projects/standard/faird/shared/code/external/utilities/MSCcodebase-master/Utilities/Conte69_atlas-v2.LR.32k_fs_LR.wb/Conte69.R.very_inflated.32k_fs_LR.surf.gii';

make_subcortical_images = 'TRUE';
%pics_code_path = '/projects/standard/faird/shared/code/internal/utilities/figure_maker/make_dscalar_pics_v9.3.sh';
    pics_code_path = settings.path{1}; % path to figure_maker bash script.
 
%pics_folder = '/home/miran045/shared/projects/WashU_Nordic/MSC02_precision/whole_brain_map/restMErmnoisevols';
pics_folder = pwd;
scalar_name = [pics_folder '/' dscalar_name;];
output_name = dscalar_name(1:end-12);

cmd = [pics_code_path ' ' scalar_name ' ' output_name '_fig ' pics_folder ' FALSE 0 0.8 JET256 FALSE 0 0 THRESHOLD_TEST_SHOW_OUTSIDE TRUE  ' make_subcortical_images ' png 8 118 TRUE ' settings.path{4} ' ' settings.path{2} ' ' settings.path{3} ' ' settings.path{5} ' ' settings.path{6}];
disp(cmd);
system(cmd);

