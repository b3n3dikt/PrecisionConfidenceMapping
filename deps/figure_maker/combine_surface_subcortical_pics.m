function combine_surface_subcortical_pics(projectdir,remove_frontal,remove_middle,outputdir)

% R. Hermosillo 09/12/2020

%This funtion loads a project folder with network subfolders and assumes
%that there are many subcortical and surface images inside.
%inputs are a project directory.

%Options to crop:
%remove_frontal=remove pixels from the image. Set to 0, to keep pixels.
%Set to 1 to remove pixels.
%remove_middle=remove pixels from center of image (i.e. eyes and posterior cerebral cortex). Helpful for very tight images. Set to 0, to keep pixels.
%Set to 1 to remove pixels.

%load list
%input_list = importdata(input_list_file);
%projectdir=pwd;

%check input format
if isnumeric(remove_frontal)==1
else
    remove_frontal=str2double(remove_frontal);
end

if isnumeric(remove_middle)==1
else
    remove_middle=str2double(remove_middle);
end

dinfo = dir(projectdir); % find folders with network names
%dinfo = dir(pwd);

netfolder_cell = {dinfo.name};
netfolder_cell = netfolder_cell(3:end); % remove . and .. as folder contents.
for f=1:size(netfolder_cell,2)
    cd([projectdir filesep char(netfolder_cell(f))])
    %netdinfo = dir('*.png');
    netdinfo = dir('*.dlabel.nii'); % find all dlabels in folder.
    label_cells = {netdinfo.name};
    
    %Get root threshold names
    thres_roots =cell(size(label_cells,2),1);
    for c=1:size(label_cells,2)
        label_root = strsplit(label_cells{c},'.dlabel.nii');
        thres_roots{c,1} = label_root{1};
    end
    %thres_roots = thres_roots';
    
    %surf_input_list = importdata('C:\Users\hermosir\Documents\test_ciftis\ABCD_subcort_pics\AX_subcortlist_overlap_net.txt');
    %subcort_input_list = importdata('C:\Users\hermosir\Documents\test_ciftis\ABCD_subcort_pics\AX_subcortlist_overlap_net.txt');
    %new_pic_folder = 'C:\Users\hermosir\Documents\test_ciftis\ABCD_subcort_pics\single_net\recropped';
    %new_pic_folder = 'C:\Users\hermosir\Documents\test_ciftis\ABCD_subcort_pics\overlap_net\recropped';
    
    combine_surf_subcort=1;
    cmd = ['mkdir -p ' outputdir filesep char(netfolder_cell(f)) ];
    system(cmd);
    disp(char(netfolder_cell(f)));
    
    for i =1:size(thres_roots,1)
        disp(i);
        %[I,cmap] = imread('H:\Documents\ABCD\Network_probability\single_net_cropped\GRP1_Aud_network_probability_singlenet_AX.png');
        [I,~] = imread([thres_roots{i} '.png']);
        [I_ax,~] = imread([thres_roots{i} '_AX.png']);
        %imshow(I)
        %imshow(I_ax);
        
        if remove_frontal ==1
            J = I(85:end,:,:); % remove frontal cortex
            J = J(:,237:end,:);
        end
        
        if remove_middle ==1
            K1 = J(1:233,:,:); %top
            K2 = J(410:end,:,:);
            %combine
            K = [K1; K2];
            %K = J(1:233,410:end, :,:); %remove middle
            J=K;
        end
        
        if combine_surf_subcort ==1
            J = [I; I_ax];
        end
        
        %imshow(J)
        %pic_folder = pwd;
        new_pic_name = [outputdir filesep char(netfolder_cell(f)) filesep thres_roots{i} '.png'];
        % save file
        %print([new_pic_folder filesep new_pic_name '.' pic_ext], '-dpng','-r300' )
        imwrite(J,new_pic_name)
        %system(['rm -f ' projectdir filesep thres_roots{i} '_AX.png']);
    end
    
    disp(['Done auto-combining images for this network: ' num2str(f)])
    
end
disp('Done.')
end