
confmap=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/figures/Percent_Holdout-100/ciftis/Probability_Maps_across_perms_TM_Percent_holdout_SCAN_network_probability.dscalar.nii
dtseries=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/sub-PFM3T7T01/ses-combined/func/sub-PFM3T7T01_ses-combined_task-restMENORDICtrimmed-60minutes_truncated_bold.dtseries.nii
motionfile=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/sub-PFM3T7T01/ses-combined/func/sub-PFM3T7T01_ses-combined_task-restMENORDICtrimmed-60minutes_desc-dcan_qc_power_2014_FD_only.mat
left_surf=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/sub-PFM3T7T01/ses-combined/anat/sub-PFM3T7T01_ses-combined_space-fsLR_den-32k_hemi-L_desc-hcp_midthickness.surf.gii

right_surf=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/sub-PFM3T7T01/ses-combined/anat/sub-PFM3T7T01_ses-combined_space-fsLR_den-32k_hemi-R_desc-hcp_midthickness.surf.gii
thr=0
outdir=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-60m/figures/Percent_Holdout-100/ciftis/Thresholded-${thr}
label_base=SCAN_conf_clusters



/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/confmap2seed.sh \
   --confmap      "${confmap}" \
   --dtseries     "${dtseries}" \
   --left_surf    "${left_surf}" \
   --right_surf   "${right_surf}" \
   --thr          "${thr}" \
   --outdir       "${outdir}" \
   --label_base   "${label_base}" \
   --motion_conc  "${motionfile}"





   /projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/confmap2seed.sh --confmap ${confmap} --dtseries ${dtseries} --left_surf ${left_surf} --right_surf ${right_surf} --thr ${thr} --outdir ${outdir} --label_base ${label_base} --motion_conc ${motionfile}

#Step 1) Binerize confmap at a given threshold. I.e. if you have the SCAN conf map turn everything above a given value 
SUB=PFM3T7T01
SES=combined
basename=ExpData-8m
basedir=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-${SUB}/ses-${SES}/${basename}/
threshold=0.99
cifti_in=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/figures/Percent_Holdout-100/ciftis/Probability_Maps_across_perms_TM_Percent_holdout_SCAN_network_probability.dscalar.nii
outdir=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/figures/Percent_Holdout-100/ciftis/Thresholded-${threshold}
binary_cifti_out=Binary_SCAN_network_probability_thresholded_at-${threshold}.dscalar.nii
mkdir -p ${outdir}

wb_command -cifti-math "x > ${threshold}" ${outdir}/${binary_cifti_out} -var x ${cifti_in}

#Step 2) run https://www.humanconnectome.org/software/workbench-command/-cifti-find-clusters on this to seperate out the different SCAN nodes into unique values. 

clustered_dscalar=Clustered_SCAN_network_probability_thresholded_at-${threshold}.dscalar.nii


#anat_dir=/home/yaco0006/shared/projects/Baby7T/derivatives/XCP-D_derivatives/ION${SUB}_${SES}_combined/sub-${SUB}/ses-${SES}/anat
#thicknessL=${anat_dir}/sub-${SUB}_ses-${SES}_hemi-L_space-fsLR_den-32k_desc-hcp_midthickness.surf.gii
thicknessL=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/sub-PFM3T7T01/ses-combined/anat/sub-PFM3T7T01_ses-combined_space-fsLR_den-32k_hemi-L_desc-hcp_midthickness.surf.gii

thicknessR=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/sub-PFM3T7T01/ses-combined/anat/sub-PFM3T7T01_ses-combined_space-fsLR_den-32k_hemi-R_desc-hcp_midthickness.surf.gii

#taskfolder=/home/yaco0006/shared/projects/Baby7T/analysis/oddball_task

#in=${taskfolder}/sub-${SUB}_acq-${ACQ}_thresholded_p0.01_from_noise_abs_for_clustering_noderiv_nodisp.dscalar.nii
out=${taskfolder}/sub-${SUB}_acq-${ACQ}_clustermask_0.01_noderiv_nodisp.dscalar.nii

