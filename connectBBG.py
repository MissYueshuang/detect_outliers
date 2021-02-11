# -*- coding: utf-8 -*-
"""
Created on Tue Dec  1 20:56:08 2020

@author: rmileng
"""
import pandas as pd
import pyodbc
import numpy as np
from dateutil.parser import parse
import os
import sys
from xbbg import blp

def getFPT(df):
    FPT = { 1:('A','A'),
            11:('S','S1'),
            12:('S','S2'),
            21:('Q','Q1'),
            22:('Q','Q2'),
            23:('Q','Q3'),
            24:('Q','Q4')}
    return FPT.get(df.Fiscal_period_ID)

def getFreq(Fiscal_period_ID):
    if Fiscal_period_ID == 1:
        return 12
    elif (Fiscal_period_ID>1) & (Fiscal_period_ID<20):
        return 6
    else:
        return 3

def getBQL(Ticker,fsField,FPR,FPT):
    return '=BQL("{0}","{1}(FPR={2},FPT={3})")'.format(Ticker,fsField,FPR,FPT)


def getBDP(Ticker,BBGname,FPR,Fiscal_year):
    value = blp.bdp(Ticker,BBGname,FUND_PER=FPR,EQY_FUND_YEAR=Fiscal_year)
    if value.empty:
        return np.nan
    return value.iloc[0,0]
             
def connectBBG(econ,VTpath,yyyymm):    
    # initialize    
    Outliers = pd.read_excel(VTpath+'\outliersCombined\CombinedOutliers_Econ%d.xls'%econ, header=None)
    Outliers.columns = ['u3_id','fsField','PE','Value','ID']
    compList = Outliers.u3_id.drop_duplicates()
    compList = ','.join([str(icomp) for icomp in compList])
    columnName = pd.read_csv(VTpath+r'\columnName.csv',header=None)
    fsfieldName = columnName.iloc[4:,:].reset_index(drop=True)
    fsfieldName = fsfieldName.to_dict()[0]
        
    # this step is to get ID_BB info and ticker
    cnt = pyodbc.connect('Driver=xx; Server=xx; Database=xx; Trusted_Connection=xx;')
    query = 'select map.U3_COMPANY_NUMBER as u3_num, MAP.U4_COMPANY_ID AS U4_ID, ci.ID_BB_COMPANY,ci.Ticker '\
    'from tier3.ref.company_number_mapping_Temp map '\
    'left join tier3.ref.company_information ci on map.u4_company_id = ci.company_id '\
    'where map.U3_COMPANY_NUMBER in (compList);'
    query = query.replace('compList',compList)
    TickerInfo = pd.read_sql(query, con = cnt)
    Outliers = pd.merge(Outliers,TickerInfo,how='left',left_on='u3_id',right_on='u3_num')
    Outliers.Ticker = Outliers.Ticker + ' Equity'
    
    # this step is to get FS related ticker (normal case)
    query2 = 'select ent.Latest_period_end as PE, ent.ID, ent.Company_ID as U4_ID, ent.ID_BB_COMPANY, ent.Fiscal_year,ent.Fiscal_period_ID,Accounting_standard_ID,Filing_status_ID, '\
    'Is_consolidated, Fundamentals_type_ID from tier2.ent.fundamentals ent where Company_ID in (compList);'
    U4_ID = Outliers.U4_ID.drop_duplicates()
    U4_ID = ','.join([str(icomp) for icomp in U4_ID])
    query2 = query2.replace('compList',U4_ID)
    DBinfo = pd.read_sql(query2, con = cnt)
    DBinfo = DBinfo[DBinfo.PE.notnull()]
    DBinfo.PE = [int(parse(i).strftime('%Y%m%d')) for i in DBinfo.PE]
    Outliers.ID_BB_COMPANY = Outliers.ID_BB_COMPANY.astype(int)
    OutliersFS = pd.merge(Outliers,DBinfo,on=['U4_ID','ID','PE','ID_BB_COMPANY'], how='left')
       
    # Find real net income
    OutliersNI = OutliersFS[OutliersFS.fsField==6]
    OutliersFS = OutliersFS[OutliersFS.fsField!=6]
    OutliersNI = pd.merge(OutliersNI,DBinfo,on=['U4_ID','ID_BB_COMPANY','PE','Fiscal_year','Fiscal_period_ID','Accounting_standard_ID','Filing_status_ID','Is_consolidated'], how='left')
    OutliersNI = OutliersNI[OutliersNI.Fundamentals_type_ID_y==3]
    U4_ID = OutliersNI.U4_ID.drop_duplicates()
    U4_ID = ','.join([str(icomp) for icomp in U4_ID])
    query2 = 'select dat.[117] as NI, ent.Latest_period_end as PE, ent.ID, ent.Company_ID as U4_ID, ent.ID_BB_COMPANY '\
    'from (select ID_FS_ENT, Field_ID, Field_value = case when Update_lock = 1 then \'* \'+str(Field_value,20,3) else str(Field_value,20,3) end '\
    'from dat.FUNDAMENTALS where ID_FS_ENT in (select id from ent.fundamentals where Company_ID in (compList)) '\
    'and Field_ID = 117 ) as pt pivot (max(pt.field_value) '\
    'for pt.field_id in ([117])) dat left join ent.fundamentals ent on dat.ID_FS_ENT = ent.ID '\
    'order by ent.Latest_period_end, ent.Announcement_date;'    
    query2 = query2.replace('compList',U4_ID)
    DBinfo2 = pd.read_sql(query2, con = cnt)
    
    OutliersNI = pd.merge(OutliersNI,DBinfo2[["NI","ID","ID_BB_COMPANY"]],left_on=["ID_y","ID_BB_COMPANY"],right_on=["ID","ID_BB_COMPANY"],how='left')
    OutliersNI.Value = OutliersNI.NI
