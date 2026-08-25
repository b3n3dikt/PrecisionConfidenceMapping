function  cifti_conn_pairwise_corr_exaversion(wb_command, pconn_dconn_template,pconn_or_dconn, subject_conn_conc, keep_conn_matrices,output_directory,inherit_name,output_name)

%pconn_dconn_template = template correlation matrix to compare data to
%pconn_or_dconn = specify if your data are parcellated or dense 
%subject_conn_conc = conc file that has full paths to your cifti connectivity matrices
%keep_conn_matrices = set to 1 to keep the correlation matrices.  Set to 0 to remove correlation matrices.
%output_directory = path to some output directory
%inherit_name = if set to 1, then the code will try to write out a dscalar using a combination of the template and subject dconn names.  HOwever if the file name gets too long, then the code will fail.  Instead, provide an output name.
%output_name = provide an output name.  If you you set inheret_name = 1,
%then this variable will not be used.

%pconn_dconn_template='/mnt/max/shared/code/internal/utilities/hcp_comm_det_damien/Merged_HCP_best80_dtseries.conc_AVG.dconn.nii';
%pconn_or_dconn='dconn';
%subject_conn_conc='/mnt/max/shared/code/internal/utilities/hcp_comm_det_damien/cub-sub-NDARINVLWRKNUN1_FNL_preproc_v2_Atlas.dtseries.nii_dconn_of_dtseries_SMOOTHED_1.7_3_minutes_of_data_at_FD_0.35.conc';

%%
%wb_command = '/home/exacloud/lustre1/fnl_lab/code/external/utilities/workbench-9253ac2/bin_rh_linux64/wb_command';%exacloud path
%wb_command = '/home/exacloud/tempwork/fnl_lab/code/external/utilities/workbench-1.3.2/bin_rh_linux64/wb_command';
%wb_command = 'LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/local/bin/wb_command'; % workbench command path
%wb_command = '/Applications/workbench/bin_macosx64/wb_command'; % workbench command path
%% make sure template exists (i.e. paths to template)

if exist(pconn_dconn_template,'file')==0
    disp(pconn_dconn_template);
    error('Template d or pconn file does not exist');
   
else
    [~,filename,extension] = fileparts(pconn_dconn_template);
    pconn_dconn_template_basename = [filename extension];
end

%% make sure files connectivity matrices in conc exist
%conc = strsplit(subject_conn_conc, '/');
    conc = strsplit(subject_conn_conc, '.');
    conc = char(conc(end));
    if strcmp('conc', conc)
        A = importdata(subject_conn_conc);
    else
        A = {subject_conn_conc};
    end

%conc=subject_conn_conc;
disp(A)
%conc = char(conc(end));
%disp(conc)
%A = importdata(conc);

for i = 1:length(A)
    disp(A{i});
    if exist(A{i},'file') == 0
        error(['matrix ' num2str(i) ' does not exist']);
    else
    end
end
disp('All matrix files exist continuing ...');

if isnumeric(inherit_name) ==0
   inherit_name = str2num(inherit_name);
end

if isnumeric(keep_conn_matrices) ==0
    keep_conn_matrices=str2num(keep_conn_matrices);
end
%% Generate workbench command to do the pairwise correlation for all matrices in conc file

if strcmp(pconn_or_dconn,'pconn') ==1
    suffix = 'pscalar.nii';
    disp(pconn_or_dconn);
elseif strcmp(pconn_or_dconn,'dconn') ==1
    suffix = 'dscalar.nii';
    disp(pconn_or_dconn);
else
    'matrices needs to be "pconn" or "dconn"';
    return
end

scalar_paths = {};
for i = 1:length(A)
    
    if inherit_name ==1
        [~,A_name,~] = fileparts(A{i});
        dconn_vs_altas = [output_directory filesep A_name '_to_' pconn_dconn_template_basename '.' suffix]; % set scalar name
    else
        dconn_vs_altas = [output_directory filesep output_name '.' suffix];
    end
    
    if exist(dconn_vs_altas,'file') == 0 % make sure the matrix doesn't already exist
        %[~,template_name,~] = fileparts(pconn_dconn_template);
        
        cmd = [wb_command ' -cifti-pairwise-correlation ' pconn_dconn_template ' ' A{i} ' ' dconn_vs_altas ];
        disp(cmd)
        tic;
        system(cmd);
        toc;
        clear cmd A_name
    else
        disp([dconn_vs_altas 'already exists']);
    end
    
    %add option to delete matrices after making scalars
    
    if str2double(keep_conn_matrices) ==0
      cmd = ['rm -f ' A{i}];
      disp(strcat('removing matrix: ',(A{i})))
      system(cmd);
      clear cmd
    else
       disp(strcat('keeping matrix: ',(A{i})))
    end
    
    %scalar_paths = [scalar_paths; strcat({pwd}, '/', {subject_conn_conc}, '_', {num2str(i)}, '_to_', {pconn_dconn_template}, '.', {suffix})]; %for scalar conc file
    if i ==1
        scalar_paths =  {dconn_vs_altas};
    else
        scalar_paths = [scalar_paths; {dconn_vs_altas}]; %for scalar conc file
    end
end
Summary_of_pairwise = [num2str(i),'  total scalars made from subject list.'];
disp(Summary_of_pairwise);

%% GENERATE FINAL CONC text file here to use in other code ()

%concname = [pwd '/' subject_conn_conc '_vs_' pconn_dconn_template];
%[~,template_name,~] = fileparts(pconn_dconn_template);
disp(subject_conn_conc)
concname = [output_name];
disp([concname '_allscalars.conc'])
fileID = fopen([concname '_allscalars.conc'],'w');
nrows = length(A);
for row = 1:nrows
    fprintf(fileID,'%s\n' ,scalar_paths{row,:});
end
fclose(fileID);
%clear concname scalar_paths
disp('Done')
