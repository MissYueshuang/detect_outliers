function combinedOutlier(Econ, month, lag_num,GC_VT,financialStatement,financialStatementRevision )

% Econ = CommonEconomies.economies(:,[3,5]);
% Econ = cell2mat(Econ);
% Econ = Econ( ~isnan(Econ(:,2)), 1);
Econ = sortrows(Econ);

mktcapPath = [GC_VT.dataEnv 'ProductionData\ModelCalibration\' num2str(month) '\IDMTData\CleanData\EquityWithoutStalePrice\'];
method1Path = [pwd '\v3_OutliersbyRelativeChange_lag' num2str(lag_num) '\'];
method2Path = [pwd '\OutliersbyExpFit\'];
method3Path = [pwd '\Suspicion_TZScore&LOF\V2\'];

reportPath = [pwd '\outliersCombined\'];
if ~exist(reportPath)
mkdir(reportPath)
end


for iEcon = Econ(:)'
    try
        outlier1 = xlsread([method1Path 'OutliersRevChange_' num2str(iEcon) '.csv']);
    catch
        outlier1 = [];
    end
    
    try
        outlier2 = xlsread([method2Path 'Suspicious_' num2str(iEcon) '.csv']);
    catch
        outlier2 = [];
    end

    try
        [outlier3, ~, ~] = xlsread([method3Path 'Suspicious_' num2str(iEcon) '.csv']);

    outlier3 = outlier3(~isnan(outlier3(:, 4)), :);
    catch
        outlier3 = [];
    end
    
    % End
    outlierAll = [outlier1(:,1:4); outlier2(:,1:4); outlier3];
    filename = [reportPath 'CombinedOutliers_Econ' num2str(iEcon) '.xls'];
    
    outlierAll(:,5) = zeros(size(outlierAll,1),1);
    for i = 1:size(outlierAll,1)
        [lia,loc] = ismember(financialStatement(:,[1,2]),outlierAll(i,[1,3]),'rows');
        idx = find(loc>0);
        outlierAll(i,5) = financialStatementRevision(idx,outlierAll(i,2));
    end
    
    if ~isempty(outlierAll)
        [~, ia, ~] = unique(outlierAll(:,[1,2,3]), 'rows');
        outlierAll = outlierAll(ia, :);
        xlswrite(filename, outlierAll);
    else
        fprintf(['No outlier detected for econ ' num2str(iEcon) '. \n']);
    end
    
    
    clear outlier1 outlier2 outlier3 outlierAll
%     fprintf(['Econ ' num2str(iEcon) ' combined outliers finished. \n']);
    
end