#module load workbench
wb_command -cifti-find-clusters ${outdir}/${binary_cifti_out} 0.1 100 0.1 100 COLUMN ${outdir}/${clustered_dscalar} -left-surface ${thicknessL} -right-surface ${thicknessR}

#Step 3) turn new clusters into a dlable file. 

clustered_dlabel=Clustered_SCAN_network_probability_thresholded_at-${threshold}.dlabel.nii

wb_command -cifti-label-import ${outdir}/${clustered_dscalar} "" ${outdir}/${clustered_dlabel}


#Step 4) parcellate dtseries using label. 
dtseries_path=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/sub-PFM3T7T01/ses-combined/func/sub-PFM3T7T01_ses-combined_task-restMENORDICtrimmed-8minutes_truncated_bold.dtseries.nii
motion_path=/projects/standard/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bootstrap_reliability_curves_percent_split-100/sub-PFM3T7T01/ses-combined/ExpData-8m/sub-PFM3T7T01/ses-combined/func/sub-PFM3T7T01_ses-combined_task-restMENORDICtrimmed-8minutes_desc-dcan_qc_power_2014_FD_only.mat
clustered_ptseries=Clustered_SCAN_network_probability_timeseries_thresholded_at-${threshold}.ptseries.nii
wb_command -cifti-parcellate ${dtseries_path} ${outdir}/${clustered_dlabel} COLUMN  ${outdir}/${clustered_ptseries} 

#step 5) run seed connectivity analysis on each label. 



#/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/make_seedmap.m

cifti_conn_matrix_to_corr_pt_dt('/projects/standard/faird/shared/projects/HighField_7T/seedAnalysisdtseries.conc', '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysisptseries.conc', 'none', .2 ,1.75, 1, 15, 'none', 'none', 'none', '/home/feczk001/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command', 'mean', 0, 0, 0, '/projects/standard/faird/shared/projects/HighField_7T/seedMaps/')




% make_seedmap.m
% -------------------------------------------------------------------------
% Function: make_seedmap
% Purpose : Generate seedbased connectivity maps (seed maps) **for every
%           nonzero cluster label** present in a clustered .ptseries.nii.
%           Designed to be called noninteractively from a bash wrapper
%           (e.g. confmap2seed.sh) after the Workbench clustering step.
%
% Usage (MATLAB / Octave, R2022b+ recommended):
%   make_seedmap(ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, ...
%                'Name', value, ... )
%
% Required positional args
%   ptseries        clustered .ptseries.nii (one column per ROI label)
%   dtConc          .conc file listing the dtseries you want to correlate
%   motionConc      .conc file listing motion (.mat) files, onetoone with dtConc
%   leftSurfConc    .conc file listing lefthemisphere midthickness surfaces
%   rightSurfConc   .conc file listing righthemisphere midthickness surfaces
%
% Key optional NameValue arguments (defaults shown):
%   'OutDir'        : [ptseriesDir '/seedMaps']
%   'UtilitiesRoot' : '/projects/standard/faird/shared/code/internal/utilities'
%   'FdThresh'      : 0.2
%   'TR'            : 0.8               % seconds
%   'Minutes'       : 0                 % 0  use all frames
%   'SmoothKernel'  : 2.25              % mm FWHM
%   'wbCommand'     : getenv('WB_COMMAND') or 'wb_command' on PATH
%   'MeanOrPCA'     : 'mean'            % or 'pca'
%   'NumComponents' : 0                 % used if MeanOrPCA=='pca'
%   'FisherZ'       : 0                 % 1  Fisherz transform
%   'RemoveOutliers': 1
%
% The function automatically:
%   " Adds required Fairlab utility toolboxes (CIFTI, Matlab_CIFTI, seed_map_wrapper)
%   " Creates a temporary .conc that points to *this* ptseries
%   " Detects unique ROI labels (nonzero) in the ptseries
%   " Calls cifti_conn_matrix_to_corr_pt_dt for each ROI, writing results to
%     <OutDir>/Cluster_###/
% -------------------------------------------------------------------------
function make_seedmap(ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, varargin)

