function mask = create_region_mask(dt, ROIs)
    % Initialize mask with zeros
    mask = zeros(size(dt.cdata, 1), 1);
    
    % Loop through each region of interest
    for i = 1:length(ROIs)
        region_name = ROIs{i};
        found = false; % Flag to check if the region is found
        
        % Find the model corresponding to the current region
        for j = 1:length(dt.diminfo{1,1}.models)
            model = dt.diminfo{1,1}.models{1,j};
            %disp((model.struct))
            if strcmp(model.struct, region_name)
                found = true; % Set the flag to true if found
                % Create mask for the current region
                start_idx = model.start;
                count = model.count;
                
                % Debugging statements
                %disp(['Processing region: ' region_name]);
                %disp(['start_idx: ' num2str(start_idx) ', count: ' num2str(count)]);
                
                % Check if the indices are within bounds
                if start_idx+count-1 > length(mask)
                    error('Index exceeds matrix dimensions.');
                end
                
                mask(start_idx:start_idx+count-1) = 1;
                break; % Exit the loop once the region is found
            end
        end
        
        % If the region is not found, throw an error or warning
        if ~found
            warning(['Region not found: ' region_name]);
        end
    end
end
