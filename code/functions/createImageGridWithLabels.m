function createImageGridWithLabels(cifti_dir, outputName, filePattern)
    fileList = dir(filePattern);

    if isempty(fileList)
        % Not an error: a surface-only template/run (e.g. abcd_surf, SURF_ONLY=1)
        % has no subcortex, so the subcortical patterns (*_fig_AX/CO/PA.png)
        % legitimately match nothing. Skip quietly rather than aborting the
        % figure script (which would also skip the dlabel conversion and
        % thresholding steps downstream).
        warning('No files matched the pattern %s in directory %s. Skipping this label grid.', filePattern, cifti_dir);
        return
    end

    gridRows = 5;
    numImages = length(fileList);
    gridCols = ceil(numImages / gridRows);

    % Load every tile and crop its white border first. The wb_command surface
    % snapshots carry a large white margin; left uncropped they dominate the
    % grid with whitespace and shrink each brain (making the labels look tiny).
    imgs  = cell(numImages, 1);
    names = cell(numImages, 1);
    tileH = 0; tileW = 0;
    for i = 1:numImages
        img = cropWhiteBorder(imread(fullfile(fileList(i).folder, fileList(i).name)));
        if size(img, 3) == 1
            img = repmat(img, 1, 1, 3);   % normalize to RGB so the montage is uniform
        end
        imgs{i} = img;
        tileH = max(tileH, size(img, 1));
        tileW = max(tileW, size(img, 2));

        [~, name, ~] = fileparts(fileList(i).name);
        % Extract network name dynamically based on the provided filePattern
        if contains(filePattern, 'half-1')
            tokens = regexp(name, 'half-1_(.*?)_network_probability_fig', 'tokens');
        elseif contains(filePattern, 'Percent_holdout')
            tokens = regexp(name, '_TM_Percent_holdout_(.*?)_network_probability_fig', 'tokens');
        else
            tokens = {{}};
        end
        if ~isempty(tokens) && ~isempty(tokens{1})
            names{i} = tokens{1}{1};
        else
            names{i} = 'Unknown';
        end
    end

    % Build a tightly packed montage by hand (small fixed gap), reserving a
    % label band above each brain. Doing the layout in the pixel array — rather
    % than via subplot — removes the large inter-axes gaps subplot inserts.
    gap     = 8;                              % px between tiles
    labelH  = max(36, round(tileH * 0.14));   % px band above each brain for text
    cellH   = tileH + labelH + gap;
    cellW   = tileW + gap;
    montage = uint8(255 * ones(cellH * gridRows, cellW * gridCols, 3));  % white canvas

    textXY = zeros(numImages, 2);   % center-x, baseline-y for each label (pixels)
    for i = 1:numImages
        row = floor((i - 1) / gridCols);
        col = mod(i - 1, gridCols);
        img = imgs{i};
        [h, w, ~] = size(img);

        % Center the (variable-size cropped) brain within its tile.
        r0 = row * cellH + labelH + floor((tileH - h) / 2) + 1;
        c0 = col * cellW + floor((tileW - w) / 2) + 1;
        montage(r0:r0+h-1, c0:c0+w-1, :) = img;

        textXY(i, 1) = col * cellW + cellW / 2;        % horizontal center of tile
        textXY(i, 2) = row * cellH + round(labelH * 0.62);  % within the label band
    end

    % Headless-safe labeling. The previous version annotated tiles with
    % insertText() (Computer Vision Toolbox), which needs an X server + system
    % fonts and fails on headless compute nodes ("No available X client --
    % cannot find font information"). Here we display the montage in an INVISIBLE
    % figure with image() and draw labels with text(), which use MATLAB's bundled
    % fonts (no X11), then rasterize with print(). Uses only base graphics
    % (image/text/print) — no Image Processing or CV toolbox, no tiledlayout.
    fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'pixels', ...
                 'Position', [100, 100, size(montage, 2), size(montage, 1)]);
    % Clean up the figure even if something below errors, so the caller's
    % try/catch doesn't leak invisible figures.
    cleanupFig = onCleanup(@() close(fig));

    ax = axes('Parent', fig, 'Position', [0 0 1 1]);
    image(ax, montage);
    axis(ax, 'image'); axis(ax, 'off');
    hold(ax, 'on');
    fontSize = max(14, round(labelH * 0.5));
    for i = 1:numImages
        text(ax, textXY(i, 1), textXY(i, 2), names{i}, ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'Color', 'k', ...
            'Interpreter', 'none');   % underscores render literally
    end

    outputFileName = fullfile(cifti_dir, outputName);
    print(fig, outputFileName, '-dpng', '-r150');
    fprintf('Grid image with labels saved as %s\n', outputFileName);