%% ------------------------------- Parse inputs ---------------------------

p = inputParser;
addRequired(p,'ptseries',@(x)exist(x,'file')==2);
addRequired(p,'dtConc', @(x)exist(x,'file')==2);
addRequired(p,'motionConc',@(x)exist(x,'file')==2);
addRequired(p,'leftSurfConc',@(x)exist(x,'file')==2);
addRequired(p,'rightSurfConc',@(x)exist(x,'file')==2);

% Namevalue pairs
addParameter(p,'OutDir', fullfile(fileparts(ptseries),'seedMaps'), @ischar);
addParameter(p,'UtilitiesRoot','/projects/standard/faird/shared/code/internal/utilities',@ischar);
addParameter(p,'FdThresh',0.2,@isnumeric);
addParameter(p,'TR',0.8,@isnumeric);
addParameter(p,'Minutes',0,@isnumeric);
addParameter(p,'SmoothKernel',2.25,@isnumeric);
addParameter(p,'wbCommand', '', @ischar);
addParameter(p,'MeanOrPCA','mean',@(x)any(strcmpi(x,{'mean','pca'})));
addParameter(p,'NumComponents',0,@isnumeric);
addParameter(p,'FisherZ',0,@isnumeric);
addParameter(p,'RemoveOutliers',1,@isnumeric);
parse(p, ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, varargin{:});
C = p.Results;               % shorthand

if isempty(C.wbCommand)
    if ~isempty(getenv('WB_COMMAND'))
        C.wbCommand = getenv('WB_COMMAND');
    else
        C.wbCommand = 'wb_command'; % assume on PATH
    end
end

%% ------------------------- Toolbox path handling ------------------------
addpath(genpath(fullfile(C.UtilitiesRoot,'CIFTI')));
addpath(genpath(fullfile(C.UtilitiesRoot,'Matlab_CIFTI')));
addpath(genpath(fullfile(C.UtilitiesRoot,'seed_map_wrapper')));

%% ----------------------- Create output directories ----------------------
if ~exist(C.OutDir,'dir'); mkdir(C.OutDir); end

%% --------------------- Identify ROI labels in ptseries ------------------
pt = ciftiopen(ptseries, C.wbCommand);  % returns struct with .cdata
labels = unique(pt.cdata);
labels(labels==0) = [];
if isempty(labels)
    error('No nonzero ROI labels found in %s', ptseries);
end
nROI = numel(labels);

%% -------------------- Temporary .conc pointing to ptseries --------------
ptConcPath = fullfile(C.OutDir, 'tmp_ptseries.conc');
fid = fopen(ptConcPath,'w'); fprintf(fid,'%s\n',ptseries); fclose(fid);

%% ----------------------------- Main loop --------------------------------
for ii = 1:nROI
    roiIdx = labels(ii);
    fprintf('[%d/%d] Generating seed map for ROI label %d ...\n', ii, nROI, roiIdx);

    roiOut = fullfile(C.OutDir, sprintf('Cluster_%03d', roiIdx));
    if ~exist(roiOut,'dir'); mkdir(roiOut); end

    cifti_conn_matrix_to_corr_pt_dt( ...
        dtConc, ptConcPath, motionConc, ...
        C.FdThresh, C.TR, roiIdx, C.Minutes, C.SmoothKernel, ...
        leftSurfConc, rightSurfConc, ...
        C.wbCommand, ...
        C.MeanOrPCA, C.NumComponents, C.FisherZ, C.RemoveOutliers, ...
        roiOut);
end

fprintf('\n  All seed maps written to %s\n', C.OutDir);
end





