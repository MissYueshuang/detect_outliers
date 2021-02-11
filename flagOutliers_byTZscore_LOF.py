
# coding: utf-8

import numpy as np
import pandas as pd
import scipy.io 
import sys
from sklearn.neighbors import LocalOutlierFactor as LOF

pd.options.mode.chained_assignment = None

def outlier_detection(k, date_start, mktcap_firmDF,columnName,threshold=0.3):

    if mktcap_firmDF.ndim == 1:
        outliers = pd.DataFrame()
        return outliers
    mktcap_firmDF.reset_index(inplace=True)
    mktcap_firmDF.insert(1,'fsField',columnName.index(mktcap_firmDF.columns[2])-3)
    mktcap_firmDF.rename(columns={mktcap_firmDF.columns[3] : 'mktcap'},inplace=True)
    
    for i in range(1, k+1):
        mktcap_firmDF['mcng%d'% i] = mktcap_firmDF['mktcap'].pct_change(i, fill_method=None)
        mktcap_firmDF['mcng-%d'% i] = mktcap_firmDF['mktcap'].pct_change(-i, fill_method=None)
        
    mktcap_firmDF['mcng'] = mktcap_firmDF.loc[:, 'mcng1':'mcng-%d'% k].mean(axis=1)
    mktcap_firmDF['zscore'] = (mktcap_firmDF['mcng']-mktcap_firmDF['mcng'].mean())/mktcap_firmDF['mcng'].std()
    mktcap_firmDF['tzscore'] = np.sqrt((mktcap_firmDF.mcng - mktcap_firmDF.mcng.min())/(mktcap_firmDF.mcng.max()-mktcap_firmDF.mcng.min()))
    mktcap_firmDF.tzscore = (mktcap_firmDF.tzscore-mktcap_firmDF.tzscore.mean())/mktcap_firmDF.tzscore.std()
    
    # Transformed z-score
    outliers = mktcap_firmDF[(mktcap_firmDF['tzscore']>mktcap_firmDF['tzscore'].quantile(0.999)) | (mktcap_firmDF['tzscore']<mktcap_firmDF['tzscore'].quantile(0.005))]
    outliers = outliers[outliers['Period_End']>date_start]
    outliers = outliers.dropna()
    outliers = outliers[outliers.index.values>0.1]
    outliers = outliers[(((outliers['mcng1']>threshold) & (outliers['mcng-1']>threshold)) | ((outliers['mcng-1']<-threshold) & (outliers['mcng1']<-threshold)))]

    return outliers


def anomaly_detection(compList, date_start, VTpath, mktcap, columnName, econ):

    k = 5    #time windown

    if type(compList) != list:
        compList = [compList]
    
    outliers = pd.DataFrame()
    for j in compList[:]:
        for i in mktcap.columns[1:]:
            outliers = outliers.append(outlier_detection(k, date_start, mktcap.loc[j,['Period_End',i]],columnName))
            
    if len(outliers)==0:
        pd.DataFrame().to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_%d.csv' % econ, index = False)
    else:
   #     outliers.drop_duplicates().to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\output_final_econ%d.csv' % j)
        final = outliers.drop_duplicates().iloc[:,[0,1,2,3]].rename(columns= {'Company_Number': 'u3_num'})
     #   final['econ'] = j
        if len(final) <1:
            final[['u3_num', 'fsField', 'Period_End', 'mktcap']].to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_%d.csv' % econ, index = False)
        else:
            final[['u3_num', 'fsField', 'Period_End', 'mktcap']].drop_duplicates().sort_values(by=['u3_num']).to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_%d.csv' % econ, index = False)


def outlier_detection_lof(k, date_start, mktcap_firmDF,columnName):

 #   company_id = mktcap_firmDF.index[0]
    if mktcap_firmDF.ndim == 1:
        outliers = pd.DataFrame()
        return outliers
    mktcap_firmDF.reset_index(inplace=True)
    mktcap_firmDF.insert(1,'fsField',columnName.index(mktcap_firmDF.columns[2])-3)
    mktcap_firmDF.rename(columns={mktcap_firmDF.columns[3] : 'mktcap'},inplace=True)
#    mktcap_firmDF['company_id'] = company_id
#    mktcap_firmDF['trading_date'] = pd.to_datetime([str(item) for item in mktcap_firmDF.index])
    
    for i in range(1, k+1):
        mktcap_firmDF['mcng%d'% i] =  mktcap_firmDF['mktcap'].pct_change(i, fill_method=None)
        mktcap_firmDF['mcng-%d'% i] = mktcap_firmDF['mktcap'].pct_change(-i, fill_method=None)

    X  = mktcap_firmDF.loc[:, 'mcng1':'mcng-%d'%k].replace([np.inf, -np.inf], np.nan).dropna()
    n_neighbors=20
    if len(X) < n_neighbors:
        outliers = pd.DataFrame()
        return(outliers)
    clf = LOF(n_neighbors, contamination = 0.001)
    y_pred = clf.fit_predict(X)
    index1 = np.where(y_pred==-1)
    outliers = mktcap_firmDF.loc[X.iloc[index1].index]
    outliers = outliers[outliers['Period_End']>=date_start]
    outliers = outliers[outliers.mktcap>0.1]
    outliers = outliers.dropna()
    outliers = outliers.replace(0., np.nan)
    outliers = outliers.dropna(thresh=14, axis=0)
    outliers = outliers.replace(np.nan, 0.)
    
    return outliers

