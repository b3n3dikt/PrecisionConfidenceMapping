function [transition_matrix, transition_matrix_full, network_to_index] = map_network_changes_nonan(Mdata, Cdata)
    % Find unique networks from both Mdata and Cdata
    unique_networks = unique([Mdata; Cdata]);
    unique_networks(isnan(unique_networks)) = []; % Remove NaN values from unique networks

    % Initialize transition matrices
    transition_matrix = zeros(length(unique_networks));
    transition_matrix_full = zeros(length(unique_networks));

    % Create a map from network number to index in the matrix
    network_to_index = containers.Map(unique_networks, 1:length(unique_networks));

    % Iterate over the data to fill the transition matrices
    for i = 1:length(Mdata)
        % Skip NaN values
        if isnan(Mdata(i)) || isnan(Cdata(i))
            continue;
        end

        m_idx = network_to_index(Mdata(i));
        c_idx = network_to_index(Cdata(i));
        if Mdata(i) ~= Cdata(i)
            transition_matrix(m_idx, c_idx) = transition_matrix(m_idx, c_idx) + 1;
        end
        transition_matrix_full(m_idx, c_idx) = transition_matrix_full(m_idx, c_idx) + 1;
    end
end