% make_seedmap.m
% -------------------------------------------------------------------------
% Function: make_seedmap
% Purpose : Generate seedbased connectivity maps (seed maps) **for every
%           nonzero cluster label** present in a clustered .ptseries.nii.
%           Designed to be called noninteractively from a bash wrapper
%           (e.g. confmap2seed.sh) after the Workbench clustering step.
%
% Usage (MATLAB / Octave, R2022b+ recommended):
%   make_seedmap(ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, ...
%                'Name', value, ... )
%
% Required positional args
%   ptseries        clustered .ptseries.nii (one column per ROI label)
%   dtConc          .conc file listing the dtseries you want to correlate
%   motionConc      .conc file listing motion (.mat) files, onetoone with dtConc
%   leftSurfConc    .conc file listing lefthemisphere midthickness surfaces
%   rightSurfConc   .conc file listing righthemisphere midthickness surfaces
%
% Key optional NameValue arguments (defaults shown):
%   'OutDir'        : [ptseriesDir '/seedMaps']
%   'UtilitiesRoot' : '/projects/standard/faird/shared/code/internal/utilities'
%   'FdThresh'      : 0.2
%   'TR'            : 0.8               % seconds
%   'Minutes'       : 0                 % 0  use all frames
%   'SmoothKernel'  : 2.25              % mm FWHM
%   'wbCommand'     : getenv('WB_COMMAND') or 'wb_command' on PATH
%   'MeanOrPCA'     : 'mean'            % or 'pca'
%   'NumComponents' : 0                 % used if MeanOrPCA=='pca'
%   'FisherZ'       : 0                 % 1  Fisherz transform
%   'RemoveOutliers': 1
%
% The function automatically:
%   " Adds required Fairlab utility toolboxes (CIFTI, Matlab_CIFTI, seed_map_wrapper)
%   " Creates a temporary .conc that points to *this* ptseries
%   " Detects unique ROI labels (nonzero) in the ptseries
%   " Calls cifti_conn_matrix_to_corr_pt_dt for each ROI, writing results to
%     <OutDir>/Cluster_###/
% -------------------------------------------------------------------------
function make_seedmap(ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, varargin)

%% ------------------------------- Parse inputs ---------------------------

p = inputParser;
addRequired(p,'ptseries',@(x)exist(x,'file')==2);
addRequired(p,'dtConc', @(x)exist(x,'file')==2);
addRequired(p,'motionConc',@(x)exist(x,'file')==2);
addRequired(p,'leftSurfConc',@(x)exist(x,'file')==2);
addRequired(p,'rightSurfConc',@(x)exist(x,'file')==2);

% Namevalue pairs
addParameter(p,'OutDir', fullfile(fileparts(ptseries),'seedMaps'), @ischar);
addParameter(p,'UtilitiesRoot','/projects/standard/faird/shared/code/internal/utilities',@ischar);
addParameter(p,'FdThresh',0.2,@isnumeric);
addParameter(p,'TR',0.8,@isnumeric);
addParameter(p,'Minutes',0,@isnumeric);
addParameter(p,'SmoothKernel',2.25,@isnumeric);
addParameter(p,'wbCommand', '', @ischar);
addParameter(p,'MeanOrPCA','mean',@(x)any(strcmpi(x,{'mean','pca'})));
addParameter(p,'NumComponents',0,@isnumeric);
addParameter(p,'FisherZ',0,@isnumeric);
addParameter(p,'RemoveOutliers',1,@isnumeric);
parse(p, ptseries, dtConc, motionConc, leftSurfConc, rightSurfConc, varargin{:});
C = p.Results;               % shorthand

if isempty(C.wbCommand)
    if ~isempty(getenv('WB_COMMAND'))
        C.wbCommand = getenv('WB_COMMAND');
    else
        C.wbCommand = 'wb_command'; % assume on PATH
    end
end

%% ------------------------- Toolbox path handling ------------------------
addpath(genpath(fullfile(C.UtilitiesRoot,'CIFTI')));
addpath(genpath(fullfile(C.UtilitiesRoot,'Matlab_CIFTI')));
addpath(genpath(fullfile(C.UtilitiesRoot,'seed_map_wrapper')));

