% xcpd2dcanmotion.m
% Usage: xcpd2dcanmotion(inFile,varargin), where inFile is an XCP-D "*desc-dcan_qc.hdf5" or "*.-DCAN.hdf5" motion data file, and varargin is the path to the output directory (if none is specified, the directory containing the input file is used by default).
% Outputs a motion data file in DCANBOLDProc "*_power_2014_FD_only.mat" format  

function xcpd2dcanmotion(inFile,varargin)

% Check the number of input arguments
narginchk(1, 2);

% Check if the second input argument (outDir) was provided
if nargin == 2
    outDir = varargin{1};
else
    % If no output directory was provided, use the directory containing the input file
    [inputPath, ~, ~] = fileparts(inFile);
    outDir = inputPath;
end

% get h5info on FD groups (one group per FD increment)
h5i = h5info(inFile,'/dcan_motion');

% get total number of FD increments
ngroups = size(h5i.Groups,1);

% motion data cell array in DCANBOLDProc format
motion_data = cell(1,ngroups);

% loop over FDs 
% copy fields from hdf5 into temp struct then add to motion_data
for i = 1:ngroups 
    fdgroup = string(h5i.Groups(i).Name);
    tmpstruct = struct();
    tmpstruct.skip = h5read(inFile,fdgroup + '/skip');
    tmpstruct.FD_threshold = h5read(inFile,fdgroup + '/threshold');
    tmpstruct.frame_removal = h5read(inFile,fdgroup + '/binary_mask');
    tmpstruct.total_frame_count = h5read(inFile,fdgroup + '/total_frame_count');
    tmpstruct.remaining_frame_count = h5read(inFile,fdgroup + '/remaining_total_frame_count');
    tmpstruct.remaining_seconds = h5read(inFile,fdgroup + '/remaining_seconds');
    tmpstruct.remaining_frame_mean_FD = h5read(inFile,fdgroup + '/remaining_frame_mean_FD');
    motion_data{1,i} = tmpstruct;
end

% save to file
[filepath,name,ext] = fileparts(inFile);
outFile = strcat(outDir,'/',name,'_power_2014_FD_only.mat')
save(outFile,'motion_data')