end

function out = cropWhiteBorder(img)
    % Trim near-white rows/columns around the edges, leaving a small margin.
    if size(img, 3) == 3
        nonwhite = min(img, [], 3) < 250;   % white only where all channels are high
    else
        nonwhite = img < 250;
    end
    rows = find(any(nonwhite, 2));
    cols = find(any(nonwhite, 1));
    if isempty(rows) || isempty(cols)
        out = img;   % all white (shouldn't happen) — return unchanged
        return
    end
    m  = 4;   % keep a few px of breathing room
    r1 = max(1, rows(1) - m);   r2 = min(size(img, 1), rows(end) + m);
    c1 = max(1, cols(1) - m);   c2 = min(size(img, 2), cols(end) + m);
    out = img(r1:r2, c1:c2, :);
end

% original version which worked on split half but not percent holdout
%function createImageGridWithLabels(cifti_dir, outputName, filePattern)
%    fileList = dir(filePattern);
%
%    if isempty(fileList)
%        error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
%    end
%
%    imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
%    [imgHeight, imgWidth, imgDepth] = size(imgExample);
%
%    gridRows = 5;
%    numImages = length(fileList);
%    gridCols = ceil(numImages / gridRows);
%    textHeight = 70; % Adjust textHeight for visibility
%    textColor = 'white'; % Ensure contrast
%    fontSize = 45; % Adjust font size for visibility
%
%    totalImgHeight = imgHeight + textHeight;
%    gridImg = zeros(totalImgHeight*gridRows, imgWidth*gridCols, imgDepth, 'uint8') + 255; % Start with a white background
%
%    for i = 1:numImages
%        img = imread(fullfile(fileList(i).folder, fileList(i).name));
%        [~, name, ~] = fileparts(fileList(i).name);
%        networkNameMatch = regexp(name, 'half-1_(.*?)_network', 'tokens');
%
%        if ~isempty(networkNameMatch)
%            networkName = networkNameMatch{1}{1};
%        else
%            networkName = 'Unknown';
%        end
%
%        textPosition = [imgWidth / 2, 1]; % Adjust y-coordinate for visibility
%
%        imgWithLabel = zeros(imgHeight + textHeight, imgWidth, imgDepth, 'uint8');
%        imgWithLabel(textHeight+1:end, :, :) = img;
%        imgWithLabel = insertText(imgWithLabel, textPosition, networkName, 'FontSize', fontSize, 'BoxOpacity', 0, 'TextColor', textColor, 'AnchorPoint', 'CenterTop');
%
%        row = floor((i-1) / gridCols);
%        col = mod(i-1, gridCols);
%        rowStart = (row * totalImgHeight) + 1;
%        colStart = (col * imgWidth) + 1;
%
%        gridImg(rowStart:rowStart+totalImgHeight-1, colStart:colStart+imgWidth-1, :) = imgWithLabel;
%    end
%
%    outputFileName = fullfile(cifti_dir, outputName);
%    imwrite(gridImg, outputFileName);
%    fprintf('Grid image with labels saved as %s\n', outputFileName);
%end

% 
% function createImageGridWithLabels(cifti_dir, outputName, filePattern)
%     fileList = dir(filePattern);
% 
%     if isempty(fileList)
%         error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
%     end
% 
%     imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
%     [imgHeight, imgWidth, imgDepth] = size(imgExample);
% 
%     gridRows = 5;
%     numImages = length(fileList);
%     gridCols = ceil(numImages / gridRows);
%     textHeight = 50; % Increase textHeight for visibility
%     textColor = 'white'; % Ensure contrast
%     fontSize = 24; % Increase font size for visibility
% 
%     totalImgHeight = imgHeight + textHeight;
%     gridImg = zeros(totalImgHeight*gridRows, imgWidth*gridCols, imgDepth, 'uint8') + 255;
% 
%     for i = 1:numImages
%         img = imread(fullfile(fileList(i).folder, fileList(i).name));
%         [~, name, ~] = fileparts(fileList(i).name);
%         networkNameMatch = regexp(name, 'half-1_(.*?)_network', 'tokens');
%         networkName = ~isempty(networkNameMatch) ? networkNameMatch{1}{1} : 'Unknown';
%         
%         % Define text position at the top center of each image space
%         textPosition = [imgWidth / 2, 1]; % Adjust y-coordinate for visibility if needed
% 
%         % Create an image with textHeight added for the label
%         imgWithLabel = zeros(imgHeight + textHeight, imgWidth, imgDepth, 'uint8');
%         imgWithLabel(textHeight+1:end, :, :) = img;
%         imgWithLabel = insertText(imgWithLabel, textPosition, networkName, ...
%                                   'FontSize', fontSize, 'BoxOpacity', 0, ...
%                                   'TextColor', textColor, 'AnchorPoint', 'CenterTop');
% 
%         row = floor((i-1) / gridCols);
%         col = mod(i-1, gridCols);
%         rowStart = row * totalImgHeight + 1;
%         colStart = col * imgWidth + 1;
%         rowEnd = rowStart + totalImgHeight - 1;
%         colEnd = colStart + imgWidth - 1;
% 
%         gridImg(rowStart:rowEnd, colStart:colEnd, :) = imgWithLabel;
%     end
% 
%     outputFileName = fullfile(cifti_dir, outputName);
%     imwrite(gridImg, outputFileName);
%     fprintf('Grid image with labels saved as %s\n', outputFileName);
% end


% function createImageGridWithLabels(cifti_dir, outputName, filePattern)
%     % Get a list of all files that match the pattern
%     fileList = dir(filePattern);
% 
%     if isempty(fileList)
%         error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
%     end
% 
%     % Assuming all images are the same size, read the first image to get its size
%     imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
%     [imgHeight, imgWidth, imgDepth] = size(imgExample);
% 
%     % Parameters for the grid
%     gridRows = 5; % Define your grid configuration here
%     numImages = length(fileList);
%     gridCols = ceil(numImages / gridRows); % Adjust based on the actual number of images
%     textHeight = 30; % Space for text
% 
%     % Initialize the grid image
%     totalImgHeight = imgHeight + textHeight; % Total height per image row in the grid
%     gridImg = zeros(totalImgHeight*gridRows, imgWidth*gridCols, imgDepth, 'uint8') + 255; % Start with a white background
% 
%     % Loop through each image file
%     for i = 1:numImages
%         % Read and annotate the image
%         img = imread(fullfile(fileList(i).folder, fileList(i).name));
%         
%         % Extract the network name from the filename
%         [~, name, ~] = fileparts(fileList(i).name);
%         networkNameMatch = regexp(name, 'half-1_(.*?)_network', 'tokens');
%         if ~isempty(networkNameMatch)
%             networkName = networkNameMatch{1}{1};
%         else
%             networkName = 'Unknown';
%         end
%         
%         % Insert network name into the image
%         imgWithText = insertText(img, [0, 0], networkName, 'FontSize', 18, 'BoxOpacity', 0, 'TextColor', 'white', 'AnchorPoint', 'LeftTop');
%         [textImgHeight, textImgWidth, ~] = size(imgWithText);
% 
%         % Calculate grid position
%         row = floor((i-1) / gridCols);
%         col = mod(i-1, gridCols);
%         rowStart = (row * totalImgHeight) + 1;
%         colStart = (col * imgWidth) + 1;
% 
%         % Correctly adjust rowEnd based on the actual height of imgWithText
%         rowEnd = rowStart + textImgHeight - 1;
% 
%         % Ensure gridImg space matches the dimensions of imgWithText
%         gridImg(rowStart:rowEnd, colStart:(colStart + imgWidth - 1), :) = imgWithText;
%     end
% 
%     % Save the grid image
%     outputFileName = fullfile(cifti_dir, outputName);
%     imwrite(gridImg, outputFileName);
%     fprintf('Grid image with labels saved as %s\n', outputFileName);
% end

% 
% 
% function createImageGridWithLabels(cifti_dir, outputName, filePattern)
% % Get a list of all files that match the pattern
% fileList = dir(filePattern);
% 
% if isempty(fileList)
%     error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
% end
% 
% % Read the first image to get its size (assuming all images are the same size)
% imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
% [imgHeight, imgWidth, imgDepth] = size(imgExample);
% 
% % Parameters for the grid
% gridRows = 5; % Define your grid configuration here
% numImages = length(fileList);
% gridCols = ceil(numImages / gridRows); % Adjust based on the actual number of images
% textHeight = 30; % Space for text
% 
% % Initialize the grid image
% totalImgHeight = imgHeight + textHeight; % Total height per image row in the grid
% gridImg = zeros(totalImgHeight*gridRows, imgWidth*gridCols, imgDepth, 'uint8') + 255; % Start with a white background
% 
% % Loop through each image file
% for i = 1:numImages
%     % Extract network name and other operations...
% 
%     % Calculate grid position...
% 
%     % Read and annotate the image...
%     [textImgHeight, textImgWidth, ~] = size(imgWithText);
% 
%     % Correctly calculate position in gridImg, fully accounting for the actual size of imgWithText
%     rowStart = (row * totalImgHeight) + 1;
%     colStart = (col * imgWidth) + 1;
% 
%     % Correctly adjust rowEnd based on the actual height of imgWithText
%     rowEnd = rowStart + textImgHeight - 1;
% 
%     % Ensure gridImg space matches the dimensions of imgWithText
%     % Here we use rowStart:rowEnd and colStart:(colStart + textImgWidth - 1) directly
%     gridImg(rowStart:rowEnd, colStart:(colStart + textImgWidth - 1), :) = imgWithText;
% end
% 
% % Save the grid image
% outputFileName = fullfile(cifti_dir, outputName);
% imwrite(gridImg, outputFileName);
% fprintf('Grid image with labels saved as %s\n', outputFileName);
% end
% 

% 
% function createImageGridWithLabels(cifti_dir, outputName,filePattern)
%     % Create a grid of images with labels extracted from filenames
%     % and save it as a single image file.
%     
%     % Pattern to match your files
%     %filePattern = fullfile(cifti_dir, 'Probability_Maps*half-1*_network_probability_fig.png');
%     
%     % Get a list of all files that match the pattern
%     fileList = dir(filePattern);
%     
%      % Adjust imgHeight to account for text annotation
%     % Since `insertText` might change the image height, accommodate for variability
%     maxImgHeight = imgHeight + textHeight;
%     
%     % Create a blank image matrix for the grid, adjusting for potential variability in textHeight
%     gridImg = zeros(maxImgHeight*gridRows, imgWidth*gridCols, 3, 'uint8') + 255; % Start with white
% 
%     % Assuming all images are the same size, read the first image to get its size
%     if isempty(fileList)
%         error('No files matched the pattern %s in directory %s.', filePattern, cifti_dir);
%     end
%     imgExample = imread(fullfile(fileList(1).folder, fileList(1).name));
%     [imgHeight, imgWidth, ~] = size(imgExample);
%     
%     % Determine the grid size
%     numImages = length(fileList);
%     gridRows = 5; % Define your grid configuration here
%     gridCols = ceil(numImages / gridRows); % Adjust based on the actual number of images
%     
%     % Calculate the height needed for text annotations
%     textHeight = 30; % Adjust as needed
%     
%     % Adjust imgHeight to account for text annotation
%     totalImgHeight = imgHeight + textHeight;
%     
%     % Create a blank image matrix for the grid, adjusting for textHeight
%     gridImg = zeros(totalImgHeight*gridRows, imgWidth*gridCols, 3, 'uint8') + 255; % Start with white
%     
%     % Define text properties
%     textPosition = [5, 5]; % Adjust based on where you want the text
%     textColor = 'black';
%     
%     
%     % Instead of using fixed imgHeight for rowStart and rowEnd calculations,
%     % use the actual height of imgWithText for each image
%     for i = 1:numImages
%         % ... extract network name, calculate grid position, read and annotate image ...
%     
%         % Get the actual height of the annotated image
%         [annotatedImgHeight, ~, ~] = size(imgWithText);
%     
%         % Calculate position in gridImg, adjusting for textHeight
%         rowStart = row * maxImgHeight + textHeight + 1 - textHeight; % Adjust if needed
%         rowEnd = rowStart + annotatedImgHeight - 1; % Use actual height of imgWithText
%         colStart = col * imgWidth + 1;
%         colEnd = (col + 1) * imgWidth;
%     
%         % Ensure the target area in gridImg matches the dimensions of imgWithText
%         % Adjust rowEnd in gridImg if necessary to fit the imgWithText
%         gridImg(rowStart:rowEnd, colStart:colEnd, :) = imgWithText; % Adjust as needed
%     end
%     
%     % Save the grid image
%     outputFileName = fullfile(cifti_dir, outputName);
%     imwrite(gridImg, outputFileName);
%     fprintf('Grid image with labels saved as %s\n', outputFileName);
% end