%% ----------------------- Create output directories ----------------------
if ~exist(C.OutDir,'dir'); mkdir(C.OutDir); end

%% --------------------- Identify ROI labels in ptseries ------------------
pt = ciftiopen(ptseries, C.wbCommand);  % returns struct with .cdata
labels = unique(pt.cdata);
labels(labels==0) = [];
if isempty(labels)
    error('No nonzero ROI labels found in %s', ptseries);
end
nROI = numel(labels);

%% -------------------- Temporary .conc pointing to ptseries --------------
ptConcPath = fullfile(C.OutDir, 'tmp_ptseries.conc');
fid = fopen(ptConcPath,'w'); fprintf(fid,'%s\n',ptseries); fclose(fid);

%% ----------------------------- Main loop --------------------------------
for ii = 1:nROI
    roiIdx = labels(ii);
    fprintf('[%d/%d] Generating seed map for ROI label %d ...\n', ii, nROI, roiIdx);

    roiOut = fullfile(C.OutDir, sprintf('Cluster_%03d', roiIdx));
    if ~exist(roiOut,'dir'); mkdir(roiOut); end

    cifti_conn_matrix_to_corr_pt_dt( ...
        dtConc, ptConcPath, motionConc, ...
        C.FdThresh, C.TR, roiIdx, C.Minutes, C.SmoothKernel, ...
        leftSurfConc, rightSurfConc, ...
        C.wbCommand, ...
        C.MeanOrPCA, C.NumComponents, C.FisherZ, C.RemoveOutliers, ...
        roiOut);
end

fprintf('\n  All seed maps written to %s\n', C.OutDir);
end




% seedmap_cluster_driver.m
% -------------------------------------------------------------------------
% Generate seedbased functional connectivity maps ("seed maps") for **each
% cluster label** produced by your Workbench `cifti-find-clusters` step.
%
% Core workflow
%   1. Load the clusterwise ptseries produced earlier.
%   2. Detect every nonzero label (each label is one cluster/ROI).
%   3. For each label, call `cifti_conn_matrix_to_corr_pt_dt` (Fair et al.)
%      to compute a wholebrain correlation map.
%   4. Save the outputs into <outDir>/Cluster_<label>/ &
%
% -------------------------------------------------------------------------
% USER SETTINGS  -----------------------------------------------------------
conf.ptseries      = '/ABS/PATH/Clusters_SCAN_thr0.99.ptseries.nii';
conf.dtConc        = '/ABS/PATH/rest.dt.conc';    % list of dtseries
conf.motionConc    = '/ABS/PATH/rest_motion.conc';% list of .mat FD files
conf.lSurfConc     = '/ABS/PATH/left_midthick.conc';
conf.rSurfConc     = '/ABS/PATH/right_midthick.conc';

conf.fdThresh      = 0.2;      % FD threshold (Power 2014)
conf.tr            = 0.8;      % TR (s)
conf.minutes       = 0;        % 0  use all timepoints
conf.smoothKernel  = 2.25;     % FWHM (mm) for surface smoothing
conf.wbCommand     = '/abs/path/to/wb_command';
conf.meanOrPCA     = 'mean';   % 'mean' or 'pca'
conf.numComponents = 0;        % used only when meanOrPCA='pca'
conf.fisherZ       = 0;        % 1  Ztransform correlations
conf.removeOutliers= 1;        % despike/extreme value removal
conf.outDir        = '/ABS/PATH/seedMaps';  % results directory

% PATHS TO TOOLBOXES -------------------------------------------------------
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/CIFTI'));
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/Matlab_CIFTI'));
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/seed_map_wrapper')); % contains cifti_conn_matrix_to_corr_pt_dt

% -------------------------------------------------------------------------
% SCRIPT  (no edits required below unless custom tweaks)
% -------------------------------------------------------------------------
if ~exist(conf.outDir,'dir'); mkdir(conf.outDir); end

