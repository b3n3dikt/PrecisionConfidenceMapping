function createImageGrid(cifti_dir, outputName, filePattern)
    % Create a grid of images based on a wildcard pattern in a specified directory
    % and save it as a single image file.
    %
    % Inputs:
    %   cifti_dir - The directory containing the images.
    %   outputName - The name of the output file to save the grid image as.
    
    % Pattern to match your files
    %filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig.png');
    
    % Get a list of all files that match the pattern
    fileList = dir(filePattern);
    
    % Assuming all images are the same size, read the first image to get its size
    if isempty(fileList)
        error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
    end
    imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
    [imgHeight, imgWidth, imgDepth] = size(imgExample);
    
    % Determine the grid size
    numImages = length(fileList);
    gridRows = 5; % Define your grid configuration here
    gridCols = ceil(numImages / gridRows); % Adjust based on the actual number of images
    
    % Create a blank image matrix for the grid
    gridImg = zeros(imgHeight*gridRows, imgWidth*gridCols, imgDepth, 'uint8');
    
    % Loop over each file, read the image, and fill the appropriate spot in gridImg
    for i = 1:numImages
        % Calculate grid position
        row = floor((i-1) / gridCols);
        col = mod(i-1, gridCols);
    
        % Read image
        img = imread(fullfile(fileList(i).folder, fileList(i).name));
    
        % Calculate position in gridImg
        rowStart = row * imgHeight + 1;
        rowEnd = (row + 1) * imgHeight;
        colStart = col * imgWidth + 1;
        colEnd = (col + 1) * imgWidth;
    
        % Place image in gridImg
        gridImg(rowStart:rowEnd, colStart:colEnd, :) = img;
    end
    
    % Save the grid image
    outputFileName = fullfile(cifti_dir, outputName);
    imwrite(gridImg, outputFileName);
    fprintf('Grid image saved as %s\n', outputFileName);
end
