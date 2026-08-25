
function dcan2xcpdmotion(inMatFile,varargin)
    % DCAN2XCPDMOTION: Converts a "_power_2014_FD_only.mat" file back into
    % a .hdf5 with the same "/dcan_motion" structure expected by the original script.
    %
    % Usage: dcan2xcpdmotion(inMatFile, outDir)
    %   inMatFile: Path to the *_power_2014_FD_only.mat file
    %   outDir   : (Optional) Output directory. Defaults to inMatFile's folder.

    narginchk(1, 2);
    if nargin == 2
        outDir = varargin{1};
    else
        [inputPath, ~, ~] = fileparts(inMatFile);
        outDir = inputPath;
    end

    loadedData = load(inMatFile, 'motion_data');
    motion_data = loadedData.motion_data;

    [~, name, ~] = fileparts(inMatFile);
    outFile = fullfile(outDir, strrep(name, '_power_2014_FD_only', '') + ".hdf5");

    % Create or overwrite the file
    fileId = H5F.create(outFile, 'H5F_ACC_TRUNC', 'H5P_DEFAULT', 'H5P_DEFAULT');
    groupId = H5G.create(fileId, '/dcan_motion', 'H5P_DEFAULT', 'H5P_DEFAULT', 'H5P_DEFAULT');
    H5G.close(groupId);
    H5F.close(fileId);

    for i = 1:numel(motion_data)
        fd = 0.01 * (i - 1);
        switch fd
            case 0
                groupName = sprintf('/dcan_motion/fd_%.1f', fd);
            case 1
                groupName = sprintf('/dcan_motion/fd_%.1f', fd);
            otherwise
                groupName = sprintf('/dcan_motion/fd_%g', fd);
        end
        tmpstruct = motion_data{i};
        fields = fieldnames(tmpstruct);
        for f = 1:numel(fields)
            fieldName = fields{f};
            dsPath = groupName + "/" + mapFieldName(fieldName);
            dataVal = tmpstruct.(fieldName);
            createAndWriteDataset(outFile, dsPath, dataVal);
        end
    end

    fprintf('HDF5 file created: %s\n', outFile);
end

function mapped = mapFieldName(original)
    switch original
        case 'FD_threshold'
            mapped = 'threshold';
        case 'frame_removal'
            mapped = 'binary_mask';        
        case 'remaining_frame_count'
            mapped = 'remaining_total_frame_count';
        otherwise
            mapped = original;
    end
end

function createAndWriteDataset(hdf5File, dsPath, dataVal)
    % If the data is a char array (e.g. format string), skip
    if  ~ischar(dataVal)
        dims = size(dataVal);
        h5create(hdf5File, dsPath, dims, 'Datatype', class(dataVal));
        h5write(hdf5File, dsPath, dataVal);
    end
end