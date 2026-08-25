function segmentation_result = simulate_probabilistic_segmentation(start, end_, n)
    x = linspace(start, end_, n);
    d = abs(x);
    mu = 0.0;
    sigma = 2.0;
    segmentation_result = exp(-((d - mu) .^ 2) / (2.0 * sigma ^ 2));
    segmentation_result(segmentation_result < 0.01) = 0;
end

% 
% function segmentation_result = simulate_probabilistic_segmentation(start, end_)
%     [x, y] = meshgrid(linspace(start, end_, 100), linspace(start, end_, 100));
%     d = sqrt(x .^ 2 + y .^ 2);
%     mu = 0.0;
%     sigma = 2.0;
%     segmentation_result = exp(-((d - mu) .^ 2) / (2.0 * sigma ^ 2));
%     segmentation_result(segmentation_result < 0.01) = 0;
% end