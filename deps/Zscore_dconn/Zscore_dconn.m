function output_cifti_name = Zscore_dconn(input_cifti_name, output_cifti_name, wb_command)
% Sectionally Z-score a dense connectivity matrix (dconn).
%
% Inputs:
%   input_cifti_name   - full path to the input .dconn.nii
%   output_cifti_name  - full path for output, or 'inferred' to auto-name
%   wb_command         - path to wb_command, or '' to use whatever's on PATH
%                         (only used if ciftiopen needs to convert an old
%                         cifti-1 file to cifti-2; kept for API compatibility
%                         with template_matching_RH's call site)
%
% Z-scoring is performed independently for each block defined by the
% cortical hemisphere and subcortical partition:
%   LL LR LS / RL RR RS / SL SR SS
% Partition boundaries are read directly from the CIFTI diminfo (the
% CORTEX_LEFT / CORTEX_RIGHT surface models' vertex counts; everything else
% is treated as one subcortical block), so this works for any resolution
% (32k, 59k, macaque, 7T, etc.) without any hardcoded grayordinate count --
% the numbers come from the file itself, not from this function.
% Method: Hermosillo et al. (2024) doi:10.1038/s41593-024-01596-5
%
% Uses ciftiopen/ciftisave (deps/cifti-matlab) -- the same CIFTI I/O library
% every other step in PCM already uses. No FieldTrip / COMBINED_UTILS
% dependency.

if strcmp(output_cifti_name, 'inferred')
    output_cifti_name = [input_cifti_name(1:end-10) 'Zscored.dconn.nii'];
end

if exist(output_cifti_name, 'file')
    disp(['Zscore_dconn: already exists, skipping: ' output_cifti_name]);
    return
end

disp('Zscore_dconn: loading dconn...')
if nargin >= 3 && ~isempty(wb_command)
    cii = ciftiopen(input_cifti_name, wb_command);
else
    cii = ciftiopen(input_cifti_name);
end

% Infer partition boundaries from diminfo BEFORE freeing cii.cdata. A dconn's
% two dimensions map the same brainordinates, so diminfo{1} alone is enough.
n_L = 0;  n_R = 0;
L_start = -1;  R_start = -1;
models = cii.diminfo{1}.models;
for i = 1:length(models)
    if strcmp(models{i}.type, 'surf')
        switch models{i}.struct
            case 'CORTEX_LEFT'
                n_L = models{i}.count;  L_start = models{i}.start;
            case 'CORTEX_RIGHT'
                n_R = models{i}.count;  R_start = models{i}.start;
        end
    end
end
if n_L == 0 || n_R == 0
    error(['Zscore_dconn: could not find CORTEX_LEFT/CORTEX_RIGHT surface ' ...
           'models in this dconn''s diminfo.']);
end
% The 9-block partition below assumes brainordinates are laid out as
% [left cortex][right cortex][subcortical, if any] -- i.e. left cortex starts
% first and right cortex starts immediately after it. That's the standard
% HCP/DCAN dense-connectome layout (and what both the FieldTrip version and
% the original hardcoded-index version of this function already assumed),
% but verify it explicitly rather than assume it silently, since a future
% non-human/non-standard template could in principle differ.
% NOTE: cifti-matlab's models{i}.start is 1-based (cifti_parse_xml.m adds 1
% to the CIFTI file's 0-based IndexOffset), so a left-cortex-first layout
% means L_start == 1, not 0.
if L_start ~= 1 || R_start ~= n_L + 1
    error(['Zscore_dconn: expected CORTEX_LEFT then CORTEX_RIGHT contiguous ' ...
           'at the start of the dconn (left at 1, right at ' num2str(n_L + 1) '), ' ...
           'but found left at ' num2str(L_start) ' and right at ' ...
           num2str(R_start) '. This file''s brainordinate layout does not ' ...
           'match what the 9-block partition logic assumes.']);
end

% Memory: at 91k grayordinates the dconn is ~33 GB as single and ~66 GB as the
% double ciftiopen returns. Convert to single, then immediately drop the
% original so we don't hold both (that, plus a separate output buffer,
% peaked ~133 GB and OOM-killed the 110 GB matlab_tm job). We z-score the blocks
% in place below, so no second full-size buffer is allocated.
dconn = single(cii.cdata);
cii.cdata = [];   % free the original copy (~66 GB if it was double)

n_tot = size(dconn, 1);
n_S   = n_tot - n_L - n_R;

Le = n_L;        % last index of left cortex
Re = n_L + n_R;  % last index of right cortex

fprintf('Zscore_dconn: L=1:%d  R=%d:%d  S=%d:%d\n', Le, Le+1, Re, Re+1, n_tot);

zscore_block = @(b) reshape(zscore(b(:)), size(b));

% In-place block z-scoring. The 9 blocks tile the matrix disjointly and each is
% written back only to the indices it was read from, so overwriting dconn is
% safe and avoids allocating a second ~33 GB output buffer.
disp('Zscore_dconn: z-scoring cortical blocks...')
dconn(1:Le,    1:Le)    = zscore_block(dconn(1:Le,    1:Le));     % LL
dconn(Le+1:Re, 1:Le)    = zscore_block(dconn(Le+1:Re, 1:Le));     % LR
dconn(1:Le,    Le+1:Re) = zscore_block(dconn(1:Le,    Le+1:Re));  % RL
dconn(Le+1:Re, Le+1:Re) = zscore_block(dconn(Le+1:Re, Le+1:Re)); % RR

if n_S > 0
    disp('Zscore_dconn: z-scoring subcortical blocks...')
    dconn(Re+1:end, 1:Le)     = zscore_block(dconn(Re+1:end, 1:Le));     % LS
    dconn(Re+1:end, Le+1:Re)  = zscore_block(dconn(Re+1:end, Le+1:Re));  % RS
    dconn(1:Le,     Re+1:end) = zscore_block(dconn(1:Le,     Re+1:end)); % SL
    dconn(Le+1:Re,  Re+1:end) = zscore_block(dconn(Le+1:Re,  Re+1:end)); % SR
    dconn(Re+1:end, Re+1:end) = zscore_block(dconn(Re+1:end, Re+1:end)); % SS
end

cii.cdata = dconn;

disp(['Zscore_dconn: saving ' output_cifti_name])
ciftisave(cii, output_cifti_name);
disp('Zscore_dconn: done.')

end