% -------------------------------------------------------------------------
% 1. Identify cluster labels
% -------------------------------------------------------------------------
pt = ciftiopen(conf.ptseries, conf.wbCommand);   % load ptseries header + data
labels = unique(pt.cdata);
labels(labels==0) = [];                          % drop background
nROI = numel(labels);

% Temporary .conc file pointing to *this* ptseries ------------------------
ptConcPath = fullfile(conf.outDir, 'tmp_ptseries.conc');
fid = fopen(ptConcPath,'w'); fprintf(fid, '%s\n', conf.ptseries); fclose(fid);

% -------------------------------------------------------------------------
% 2. Loop over ROIs and generate seed maps
% -------------------------------------------------------------------------
for ii = 1:nROI
    roiIdx = labels(ii);
    fprintf('(%02d/%02d) ROI label = %d\n', ii, nROI, roiIdx);

    % Each ROI gets its own subfolder for clarity
    roiOut = fullfile(conf.outDir, sprintf('Cluster_%03d', roiIdx));
    if ~exist(roiOut,'dir'); mkdir(roiOut); end

    % Call Fairlab wrapper
    cifti_conn_matrix_to_corr_pt_dt( ...
        conf.dtConc, ptConcPath, conf.motionConc, ...
        conf.fdThresh, conf.tr, roiIdx, conf.minutes, conf.smoothKernel, ...
        conf.lSurfConc, conf.rSurfConc, ...
        conf.wbCommand, ...
        conf.meanOrPCA, conf.numComponents, conf.fisherZ, conf.removeOutliers, ...
        roiOut);
end

fprintf('\nAll seed maps written to: %s\n', conf.outDir);






%% Setup

%Setting up directory
cd('/projects/standard/faird/shared/projects/HighField_7T');

%Adding various paths 
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/CIFTI'));
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/seed_map_wrapper'));
addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/Matlab_CIFTI'));
%addpath(genpath('/projects/standard/faird/shared/code/internal/utilities/cifti_tools'));

%Setting up variables
dtConc = '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysisdtseries.conc';
ptConc = '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysisptseries.conc';
motionConc = '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysisMotion.conc';
fdThresh = .2;
tr = 1.75;
allROIs = 1; %If you want to run through all ROIs or not
specificROI = 8; %Which ROI you'd like to run through if not
minutes = 80; %Should use all minutes
smoothingKernel = 2.25;
lSurface = '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysismidL.conc';
rSurface = '/projects/standard/faird/shared/projects/HighField_7T/seedAnalysismidR.conc';
wbCommand = '/home/feczk001/shared/code/external/utilities/workbench/1.4.2/workbench/bin_rh_linux64/wb_command';
meanOrPCA = 'mean';
numComponents = 0;
fischerZ = 0;
removeOutliers = 1;
outDir = '/projects/standard/faird/shared/projects/HighField_7T/seedMaps';

%% Running command

if allROIs == 1
    for indexROI = 1:8 %Loop through all ROIS
        cifti_conn_matrix_to_corr_pt_dt(dtConc, ptConc, motionConc, ...
            fdThresh, tr, indexROI, minutes, smoothingKernel,...
            lSurface, rSurface, ...
            wbCommand, ...
            meanOrPCA, numComponents, fischerZ, removeOutliers, ...
            outDir)
    end
else
    cifti_conn_matrix_to_corr_pt_dt(dtConc, ptConc, motionConc, ...
            fdThresh, tr, specificROI, minutes, smoothingKernel,...
            lSurface, rSurface, ...
            wbCommand, ...
            meanOrPCA, numComponents, fischerZ, removeOutliers, ...
            outDir)
    
end

%% Loading the resulting dscalar

 %dscalar = cifti2mat(['/projects/standard/faird/shared/projects/HighField_7T/seedMaps/sub-101_ses-1_task-restMENORDICrmnoisevols_space-fsLR_den-91k_desc-denoisedSmoothed_bold_spatially_interpolated_15_minutes_of_data_at_FD_0.2_ROI3.dscalar.nii']);