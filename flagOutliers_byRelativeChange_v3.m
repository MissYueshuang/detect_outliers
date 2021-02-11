function [ outliers,lag_num ] = flagOutliers_byRelativeChange_v3 ( econ, marketcapClean, sincedate, threshold1, threshold2,lag_num )
%This function is to flag potential outliers of mktcap for a specific econ.

%Idea: Fill nan data by latest available data first,
%find dates that the abs changes compared to previous day and
%following day are larger then threshold, and the change direction is
%opposite.
%Special treatment for first few days: change previous: compare to first day
%for last few days: change following: compare to last day

%Threshold setting:
%For econ with price limit, e.g. China, we can set a fixed threshold to be 0.15
%and lag to be 1 (suggest setting to reflect this limit).
%
%For econ without price limit, the thresholds are different for each
%company. first define a fixed thresholdFix, and
%calculate threshold1 = (comp mktcap return's sd)*sqrt(lag_num)*thresholdIndex,
%the final threshold used for this company will be max(threshold, thresholdFix)
%

% if nargin < 4
%     priceLimitIndex = 0;
% end

if nargin < 6
    lag_num = 3;
end

%threshold setting
% if priceLimitIndex %e.g. China, the limit is 0.1
%  %   thresholdFix = 0.15;
%     thresholdIndex = 6; thresholdFix = 0.6;
% else
%     thresholdIndex = 6; thresholdFix = 0.6;
% end

comp = unique(marketcapClean(:,1));
marketcap = marketcapClean(:,2:end);
marketcap = [0:size(marketcap,2)-1;marketcap];

fullperiod = marketcap(:,1);

row = size(marketcap,1) ;
col = size(marketcap,2) -1;
marketcap_inCell = mat2cell( marketcap(:, 2:end), row, ones(col,1) );
marketcap_inCell = cellfun(@(x) [fullperiod, x], marketcap_inCell, 'uniformoutput', 0 );

outliers = cellfun(@(x) flagOutliers(x), marketcap_inCell,'uniformoutput', 0 );

outliers = outliers';
outliers = cell2mat(outliers);
outliers = sortrows(outliers);

if ~isempty(outliers)
    outliers( outliers(:,3)<sincedate, : ) = []; 
end %keep only records after 2010



    function [ outliers ] = flagOutliers(x)
        FSField = x(1,2);
        mktcap = x(2:end, 2);
        
        nanPos = find(isnan(mktcap));
        notNanPos = find(~isnan(mktcap));
        if length(notNanPos) < 10 %no enough valid points
            outliers = [];
            return
        end
        smallIdx = find(mktcap<0.1);
        
        NegIdx = find(mktcap<0);
        
%         if priceLimitIndex
%             threshold = thresholdFix;
%         else
%             mktcapWOnan = mktcap(notNanPos);
%             dailyReturn = diff(mktcapWOnan)./mktcapWOnan(1:end-1);
%             compsd = std(dailyReturn);
%             threshold1 = compsd * sqrt(lag_num) * thresholdIndex;
%             threshold = max(threshold1, thresholdFix);
%         end
        
        
        firstPos = min(notNanPos); %position of first mktcap value
        if ~isempty(nanPos)
            nanPos( nanPos < firstPos ) =[];
            %replace the nan mktcap with lastest available mktcap
            if ~isempty(nanPos)
                for iPos = nanPos'
                    repPos = max( notNanPos(notNanPos<iPos) );
                    mktcap(iPos) = mktcap(repPos);
                end
            end
        end
        
%         lag_diff = mktcap( (1+lag_num):end )-mktcap( 1:(end-lag_num) );
%         previous_special = ( mktcap(firstPos:(firstPos+lag_num-1)) - mktcap(firstPos) ) ./ mktcap(firstPos);
%         following_special = ( mktcap(end-lag_num+1:end) - mktcap(end) ) ./ mktcap(end);
%         
%         change_previous = [previous_special; lag_diff./mktcap(1:end-lag_num)];
%         change_following = [lag_diff./mktcap(1+lag_num:end); following_special];
        change_previous_min = [];
        change_following_min = [];
        change_previous_max = [];
        change_following_max = [];
        for i = 1:length(mktcap)
            if i == 1
                 change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(1:i)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i+1:i+lag_num)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(1:i)) - 1 ];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i+1:i+lag_num)) - 1];
            elseif  (i < lag_num+1) & (i > 1)
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(1:i-1)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i+1:i+lag_num)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(1:i-1)) - 1 ];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i+1:i+lag_num)) - 1];
            elseif i == length(mktcap)
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(i-lag_num:i-1)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i:end)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(i-lag_num:i-1)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i:end)) - 1];       
            elseif i > length(mktcap)-lag_num
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(i-lag_num:i-1)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i+1:end)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(i-lag_num:i-1)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i+1:end)) - 1];
            else
                change_previous_min = [change_previous_min; mktcap(i)/min(mktcap(i-lag_num:i-1)) - 1];
                change_following_min = [change_following_min; mktcap(i)/min(mktcap(i+1:i+lag_num)) - 1];
                change_previous_max = [change_previous_max; mktcap(i)/max(mktcap(i-lag_num:i-1)) - 1];
                change_following_max = [change_following_max; mktcap(i)/max(mktcap(i+1:i+lag_num)) - 1];
            end
        end 
        
 %       threshold1 = -0.9;
  %      threshold2 = 2;
        
        changes_min = [change_previous_min, change_following_min, change_previous_min.*change_following_min];
        changes_min(all(isinf(changes_min),2),:) = NaN;
        
        %select outliers
        %both change > threshold and ops direction
        index1 = find( (changes_min(:,1) < threshold1) & (changes_min(:,2) < threshold1) & (changes_min(:,3)>0));
        
        changes_max = [change_previous_max, change_following_max, change_previous_max.*change_following_max];
        index2 = find( (changes_max(:,1) > threshold2) & (changes_max(:,2) > threshold2) & (changes_max(:,3)>0));
        
        index = union(index1, index2);
%         index = index2;
        index = setdiff(index,smallIdx);
        index = reshape(index,[],1);
 %       index = union(idx,NegIdx);
        
        outlierIndex = intersect(index, notNanPos);
        if isempty(outlierIndex)
            outliers = [];
            return
        end
        
        outliers = x(outlierIndex+1,:);
        
   %     comp = x(1,2);
        comp_info = [repmat(comp,size(outlierIndex,1),1), repmat(FSField,size(outlierIndex,1),1)];
        outliers = [comp_info, outliers];
        
    end

end

