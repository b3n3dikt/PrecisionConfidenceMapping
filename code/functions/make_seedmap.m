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
%labels = unique(pt.cdata);
%labels(labels==0) = [];
%if isempty(labels)
%    error('No nonzero ROI labels found in %s', ptseries);
%end
%nROI = numel(labels);
% --------------------- Identify ROI rows ---------------------
nROI   = size(pt.cdata, 1);   % one row per cluster
labels = 1:nROI;              % sequential IDs 1..N
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