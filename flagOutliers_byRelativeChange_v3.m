function [ outliers ] = flagOutliers_byRelativeChange_v3 (marketcapClean, lag_num, priceLimitIndex )
%This function is to flag potential outliers of mktcap

if nargin < 3
    priceLimitIndex = 0;
end

if nargin < 2
    lag_num = 3;
end

%threshold setting
if priceLimitIndex 
    thresholdFix = 0.15;
else
    thresholdIndex = 4; thresholdFix = 0.6;
end

savepath = [pwd '\v3_OutliersbyRelativeChange_lag' num2str(lag_num)];
if ~isdir(savepath)
    mkdir(savepath)
end

marketcap = marketcapClean;
fullperiod = marketcap(:,1);

row = size(marketcap,1);
col = size(marketcap,2) -1;
marketcap_inCell = mat2cell( marketcap(:, 2:end), row, ones(col,1) );
marketcap_inCell = cellfun(@(x) [fullperiod, x], marketcap_inCell, 'uniformoutput', 0 );

outliers = cellfun(@(x) flagOutliers(x), marketcap_inCell,'uniformoutput', 0 );

outliers = outliers';
outliers = cell2mat(outliers);
outliers = sortrows(outliers);

if ~isempty(outliers)
    outliers( outliers(:,3)<19900000, : ) = []; 
end %keep only records after 1990

filename = [savepath '\Outliers.xls'];
if ~isempty(outliers)
    xlswrite(filename, outliers);
end

    function [ outliers ] = flagOutliers(x)
        mktcap = x(2:end, 2);
        
        nanPos = find(isnan(mktcap));
        notNanPos = find(~isnan(mktcap));
        if length(notNanPos) < lag_num + 1 % no enough valid points
            outliers = [];
            return
        end
        
        if priceLimitIndex
            threshold = thresholdFix;
        else
            mktcapWOnan = mktcap(notNanPos);
            dailyReturn = diff(mktcapWOnan)./mktcapWOnan(1:end-1);
            compsd = std(dailyReturn);
            threshold1 = compsd * sqrt(lag_num) * thresholdIndex;
            threshold = max(threshold1, thresholdFix);
        end
        
        
        firstPos = min(notNanPos); %position of first mktcap value
        if ~isempty(nanPos)
            nanPos( nanPos < firstPos ) =[];
            %replace the nan mktcap with lastest available mktcap
            for iPos = nanPos'
                repPos = max( notNanPos(notNanPos<iPos) );
                mktcap(iPos) = mktcap(repPos);
            end
        end
        
        change_previous_min = [];
        change_following_min = [];
        change_previous_max = [];
        change_following_max = [];
        for i = 1:length(mktcap)
            if i <= lag_num+1
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(1:i)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i:i+lag_num)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(1:i)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i:i+lag_num)) - 1];
            elseif i >= length(mktcap)-lag_num
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(i-lag_num:i)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i:end)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(i-lag_num:i)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i:end)) - 1];
            else
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(i-lag_num:i)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i:i+lag_num)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(i-lag_num:i)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i:i+lag_num)) - 1];
            end
        end 
                
        
        changes_min = [change_previous_min, change_following_min, change_previous_min.*change_following_min];
        
        %select outliers
        %both change > threshold and ops direction
        index1 = find( (abs(changes_min(:,1)) > threshold) & (abs(changes_min(:,2)) > threshold) & (changes_min(:,3)>0));
        
        changes_max = [change_previous_max, change_following_max, change_previous_max.*change_following_max];
        index2 = find( (abs(changes_max(:,1)) > threshold) & (abs(changes_max(:,2)) > threshold) & (changes_max(:,3)>0));
        
        index1 = union(index1, index2);
        
        %delete the potential outliers that are actually nan
        outlierIndex = intersect(index1, notNanPos);
        if isempty(outlierIndex)
            outliers = [];
            return
        end
        
        outliers = x(outlierIndex+1,:);
        comp = x(1,2);
        comp_info = [repmat(size(outlierIndex,1),1), repmat(comp,size(outlierIndex,1),1)];
        outliers = [comp_info, outliers];
    end

end

