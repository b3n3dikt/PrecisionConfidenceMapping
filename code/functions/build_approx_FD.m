function approx_FD = build_approx_FD(motion_data)
% This version finds the threshold at which the frame switches
% from remove (1) to keep (0). 
% If motion_data is sorted ascending in FD_threshold => [t1 < t2 < ...]
%
% For each TR f:
%   1) We find the first threshold that says frame_removal(f) == 0.
%   2) approx_FD(f) = t_{i-1}, i.e. the largest threshold that was 1 => remove.
%   3) If it never switches to 0 => keep, approx_FD(f) = t_last (the biggest threshold).
%   4) If it starts from 0 => keep at the smallest threshold, approx_FD(f) = 0.

numThresholds = numel(motion_data);
FDthresholds  = zeros(numThresholds, 1);

for i = 1:numThresholds
    FDthresholds(i) = motion_data{1,i}.FD_threshold;
end

[FDthresholds_sorted, sort_idx] = sort(FDthresholds, 'ascend');
motion_data_sorted              = motion_data(sort_idx);

nTR = length(motion_data_sorted{1}.frame_removal);
approx_FD = zeros(nTR,1);

for f = 1:nTR
    % find the first threshold index i where frame_removal=0 => keep
    iKeep = NaN;
    for i = 1:numThresholds
        if motion_data_sorted{1,i}.frame_removal(f) == 0
            iKeep = i;  
            break;
        end
    end
    
    if isnan(iKeep)
        % The frame is '1 => remove' at all thresholds 
        % => FD >= the largest threshold
        approx_FD(f) = FDthresholds_sorted(end);
    elseif iKeep == 1
        % The frame is '0 => keep' even at the smallest threshold
        % => FD < t(1)
        approx_FD(f) = 0;
    else
        % The frame was '1 => remove' up to threshold iKeep-1
        % Then '0 => keep' at iKeep
        approx_FD(f) = FDthresholds_sorted(iKeep - 1);
    end
end

disp("Finished building approximate FD: using the 'switch from 1 to 0' logic.");
end


% function approx_FD = build_approx_FD(motion_data, skipZeroThreshold)
% % build_approx_FD constructs an approximate FD value for each TR
% % based on the series of (FD_threshold, frame_removal) pairs in "motion_data".
% %
% % INPUTS:
% %   motion_data        - a cell array (e.g. 1 x 101), where each cell is a struct with fields:
% %                           FD_threshold : a scalar (0 -> ~1.0)
% %                           frame_removal: an [nTR x 1] vector (1 = remove, 0 = keep)
% %   skipZeroThreshold  - boolean (true/false). If true, ignore threshold=0 entries
% %
% % OUTPUTS:
% %   approx_FD - [nTR x 1] vector.  approx_FD(f) = largest FD_threshold that keeps frame f.
% %               A bigger approx_FD means the frame is likely "lower-motion" 
% %               (it passed more aggressive thresholds).
% %
% % NOTE:
% %   If a frame is removed at the smallest threshold, we assign approx_FD(f) = that threshold 
% %   or just the first nonzero threshold. Adjust as desired.
% 
% % -------------------------------------------------------------------------
% % 1) Gather all thresholds into an array
% % -------------------------------------------------------------------------
% numThresholds = numel(motion_data);
% FDthresholds = zeros(numThresholds, 1);
% for i = 1:numThresholds
%     FDthresholds(i) = motion_data{1,i}.FD_threshold;
% end
% 
% % -------------------------------------------------------------------------
% % 2) Optionally drop threshold=0 if it's meaningless
% % -------------------------------------------------------------------------
% if skipZeroThreshold
%     valid_idx = find(FDthresholds > 0);
% else
%     valid_idx = 1:numThresholds;
% end
% 
% FDthresholds_valid = FDthresholds(valid_idx);
% motion_data_valid = motion_data(valid_idx);
% 
% % -------------------------------------------------------------------------
% % 3) Sort these thresholds if necessary
% %    Ideally motion_data is already in ascending FD_threshold order,
% %    but let's be safe and sort them.
% % -------------------------------------------------------------------------
% [FDthresholds_sorted, sort_idx] = sort(FDthresholds_valid, 'ascend');
% motion_data_sorted = motion_data_valid(sort_idx);
% 
% % The # frames is the length of frame_removal in any one struct
% nTR = length(motion_data_sorted{1}.frame_removal);
% 
% % Initialize approx_FD
% approx_FD = zeros(nTR,1);
% 
% % -------------------------------------------------------------------------
% % 4) For each TR, find the largest threshold that keeps it
% % -------------------------------------------------------------------------
% for f = 1:nTR
%     last_keep_threshold = 0;
%     for i = 1:length(motion_data_sorted)
%         if motion_data_sorted{1,i}.frame_removal(f) == 1
%             % => This TR was kept at threshold FDthresholds_sorted(i)
%             last_keep_threshold = FDthresholds_sorted(i);
%         else
%             % => This TR was removed at threshold FDthresholds_sorted(i)
%             % We can break now, or keep going if you want a different logic.
%             break;  
%         end
%     end
% 
%     % If the TR was never kept (always removed), last_keep_threshold stays 0.
%     % Alternatively, you could set it to FDthresholds_sorted(1) if you prefer.
%     approx_FD(f) = last_keep_threshold;
% end
% disp("done")
% end