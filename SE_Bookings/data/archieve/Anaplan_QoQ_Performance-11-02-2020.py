'''
Created on Jul 14, 2020

@author: aliu

'''
import pandas as pd
import project_config as cfg
import pyodbc
import datetime
from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types
#from builtins import None


#target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 - 08.03.2020.xlsx'
#M2_target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M2 - 08.03.2020.xlsx'
#target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 - 08.13.2020.xlsx'
#M2_target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M2 - 08.13.2020.xlsx'
target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 - 09.16.2020.xlsx'
M2_target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M2 - 09.16.2020.xlsx'
report_date = '2020-09-16'
supplement = "Supplement.xlsx"

# -------------------------------#
#      M1 Quota & Achievement
# -------------------------------#

prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Anaplan_Performance', skiprows=3, header=0, usecols = "Q:U")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

output = pd.read_excel(target, sheet_name='Sheet 1', skiprows=4, usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

#output['2021_CQ_QtD_Achievement'] = 0
#output['2021_CQ_Quota'] = 0
#output['CQ_IncrementBooking'] = 0
#output['CQ_AdvStage'] = 0
#output['CQ_ProjectedAchievement'] = 0
#output['CQ_Projected_Attn'] = 0

output['EmployeeID'] = output['EmployeeID'].astype('str')
output['CQ_YtD_Achievement'] = output['2021_Q1_Actual'] + output['2021_Q2_Actual'] + output['2021_CQ_QtD_Achievement']

quota_col = ['2021_Q1_Quota', '2021_Q2_Quota', '2021_CQ_Quota']
achievement_col = ['2021_Q1_Actual', '2021_Q2_Actual', '2021_CQ_QtD_Achievement']
attainment_col = ['2021_Q1_Attn', '2021_Q2_Attn']


CY_quota = pd.melt(output, id_vars = ['Name', 'EmployeeID'], value_vars=quota_col, var_name='Category', value_name='Quota').reindex()
CY_quota['FiscalYear'] = CY_quota['Category'].str[:4]
CY_quota['Period'] = CY_quota['Category'].str[5:7]
CY_quota['Measure'] = 'M1'
CY_quota['Report_Date'] = report_date


CY_achievement = pd.melt(output, id_vars = ['EmployeeID'], value_vars=achievement_col, var_name='Category', value_name='Achievement')
CY_achievement['FiscalYear'] = CY_achievement['Category'].str[:4]
CY_achievement['Period'] = CY_achievement['Category'].str[5:7]

CY_attainment = pd.melt(output, id_vars = ['EmployeeID'], value_vars=attainment_col, var_name='Category', value_name='Attainment')
CY_attainment['FiscalYear'] = CY_attainment['Category'].str[:4]
CY_attainment['Period'] = CY_attainment['Category'].str[5:7]

CY = pd.merge(CY_quota[['Report_Date', 'Name','EmployeeID','FiscalYear','Period','Measure','Quota']],
              CY_achievement[['EmployeeID','Achievement','FiscalYear','Period',]],
                   how='left', on=['EmployeeID', 'FiscalYear','Period'])

CY = pd.merge(CY, CY_attainment[['EmployeeID','Attainment','FiscalYear', 'Period']], how='left', on=['EmployeeID', 'FiscalYear','Period'])

CQ_col = ['EmployeeID', 'CQ_IncrementBooking', 'CQ_AdvStage', 'CQ_ProjectedAchievement', 'CQ_Projected_Attn', 'CQ_YtD_Achievement']
CQ = output[CQ_col].copy()
CQ['Period'] = 'CQ'
CY = pd.merge(CY, CQ, how='left', on=['EmployeeID', 'Period'])

# -------------------------------#
#      M2 Quota & Achievement
# -------------------------------#

prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Anaplan_Performance', skiprows=3, header=0, usecols = "AA:AE")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

M2_output = pd.read_excel(M2_target, sheet_name='Sheet 1', skiprows=4, usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

M2_output['2021_CQ_QtD_Achievement'] = 0
M2_output['2021_CQ_Quota'] = 0
M2_output['2021_CQ_Attn'] = 0


M2_output['EmployeeID'] = M2_output['EmployeeID'].astype('str')
M2_output['CQ_YtD_Achievement'] = M2_output['2021_Q1_Actual'] + M2_output['2021_Q2_Actual'] + M2_output['2021_CQ_QtD_Achievement']

M2_quota_col = ['2021_Q1_Quota', '2021_Q2_Quota', '2021_CQ_Quota']
M2_achievement_col = ['2021_Q1_Actual', '2021_Q2_Actual', '2021_CQ_QtD_Achievement']
M2_attainment_col = ['2021_Q1_Attn', '2021_Q2_Attn', '2021_CQ_Attn']

M2_CY_quota = pd.melt(M2_output, id_vars = ['Name', 'EmployeeID'], value_vars=M2_quota_col, var_name='Category', value_name='Quota').reindex()
M2_CY_quota['FiscalYear'] = M2_CY_quota['Category'].str[:4]
M2_CY_quota['Period'] = M2_CY_quota['Category'].str[5:7]
M2_CY_quota['Measure'] = 'M2'
M2_CY_quota['Report_Date'] = report_date


M2_CY_achievement = pd.melt(M2_output, id_vars = ['EmployeeID'], value_vars=M2_achievement_col, var_name='Category', value_name='Achievement')
M2_CY_achievement['FiscalYear'] = M2_CY_achievement['Category'].str[:4]
M2_CY_achievement['Period'] = M2_CY_achievement['Category'].str[5:7]

M2_CY_attainment = pd.melt(M2_output, id_vars = ['EmployeeID'], value_vars=M2_attainment_col, var_name='Category', value_name='Attainment')
M2_CY_attainment['FiscalYear'] = M2_CY_attainment['Category'].str[:4]
M2_CY_attainment['Period'] = M2_CY_attainment['Category'].str[5:7]

M2_CY = pd.merge(M2_CY_quota[['Name','EmployeeID','FiscalYear','Period','Quota']],
                 M2_CY_achievement[['EmployeeID','Achievement','FiscalYear','Period',]],
                 how='left', on=['EmployeeID', 'FiscalYear','Period'])

M2_CY = pd.merge(M2_CY, M2_CY_attainment[['EmployeeID','Attainment','FiscalYear', 'Period']], how='left', on=['EmployeeID', 'FiscalYear','Period'])
M2_CY['Measure'] = 'M2'
M2_CY['Report_Date'] = report_date


CQ_col = ['EmployeeID', 'CQ_YtD_Achievement']
CQ = M2_output[CQ_col].copy()
CQ['Period'] = 'CQ'

M2_CY = pd.merge(M2_CY, CQ, how='left', on=['EmployeeID','Period'])

CY = CY.append(M2_CY, sort=False)


CY.loc[CY.Quota==0,'Attainment'] = None

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
CY.to_sql('StackRank', con=conn_str_local, if_exists='replace', schema="dbo", index=False)


server = 'PS-SQL-Dev02'
database = 'SalesOps_DM'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
CY.to_sql('StackRank', con=conn_str, if_exists='replace', schema="dbo", index=False)


print('I am done')


