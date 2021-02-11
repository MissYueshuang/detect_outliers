function thisEconSuspicious = fs_byExp(econList,financialStatement,sincedate)
    for iecon = econList'
        savepath = [pwd '\OutliersbyExpFit\'];
        if ~isdir(savepath)
            mkdir(savepath)
        end
%        load([path '\FinancialStatement_' num2str(iecon) '.mat']);               
        compList = unique(financialStatement(:,1));
 %       fsName = fieldnames(FinancialStatement);
        thisEconSuspicious = [];
        for icomp = compList'        
            marketcapClean = financialStatement(financialStatement(:,1)==icomp,:);
            marketcapClean(:,[3,4]) = [];
            suspicious = flagOutliers_byExpFit(marketcapClean,iecon,sincedate);
            thisEconSuspicious = [thisEconSuspicious;suspicious];            
        end
        
        dlmwrite([savepath '\Suspicious_', num2str(iecon), '.csv'], thisEconSuspicious, 'precision', '%.8f')
    end
end