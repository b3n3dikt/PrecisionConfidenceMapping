function [tf, lthresh, uthresh, center] = isthisanoutlier(a, varargin)
% Compatibility shim: replaces the cifti_connectivity/src version of
% isthisanoutlier, which uses matlab.internal.datatypes.istabular — an
% internal API removed in MATLAB R2025b.
%
% This wrapper delegates directly to MATLAB's built-in isoutlier, which
% has an identical interface and is available in R2016b and later.
%
% Called by cifti_conn_matrix_for_wrapper_continous (remove_frames_from_FDvec).
% This file must be on the MATLAB path before cifti_connectivity/src so it
% takes precedence — achieved by adding code/overrides/ last in MATLAB_ADDPATH.

[tf, lthresh, uthresh, center] = isoutlier(a, varargin{:});
end
