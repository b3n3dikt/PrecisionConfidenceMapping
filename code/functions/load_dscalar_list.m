function dscalar_list = load_dscalar_list(dscalarswithassignments)

conc = strsplit(dscalarswithassignments, '.');
conc = char(conc(end));
if strcmp('conc',conc) == 1
    dscalarswithassignments = importdata(dscalarswithassignments);
elseif strcmp('csv',conc) == 1
    dscalarswithassignments = importdata(dscalarswithassignments);
else
    dscalarswithassignments = {dscalarswithassignments};
end

num_orig_files = length(dscalarswithassignments);
network_assignment_filetype = strsplit(dscalarswithassignments{1}, '.');
cifti_type = char(network_assignment_filetype(end-1));
if strcmp('dtseries',cifti_type) == 1
    overlap =1;
else
    overlap =0;
end
tic

%check to make sure that surface files exist
found_files_total=0; missing_files_total =0;% make a "found files counter"
for i = 1:length(dscalarswithassignments)
    if rem(i,100)==0
        disp([' Validating file existence ' num2str(i)]);toc;
    end
    if exist(dscalarswithassignments{i}, 'file') == 0
        disp(['Error Subject dscalar ' num2str(i) ' does not exist'])
        disp(dscalarswithassignments{i});
        missing_files_total = missing_files_total+1;
        missing_files_indx(missing_files_total) = i;
        missing_files{missing_files_total} = dscalarswithassignments{i};
        %return
    else
        found_files_total = found_files_total+1;
        found_files_indx(found_files_total) = i;
        found_files{found_files_total} = dscalarswithassignments{i};
    end
end
% Initialize dscalar_list
    dscalar_list = {};

    % Check if all files are found and proceed accordingly
    if found_files_total == length(dscalarswithassignments)
        disp('All series files exist continuing ...');
        dscalar_list = dscalarswithassignments; % Assign all files to the output
    else
        disp('WARNING: Not all files were found.');
        % ... (existing code for handling missing files) ...
        if strcmp(str,'y') == 1 || strcmp(str,'Y') == 1 || ... % (other conditions)
            disp('Using only found files.');
            dscalar_list = found_files; % Assign found files to the output
        else
            return; % Exit the function if user chooses not to continue
        end
    end
end



