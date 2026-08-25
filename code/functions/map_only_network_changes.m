function [transition_matrix, network_to_index] = map_network_changes(Mdata, Cdata)
    % Find unique networks from both Mdata and Cdata
    unique_networks = unique([Mdata; Cdata]);

    % Initialize a transition matrix
    transition_matrix = zeros(length(unique_networks));

    % Create a map from network number to index in the matrix
    network_to_index = containers.Map(unique_networks, 1:length(unique_networks));

    % Iterate over the data to fill the transition matrix
    for i = 1:length(Mdata)
        if Mdata(i) ~= Cdata(i)
            m_idx = network_to_index(Mdata(i));
            c_idx = network_to_index(Cdata(i));
            transition_matrix(m_idx, c_idx) = transition_matrix(m_idx, c_idx) + 1;
        end
    end
end