def anomaly_detection_lof(compList, date_start, VTpath, mktcap, columnName, econ):

    k = 5

    if type(compList) != list:
        compList = [compList]
    
    outliers = pd.DataFrame()
    for j in compList[:]:   
        for i in mktcap.columns[1:]:
            outliers = outliers.append(outlier_detection_lof(k, date_start, mktcap.loc[j,['Period_End',i]],columnName))

    if len(outliers)==0:
     #   outliers.to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\output_LOF_econ%d.csv' % j)
        pd.DataFrame().to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_LOF_%d.csv' % econ, index = False)        
    else:
     #   outliers.drop_duplicates().to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\output_LOF_econ%d.csv' % econ)
        final = outliers.drop_duplicates().iloc[:,[0,1,2,3]].rename(columns= {'Company_Number': 'u3_num'})
         #   final['econ'] = econ
        if len(final) == 0:
            final[['u3_num','fsField', 'Period_End', 'mktcap']].to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_LOF_%d.csv' % econ, index = False)
        else:
            final[['u3_num', 'fsField', 'Period_End', 'mktcap']].drop_duplicates().sort_values(by=['u3_num']).to_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_LOF_%d.csv' % econ, index = False)

            
def anomaly_detection_final(econ, VTpath, date_start):

    FS = scipy.io.loadmat(VTpath+r'\tempFS\FinancialStatement_%d.mat'% econ)
    fs = FS['financialStatement'][:]
#    order = [FS['FinancialStatement'][ikey][0,0] for ikey in FS['FinancialStatement'].keys()]
#    columnName = [x for _,x in sorted(zip(order,FS['FinancialStatement'].keys()))]     
    columnName = pd.read_csv(VTpath+r'\columnName.csv',header=None)[0].tolist()
#    columnList = columnName[4:]
    fs = pd.DataFrame(fs,columns=columnName)
    fs.drop(columns=['Time_Use_First','Time_Use_Last'],inplace=True)
    compList = fs.iloc[:,0].drop_duplicates().to_list()
    fs = fs.set_index('Company_Number')
    pd.DataFrame(columnName).to_csv(VTpath+r'\columnName.csv',header=None,index=None)    
    
    # method 1
    anomaly_detection(compList, date_start, VTpath, fs, columnName, econ)
    # method 2
    anomaly_detection_lof(compList, date_start, VTpath, fs, columnName, econ)
    print('Econ %d finished processing '%econ)

#    if type(econList) != list:
#        econList = [econList]
#
#    for i in econList:
    try:
        df1 = pd.read_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_%d.csv' % (econ))
    except:
        df1=pd.DataFrame(columns = [ 'u3_num','fsField', 'Period_End'])
        
    try:
        df2 = pd.read_csv(VTpath + '\Suspicion_TZScore&LOF\Processing\Suspicious_LOF_%d.csv' % (econ))
    except:
        df2 = pd.DataFrame(columns = ['u3_num','fsField', 'Period_End'])
        
    if 'mktcap' in df1.columns and 'mktcap' in df2.columns:
        df = pd.merge(df1, df2, how = 'inner', on = ['u3_num', 'fsField', 'Period_End', 'mktcap']).dropna()
    else:
        df = pd.DataFrame(columns = ['u3_num', 'fsField', 'Period_End', 'mktcap'])
        
    if len(df)==0 and len(df1)>0:
        df = df1
    elif len(df)==0 and len(df2)>0:
        df = df2
        
    if 'mktcap' not in df.columns:
        df['mktcap'] = np.nan*np.ones((len(df),1))
        
#    df['trading_date'] = pd.to_datetime(df['trading_date'], infer_datetime_format = True).dt.strftime('%Y%m%d')
    if len(df)==1:
        df.to_csv(VTpath + '\Suspicion_TZScore&LOF\V2\Suspicious_%d.csv' % econ, index=False)
    else:
        df.drop_duplicates().to_csv(VTpath + '\Suspicion_TZScore&LOF\V2\Suspicious_%d.csv' % econ, index=False)
    print('Econ %d finished detection' %econ)


if __name__ == '__main__':
 #   date_start = 20100101    
    econList = int(sys.argv[1])   
    VTpath = sys.argv[2]
    date_start = int(sys.argv[3])
    anomaly_detection_final(econList,VTpath,date_start)








