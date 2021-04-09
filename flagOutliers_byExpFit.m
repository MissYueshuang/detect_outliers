function [suspicious, table] = flagOutliers_byExpFit(marketcapClean)
%% This Function is used to flag suspicious market cap spike according to exponential distribution

savepath = [pwd '\OutliersbyExpFit'];

if ~isdir(savepath)
    mkdir(savepath)
end

suspicious = [];
% loop for each company, the first row is company name and the first column is date series
for j = 2:size(marketcapClean, 2) 
    mc_comp = marketcapClean(2:end, j);
    n = 5;
    mc_change = zeros([length(mc_comp), 2]);
    
    % Logic dealing with non-positive mc
    idx = find(mc_comp < 0);
    suspicious = [suspicious; [marketcapClean(1, j)*ones(size(idx)), marketcapClean(idx+1, 1), mc_comp(idx)]];
    if ~isempty(idx)
        mc_change(idx, :) = [nan, nan];
        mc_comp(idx) = -mc_comp(idx);
    end
    
    idx = find(mc_comp == 0);
    suspicious = [suspicious; [marketcapClean(1, j)*ones(size(idx)), marketcapClean(idx+1, 1), mc_comp(idx)]];
    if ~isempty(idx)
        mc_change(idx, :) = [nan, nan];
        mc_comp(idx) = 1;
    end
    % End

    for i = 1:length(mc_comp)       
        if i > n && i <= length(mc_comp) - n
            if sum(isnan(mc_comp([i-n, i, i+n]))) == 0
                mc_change(i, 1) = max([mc_comp(i), mc_comp(i-n)]) / min([mc_comp(i), mc_comp(i-n)]) - 1;
                mc_change(i, 2) = max([mc_comp(i+n), mc_comp(i)]) / min([mc_comp(i+n), mc_comp(i)]) - 1;
            else
                mc_change(i, :) = [nan, nan];
            end
        else
            mc_change(i, :) = [nan, nan];
        end
    end
    
    mc_change = [marketcapClean(2:end, 1), mc_change];
    mc_change(isnan(mc_change(:, 2)), :) = [];
    mu1 = expfit(mc_change(:, 2));
    mu2 = expfit(mc_change(:, 3));
    
    
    bound1 = expinv(1 - 1e-10, mu1);
    bound2 = expinv(1 - 1e-10, mu2);
    this_suspicious = mc_change(mc_change(:, 2) > bound1 & mc_change(:, 3) > bound2, :);

    comp = marketcapClean(1, j);
    date = this_suspicious(:, 1);
    suspicious = [suspicious; [comp*ones(size(date)), date, marketcapClean(ismember(marketcapClean(:, 1), date), j)]];
end

suspicious = unique(suspicious, 'rows');

dlmwrite([savepath '\Suspicious.csv'], suspicious, 'precision', '%.8f')

end