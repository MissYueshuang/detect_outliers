function thisEconOutliers = fs_byChange(lag_num,econList,financialStatement,sincedate)
    for iecon = econList'
        savepath = [pwd '\v3_OutliersbyRelativeChange_lag' num2str(lag_num)];
        if ~isdir(savepath)
            mkdir(savepath)
        end
        
 %       load([path '\FinancialStatement_' num2str(iecon) '.mat']);               
        compList = unique(financialStatement(:,1));
 %       fsName = fieldnames(FinancialStatement);
        thisEconOutliers = [];
        for icomp = compList'        
            marketcapClean = financialStatement(financialStatement(:,1)==icomp,:);
            marketcapClean(:,[3,4]) = [];
            [outliers,lag_num] = flagOutliers_byRelativeChange_v3 (iecon, marketcapClean,sincedate,-0.9,2,lag_num);         
            thisEconOutliers = [thisEconOutliers;outliers];
        end

        dlmwrite([savepath '\OutliersRevChange_', num2str(iecon), '.csv'], thisEconOutliers, 'precision', '%.8f')
    end
end