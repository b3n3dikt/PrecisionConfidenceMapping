function [output_cifti_name] = surface_only_dconn_sigma_rat(input_cifti_name,output_cifti_name)

addpath(genpath('/home/exacloud/lustre1/fnl_lab/code/external/utilities/Matlab_CIFTI'))
%addpath(genpath('/mnt/max/shared/code/internal/utilities/CIFTI/'))
addpath(genpath('/home/exacloud/lustre1/fnl_lab/code/external/utilities/gifti-1.6'))
%path_wb_c='LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libstdc++.so.6 /usr/local/bin/wb_command';
%path_wb_c='/home/exacloud/lustre1/fnl_lab/code/external/utilities/workbench-9253ac2/bin_rh_linux64/wb_command';
path_wb_c='/home/exacloud/lustre1/fnl_lab/code/external/utilities/workbench-1.2.3-HCP/bin_rh_linux64/wb_command';

% if exist(input_cifti_name,'file') == 0
%     disp(['Subject series ' num2str(i) ' does not exist'])
%     return
% else
% end

if strcmp(output_cifti_name,'inferred') == 1
    short_file_name = char(input_cifti_name(1:end-10)); %(i.e. remove ".dconn.nii");
    output_cifti_name = [short_file_name 'surface_only'];
else
    disp('output_cifti_name must be provided or type "inferred" and it will be placed in the same location.');
end

if exist([output_cifti_name '.dconn.nii'],'file') == 0
    
    disp('loading cifti');
    tic
    newcii = ciftiopen(input_cifti_name,path_wb_c);
    dconn=single(newcii.cdata);
    toc
    
     if size(dconn,1) == 40739
     disp('dconn is already surface only')
     newdconn=dconn;
     else
    %clear newcii; %save memory
    disp ('sectioning dconn')
    newdconn=single(zeros(40739,40739));
    newdconn(1:40739,1:40739) = dconn(1:40739,1:40739);
    % LL = dconn(1:20430,1:20430);
    % LR = dconn(20431:40739,1:20430);
    % LS = dconn(40740:113556,1:20430);
    % RL = dconn(1:20430,20431:40739);
    % RR = dconn(20431:40739,20431:40739);
    % RS = dconn(40740:113556,20431:40739);
    % SL = dconn(1:20430,40740:113556);
    % SR = dconn(20431:40739,40740:113556);
    % SS = dconn(40740:113556,40740:113556);
    
    
    % disp('rewriting matrix')
    % newdconn=single(zeros(113556,113556));
    % newdconn(1:20430,1:20430) = ZLLmat;
    % newdconn(20431:40739,1:20430) = ZLRmat;
    % newdconn(40740:113556,1:20430) = ZLSmat;
    % newdconn(1:20430,20431:40739) = ZRLmat;
    % newdconn(20431:40739,20431:40739) = ZRRmat;
    % newdconn(40740:113556,20431:40739) = ZRSmat;
    % newdconn(1:20430,40740:113556) = ZSLmat;
    % newdconn(20431:40739,40740:113556) = ZSRmat;
    % newdconn(40740:113556,40740:113556) = ZSSmat;
     end
    clear dconn
    
    %open a new cifti file that has the subcorticals removed.
    newcii = ciftiopen('/home/exacloud/lustre1/fnl_lab/code/internal/utilities/community_detection/fair/supporting_files/120_LR_minsize400_recolored_manualconsensus4.dconn.nii',path_wb_c);
    newcii.cdata = newdconn;
    %addpath('/mnt/max/shared/code/internal/utilities/corr_pt_dt/support_files');
    disp('Saving new cortex only dconn')
    
    save(newcii, [output_cifti_name '.gii'], 'ExternalFileBinary')
    disp('Converting converting cortex-only  dconn .gii to .nii')
    system([path_wb_c ' -cifti-convert -from-gifti-ext ' output_cifti_name '.gii ' output_cifti_name '.dconn.nii' ]);
    disp('Removing .gii')
    system(['rm -f ' output_cifti_name '.gii']);
    system(['rm -f ' output_cifti_name '.dat']);
    
    output_cifti_name = [output_cifti_name '.dconn.nii']; %return teoutput name with the extension.
else
    
end

disp('Done coverting Dconn to surface_only Dconn.')

end
