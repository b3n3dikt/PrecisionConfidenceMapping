function output_cifti_name = Zscore_dconn_surface_only(input_cifti_name, output_cifti_name, path_wb_c)
% Thin wrapper around Zscore_dconn for surface-only (no subcortex) dconns.
% Zscore_dconn infers the partition from brainstructure and skips subcortical
% blocks automatically when they are absent.
output_cifti_name = Zscore_dconn(input_cifti_name, output_cifti_name, path_wb_c);
end
