function [suspicious] = flagOutliers_byExpFit(marketcapClean,Econ,sincedate)
%% This Function is used to flag suspicious market cap spike according to exponential distribution

savepath = [pwd '\OutliersbyExpFit\'];

comp = unique(marketcapClean(:,1));
marketcapClean(:,1) = [];

suspicious = [];
for j = 2:size(marketcapClean, 2)
    mc_comp = marketcapClean(1:end, j);
    n = 5;
    mc_change = zeros([length(mc_comp), 2]);
    
    % Logic dealing with non-positive mc
    idx = find(mc_comp < 0);
 %   suspicious = [suspicious; [j*ones(size(idx)), marketcapClean(idx, 1), mc_comp(idx)]];
    if ~isempty(idx)
        for i = idx'
            mc_change(i, :) = [nan, nan];
            mc_comp(i) = -mc_comp(i);
        end
    end
    
    idx = find(mc_comp == 0);
%    suspicious = [suspicious; [j*ones(size(idx)), marketcapClean(idx, 1), mc_comp(idx)]];
    if ~isempty(idx)
        for i = idx'
            mc_change(i, :) = [nan, nan];
            mc_comp(i) = 1e-8;
        end       
%         mc_change(idx, :) = [nan, nan];
%         mc_comp(idx) = 1;
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
    
    mc_change = [marketcapClean(1:end, 1), mc_change];
    mc_change(isnan(mc_change(:, 2)), :) = [];
    mu1 = expfit(mc_change(:, 2));
    mu2 = expfit(mc_change(:, 3));
    
    
    bound1 = expinv(1 - 1e-10, mu1);
    bound2 = expinv(1 - 1e-10, mu2);
    this_suspicious = mc_change(mc_change(:, 2) > bound1 & mc_change(:, 3) > bound2, :);
%     hold off
%     scatter(mc_change(:, 2), mc_change(:, 3))
%     hold on
%     plot(bound1*ones([101,1]), bound2:bound2/100:2*bound2)
%     plot(bound1:bound1/100:2*bound1, bound2*ones([101,1]))
    date = this_suspicious(:, 1);
    suspicious = [suspicious; [(j-1)*ones(size(date)), date, marketcapClean(ismember(marketcapClean(:, 1), date), j)]];
end

suspicious = unique(suspicious, 'rows');
suspicious = [comp*ones([size(suspicious, 1), 1]), suspicious];
suspicious(suspicious(:,3)<sincedate,:) = [];
% if ~isempty(suspicious)
%     table = tabulate(suspicious(:,2));
%     table(table(:,2) == 0, :) = [];
%     table = sortrows(table, 2, 'descend');
% else
%     table = [];
% end
%dlmwrite([savepath '\Suspicious_', num2str(comp), '.csv'], suspicious, 'precision', '%.8f')
end