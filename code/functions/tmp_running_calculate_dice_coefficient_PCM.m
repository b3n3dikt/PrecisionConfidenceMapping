/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/make_figs_and_dscalars_testing.sh
%% running without conf map 
network_name='DMN'
network_name='AllNetworks'

ConfMap=0
threshold=0.6
fig_dir='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined/PCMconfmapFigure_DiceCoCortSubCort_testing/testing'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//RefData-70m/sub-1003601_ses-combined_mode_map_rep100.conc'
%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//ExpData-70m/sub-1003601_ses-combined_successful_percent_holdout-50.conc'

dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined/figures_PCM2Standard/RefData-70m_to_RefData-70m/tmp.conc'
dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined/figures_PCM2Standard/RefData-70m_to_RefData-70m/sub-1003601_ses-combined_RefData-70m-RefData-70m_PCM_with_standard_template_matching.conc'

%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/ExpData-5m/sub-1003601_ses-combined_PCM_network-Aud.conc'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/RefData-70m/sub-1003601_ses-combined_PCM_network-Aud.conc'
%BASEDIR='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/PCMconfmapFigure_testing'
BASEDIR='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/PCMconfmapFigure_DiceCoCortSubCort_Testing/'


%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-DMN.conc'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//ExpData-65m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-DMN.conc'

%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-Tpole.conc'
%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-Tpole.conc'
thresholdTarget='both'
%calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)
calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, thresholdTarget, fig_dir)

%% running with conf map

addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/');
calculate_dice_coefficient_PCM_cortsubcort('/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined/', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-100/ciftis/sub-1003601_ses-combined_PCM_network-Tpole.conc', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//ExpData-3m/figures/Percent_Holdout-100/ciftis/sub-1003601_ses-combined_PCM_network-Tpole.conc', 'Tpole', 1, 0.8, 'both', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//PCMconfmapFigure_DiceCoCortSubCort/ExpData-3m_to_RefData-70m');


%%

calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)



addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); 
calculate_dice_coefficient_PCM_cortsubcort('/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-SMd.conc', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//ExpData-35m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-SMd.conc', 'SMd', , 0.6, /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//PCMconfmapFigure_DiceCoCortSubCort/ExpData-35m_to_RefData-70m);
calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)


/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/make_figs_and_dscalars_testing.sh 
BASEDIR='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined/'
dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-100/ciftis/sub-1003601_ses-combined_standardTM_network-All.conc'
dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//ExpData-70m/figures/Percent_Holdout-100/ciftis/sub-1003601_ses-combined_standardTM_network-All.conc'
network_name='All' 

ConfMap=0 
threshold=0
%/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//StandardTM_TrajectoryFigure_DiceCoCortSubCort/ExpData-70m_to_RefData-70m

 
thresholdTarget='both'
fig_dir='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-100/sub-1003601/ses-combined//StandardTM_TrajectoryFigure_DiceCoCortSubCort/ExpData-70m_to_RefData-70m'


calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, thresholdTarget, fig_dir)

matlab -nodisplay -nosplash -r "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); calculate_dice_coefficient_PCM_cortsubcort('${BASEDIR}', '${dscalarswithassignments1}', '${dscalarswithassignments2}', '${network_name}', '${make_NetConfMaps}', ${threshold}, '${thresholdTarget}','${fig_dir}'); exit;"



, ConfMap, threshold, fig_dir
calculate_dice_coefficient_PCM_cortsubcort(BASEDIR, dscalarswithassignments1, dscalarswithassignments2, network_name, ConfMap, threshold, fig_dir)

calculate_dice_coefficient_PCM_cortsubcort('/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//RefData-70m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-SMd.conc', '/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//ExpData-35m/figures/Percent_Holdout-80/ciftis/sub-1003601_ses-combined_PCM_network-SMd.conc', 'SMd', , 0.6, /projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined//PCMconfmapFigure_DiceCoCortSubCort/ExpData-35m_to_RefData-70m);


%network_name='Aud'
%ConfMap=1
%threshold=0
%fig_dir='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/PCMconfmapFigure_testing'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//RefData-70m/sub-1003601_ses-combined_mode_map_rep100.conc'
%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-50/sub-1003601/ses-combined//ExpData-70m/sub-1003601_ses-combined_successful_percent_holdout-50.conc'
%dscalarswithassignments1='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/ExpData-5m/sub-1003601_ses-combined_PCM_network-Aud.conc'
%dscalarswithassignments2='/projects/standard/smnelson/shared/projects/subPop/PreConfMapping/analyses/PCM/reliability_curves_percent_split-80/sub-1003601/ses-combined/RefData-70m/sub-1003601_ses-combined_PCM_network-Aud.conc'



addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/');
addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks'))
min=1;
i=min;
perm=1;
r=perm;
muI(min,perm,1) = MutualInformation(Cdata, Mdata); %Mutual information
[VIn(i,r,1), MIn(i,r,1)] = partition_distance(Cdata, Mdata); %Normalized variation of information ([p, q] matrix), Normalized mutual information ([p, q] matrix)

