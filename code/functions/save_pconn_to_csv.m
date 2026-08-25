% Function to save pconn to CSV
% Function to save pconn to CSV
function save_pconn_to_csv(pconn_file, output_file, delimiter)
    if nargin < 3
        delimiter = ',';
    end

    % Load the .pconn file
    cifti = cifti_read(pconn_file);

    % Extract the data matrix
    data_matrix = cifti.cdata;

    % Extract ROI labels from cifti.diminfo{1,1}.parcels
    parcels_info = cifti.diminfo{1,1}.parcels;
    roi_labels = {parcels_info.name};  % Get the names of the parcels

    % Verify that the number of ROI labels matches the matrix dimensions
    if length(roi_labels) ~= size(data_matrix, 1)
        error('Number of ROI labels does not match the data matrix dimensions.');
    end

    % Convert the data to a table with row and column headers
    data_table = array2table(data_matrix, 'RowNames', roi_labels, 'VariableNames', roi_labels);

    % Write the table to a CSV file
    writetable(data_table, output_file, 'Delimiter', delimiter, 'WriteRowNames', true);

    fprintf('Data matrix saved to %s\n', output_file);
end