function OutlierDetection(month, Econ, sincedate, lag_num, priceLimitIndex,CompList)
%%
% % Author: Yueshuang
% Date: 20201218
% This is the main function for the whole project
% Main idea: use 3 methods to find possible outliers under model calibration FS, 
% then compare with BBG to filter out the real outlier
% priceLimitIndex takes either 1 or 0
% lag_num is an integer, eg. lag_num = 3
% month eg. 202011
% Econ and priceLimitIndex shoud have the same size
% feasible Econ id can be found in the econList.csv in the folder
%
%%

mpath = mfilename('fullpath');
k = strfind(mpath,'VT\');
CommonToolPath = [mpath(1:k+2) 'VT_common_tools\'];
addpath (CommonToolPath);
global GC_VT
global_constants_VT();
VTpath = pwd;

if nargin < 5
    priceLimitIndex = 0;
end

if nargin < 4
    lag_num = 3;
end

if nargin <3
    sincedate = 19900101;
end

if nargin <2
    Econ = getAllEcons();
end


m = size(Econ, 1);
n = size(priceLimitIndex, 1);
if n<m
    priceLimitIndex(n:m, 1) = 0;
end


for i = 1:m % iterate through econs   
    fprintf(['Econ ' num2str(Econ(i)) ' start...\n']);
    % prepare FS :change FS BBG_ID to u3_id and only select columns in use
    MCPath = [GC_VT.dataEnv 'ProductionData\ModelCalibration\' num2str(month) '\IDMTData\CleanData\FinancialStatement\Complete\'];
    try
        load([MCPath, 'FinancialStatement_', num2str(Econ(i)), '.mat'])
    catch
        disp(['Econ ' num2str(Econ(i)) ' does not exist.'])
        continue
    end
    financialStatementComplete = financialStatement;
    FinancialStatementComplete = FinancialStatement;
    
    % this FS is the one we will use because this FS is most raw without
    % much treatment like fx rate 
    MCPath = [GC_VT.dataEnv 'ProductionData\ModelCalibration\' num2str(month) '\IDMTData\CleanData\FinancialStatement\Reference\'];
    try
        load([MCPath, 'FS_', num2str(Econ(i)), '.mat'])
    catch
        disp(['Econ ' num2str(Econ(i)) ' does not exist.'])
        continue
    end    
%    financialStatement(:,1) = financialStatementComplete(:,1);
    fsfield = fieldnames(FinancialStatementComplete);
    numidx = arrayfun(@(x) getfield(FinancialStatement,cell2mat(x)),fsfield(4:11));
    fsfield = [[1 2 3 4] numidx'];
    financialStatement = financialStatement(:,fsfield);
    financialStatementRevision = financialStatementRevision(:,(numidx - 4),1);
    clear financialStatementComplete FinancialStatementComplete 
    % for method 3 use
    save([VTpath '\tempFS\FinancialStatement_' num2str(Econ(i)) '.mat'],'financialStatement');
    
    if nargin == 6
        idx = ismember(financialStatement(:,1), CompList);
        financialStatement = financialStatement(idx, :);
    end
    
    
    % Method 1
    fs_byExp(Econ(i),financialStatement,sincedate);
        
    % Method 2
    fs_byChange(lag_num,Econ(i),financialStatement,sincedate);
        
    % Method 3
    system(['python flagOutliers_byTZscore_LOF.py ' num2str(Econ(i)) ' ' VTpath ' '  num2str(sincedate)]);
    
    % Combine all
    combinedOutlier(Econ(i), month, lag_num, GC_VT,financialStatement,financialStatementRevision);
    
    % compare with bbg
    system(['python connectBBG.py ' num2str(Econ(i)) ' ' VTpath ' ' num2str(month)]);
    
end


   
end
