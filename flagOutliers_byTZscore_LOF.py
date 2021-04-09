
# coding: utf-8

import numpy as np
import pandas as pd
from sklearn.neighbors import LocalOutlierFactor as LOF

pd.options.mode.chained_assignment = None

def outlier_detection(k, date_start, mktcap_firmDF):
    
    company_id = mktcap_firmDF.columns[0]
    mktcap_firmDF.columns = ['mktcap']
    mktcap_firmDF['company_id'] = company_id
    mktcap_firmDF['trading_date'] = pd.to_datetime([str(item) for item in mktcap_firmDF.index])

    for i in range(1, k+1):
        mktcap_firmDF['mcng%d'% i] = mktcap_firmDF['mktcap'].pct_change(i, fill_method=None)
        mktcap_firmDF['mcng-%d'% i] = mktcap_firmDF['mktcap'].pct_change(-i, fill_method=None)
    mktcap_firmDF['mcng'] = mktcap_firmDF.loc[:, 'mcng1':'mcng-%d'% k].mean(axis=1)
    mktcap_firmDF['zscore'] = (mktcap_firmDF['mcng']-mktcap_firmDF['mcng'].mean())/mktcap_firmDF['mcng'].std()
    mktcap_firmDF['tzscore'] = np.sqrt((mktcap_firmDF.mcng - mktcap_firmDF.mcng.min())/(mktcap_firmDF.mcng.max()-mktcap_firmDF.mcng.min()))
    mktcap_firmDF.tzscore = (mktcap_firmDF.tzscore-mktcap_firmDF.tzscore.mean())/mktcap_firmDF.tzscore.std()
    
    # Transformed z-score
    outliers = mktcap_firmDF[(mktcap_firmDF['tzscore']>mktcap_firmDF['tzscore'].quantile(0.999)) | (mktcap_firmDF['tzscore']<mktcap_firmDF['tzscore'].quantile(0.005))]
    outliers = outliers[outliers['trading_date']>'2000-01-01']
    outliers = outliers.dropna()
    outliers = outliers[outliers.index.values>10]
    outliers = outliers[(((outliers['mcng1']>0.12) & (outliers['mcng-1']>0.12)) | ((outliers['mcng-1']<-0.12) & (outliers['mcng1']<-0.12)))]

    return outliers


def anomaly_detection(date_start, mktcap):

    k = 5    #time windown

    outliers = pd.DataFrame()

    for i in mktcap.columns:
        outliers = outliers.append(outlier_detection(k, date_start, mktcap[[i]]))
    if len(outliers)==0:
        pd.DataFrame().to_csv('\Suspicion_TZScore&LOF\Processing\output_final.csv')
    else:
        outliers.drop_duplicates().to_csv('\Suspicion_TZScore&LOF\Processing\output_final.csv')
    
    final = outliers.iloc[:,[0,1,2]]
    if len(final) <1:
        final.to_csv('\Suspicion_TZScore&LOF\Processing\Suspicions.csv', index = False)
    else:
        final.drop_duplicates().to_csv('\Suspicion_TZScore&LOF\Processing\Suspicions.csv', index = False)


def outlier_detection_lof(k, date_start, mktcap_firmDF):

    company_id = mktcap_firmDF.columns[0]
    mktcap_firmDF.columns = ['mktcap']
    mktcap_firmDF['company_id'] = company_id
    mktcap_firmDF['trading_date'] = pd.to_datetime([str(item) for item in mktcap_firmDF.index])
    
    for i in range(1, k+1):
        mktcap_firmDF['mcng%d'% i] = mktcap_firmDF['mktcap'].pct_change(i, fill_method=None)
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
    outliers = outliers[outliers['trading_date']>'2000-01-01']
    outliers = outliers[outliers.index.values>10]
    outliers = outliers.dropna()
    outliers = outliers.replace(0., np.nan)
    outliers = outliers.dropna(thresh=13, axis=0)
    outliers = outliers.replace(np.nan, 0.)
    
    return outliers

def anomaly_detection_lof(date_start, mktcap):

    k = 5

    outliers = pd.DataFrame()

    for i in mktcap.columns:
        outliers = outliers.append(outlier_detection_lof(k, date_start, mktcap[[i]]))

    if len(outliers)==0:
        outliers.to_csv('\Suspicion_TZScore&LOF\Processing\output_LOF.csv')
        pd.DataFrame().to_csv('\Suspicion_TZScore&LOF\Processing\Suspicions_LOF.csv', index = False)    
    else:
        outliers.drop_duplicates().to_csv('\Suspicion_TZScore&LOF\Processing\output_LOF.csv' )

    final = outliers.iloc[:,[0,1,2]]
    if len(final) == 0:
        final.to_csv('\Suspicion_TZScore&LOF\Processing\Suspicions_LOF.csv', index = False)
    else:
        final.drop_duplicates().to_csv('\Suspicion_TZScore&LOF\Processing\Suspicions_LOF.csv', index = False)
            
def anomaly_detection_final(date_start, mktcap):

    anomaly_detection(date_start, mktcap);
    
    anomaly_detection_lof(date_start, mktcap);


    df1 = pd.read_csv('\Suspicion_TZScore&LOF\Processing\Suspicions.csv')
    df2 = pd.read_csv('\Suspicion_TZScore&LOF\Processing\Suspicions_LOF.csv')

    if 'mktcap' in df1.columns and 'mktcap' in df2.columns:
        df = pd.merge(df1, df2, how = 'inner', on = ['trading_date', 'mktcap']).dropna()
    else:
        df = pd.DataFrame(columns = ['trading_date','mktcap'])
    if len(df)==0 and len(df1)>0:
        df = df1
    elif len(df)==0 and len(df2)>0:
        df = df2
        
    if 'mktcap' not in df.columns:
        df['mktcap'] = np.nan*np.ones((len(df),1))
    df['trading_date'] = pd.to_datetime(df['trading_date'], infer_datetime_format = True).dt.strftime('%Y%m%d')
    if len(df)==1:
        df.to_csv('\Suspicion_TZScore&LOF\V2\Suspicions.csv', index=False)
    else:
        df.drop_duplicates().to_csv('\Suspicion_TZScore&LOF\V2\Suspicions.csv', index=False)


if __name__ == '__main__':
    date_start = '2000-01-01'
    anomaly_detection_final(date_start, mktcap)
    