#    OutliersNI.rename(columns={"ID_y":"ID"},inplace=True)
    useCols = ['u3_id', 'fsField', 'PE',"ID", 'Value', 'ID_BB_COMPANY', 'Ticker', 'Fiscal_year', 'Fiscal_period_ID']
    Outliers =  pd.concat([OutliersFS[useCols],OutliersNI[useCols]],axis=0)       
    Outliers.to_csv(VTpath+r'\OutliersAfterBBG\%d\Outliers_beforeBDP_%d.csv'%(yyyymm,econ),index=False)    
    
     # this step is to prepare for BDP query
    print('start to try BDP query')
    Outliers[['FPT', 'FPR']] = Outliers.apply(getFPT, axis=1, result_type="expand")
    Outliers['FPR'] =  Outliers['FPR'].astype(str)
    Outliers.Fiscal_year = Outliers.Fiscal_year.astype(str)
    Outliers['BBGname'] = (Outliers['fsField']-1).apply(lambda x: fsfieldName.get(x))  
    
    # there are some fs's data source is not BBG, we leave the comparison to DMT
    Outliers_nonBBG = Outliers[Outliers.Fiscal_period_ID.isnull()]
    Outliers_BBG =  Outliers[Outliers.Fiscal_period_ID.notnull()]
    Outliers_BBG['BBGValue'] = Outliers_BBG.apply(lambda x:getBDP(x['Ticker'],x['BBGname'],x['FPR'],x['Fiscal_year']),axis=1)  
    Outliers_nonBBG['BBGValue'] = None
    useCols = ['u3_id','ID_BB_COMPANY','Ticker','ID','BBGname','Fiscal_year','FPR','Value','BBGValue']
    Outliers_final = pd.concat([Outliers_BBG[useCols],Outliers_nonBBG[useCols]],axis=0)
    
    # compare the consistency and screen out final outlier
    Outliers_final.Value = Outliers_final.Value.astype(float)
    Outliers_final = Outliers_final[abs(Outliers_final.Value-Outliers_final.BBGValue)>1e-3].append(Outliers_final[Outliers_final.BBGValue.isnull()])
    Outliers_final.to_csv(VTpath+r'\OutliersAfterBBG\%d\Outliers_final_%d.csv'%(yyyymm,econ),index=False)    
    
    
if __name__ == '__main__':
#     VTpath = r'\\unicorn7\TeamData\VT\Yueshuang\Matlab\FS'
#     econ = 15
#     yyyymm = 202011
    econ = int(sys.argv[1])   
    VTpath = sys.argv[2]
    yyyymm = int(sys.argv[3])
    if os.path.isdir(VTpath+r'\OutliersAfterBBG\%d'%yyyymm)==False:
        os.mkdir(VTpath+r'\OutliersAfterBBG\%d'%yyyymm)
    connectBBG(econ,VTpath,yyyymm)
    

    
    
    
    
    