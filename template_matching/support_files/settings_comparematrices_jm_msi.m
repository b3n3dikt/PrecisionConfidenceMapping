function settings=settings_comparematrices_jm_msi()
% =============================================================================
% settings_comparematrices_jm_msi.m  —  Standalone PCM Settings
% =============================================================================
% CHANGES FROM ORIGINAL:
%   Replaced all 16 hardcoded server-absolute paths with paths computed
%   dynamically relative to this file's own location using mfilename('fullpath').
%   This makes the entire PCM_standalone package relocatable to any server
%   without editing any paths.
%
%   Original used pwd to guess a server name, then had a flat list of
%   /projects/standard/faird/... absolute paths.
%
%   Now: support_files are relative to this file's directory;
%        figure_maker assets are in ../../deps/figure_maker/;
%        wb_command is assumed to be on PATH (loaded via `module load workbench`).
% =============================================================================

% Locate this file's directory and compute PCM_standalone root
this_file = mfilename('fullpath');
support_dir = fileparts(this_file);                    % .../template_matching/support_files
tm_dir      = fileparts(support_dir);                  % .../template_matching
pcm_root    = fileparts(tm_dir);                       % .../PCM_standalone
fig_dir     = fullfile(pcm_root, 'deps', 'figure_maker');

% ── Paths used by template matching ──────────────────────────────────────────
% paths{1-3}: addpath directories — cifti-matlab is already on path via
%             MATLAB_ADDPATH set in config.sh and passed from the shell.
%             Setting these to support_dir is a safe no-op placeholder.
path{1} = support_dir; % gifti — already loaded via cifti-matlab dep
path{2} = support_dir; % Matlab_CIFTI — already loaded via cifti-matlab dep
path{3} = support_dir; % effect_size_toolbox — not used in PCM

% paths{4-7}: parcellation files not used in PCM (infomap/community detection)
path{4} = fullfile(support_dir, 'placeholder_unused.nii');
path{5} = fullfile(support_dir, 'Networks_template_cleaned.dscalar.nii');
path{6} = fullfile(support_dir, 'Networks_template_cleaned.dscalar.nii');
path{7} = fullfile(support_dir, 'placeholder_unused.nii');

% paths{8,10-12}: greyordinate template files (present in support_files/)
path{8}  = fullfile(support_dir, '91282_Greyordinates.dscalar.nii');
path{9}  = fullfile(support_dir, 'placeholder_unused.nii'); % HCP dconn, unused
path{10} = fullfile(support_dir, '91282_Greyordinates.dtseries.nii');
path{11} = fullfile(support_dir, '91282_Greyordinates_surf_only.dtseries.nii');
path{12} = fullfile(support_dir, '91282_Greyordinates_surf_only.dscalar.nii');

% paths{13-15}: figure-making assets (in deps/figure_maker/)
path{13} = fullfile(fig_dir, 'MSC01_template_quad_scaled_v3_legend_fixed_MSI.scene');
path{14} = fullfile(fig_dir, 'MSC01_template_scene_subcort_scalar_MSI.scene');
path{15} = fullfile(fig_dir, 'quick_network_pic.sh');

% path{16}: geodesic distance matrix — not used in PCM
path{16} = fullfile(support_dir, 'placeholder_unused.mat');

% wb_command: assumed on PATH via `module load workbench` in the SLURM job
path_wb_c = 'wb_command';

% path_template_nets: template is supplied per-call; this is a fallback placeholder
path_template_nets = fullfile(support_dir, 'seedmaps_ABCD164template_SMOOTHED_dtseries_all_networksZscored.mat');

settings.path = path;
settings.path_template_nets = path_template_nets;
settings.path_wb_c = path_wb_c;
