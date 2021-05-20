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
from pyasn1.compat.octets import null


# Read FY19 & FY20 from Anaplan Performance file */
target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 - 07.25.2020.xlsx'
supplement = "Supplement.xlsx"

prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Anaplan_Performance', skiprows=3, header=0, usecols = "I:M")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

output = pd.read_excel(target, sheet_name='Sheet 1', skiprows=4, usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

output['EmployeeID'] = output['EmployeeID'].astype('str')
quota_col = ['2019_Q1_Quota', '2019_Q2_Quota', '2019_Q3_Quota', '2019_Q4_Quota', '2019_FY_Quota',
             '2020_Q1_Quota', '2020_Q2_Quota', '2020_Q3_Quota', '2020_Q4_Quota', '2020_FY_Quota']

achievement_col = ['2019_Q1_Actual', '2019_Q2_Actual', '2019_Q3_Actual', '2019_Q4_Actual', '2019_FY_Actual',
                  '2020_Q1_Actual', '2020_Q2_Actual', '2020_Q3_Actual', '2020_Q4_Actual', '2020_FY_Actual']

attainment_col = ['2019_Q1_Attn', '2019_Q2_Attn', '2019_Q3_Attn', '2019_Q4_Attn', '2019_FY_Attn',
                  '2020_Q1_Attn', '2020_Q2_Attn', '2020_Q3_Attn', '2020_Q4_Attn', '2020_FY_Attn']


history_quota = pd.melt(output, id_vars = ['Name', 'EmployeeID'], value_vars=quota_col, var_name='Category', value_name='Quota')
history_quota['FiscalYear'] = history_quota['Category'].str[:4]
history_quota['Period'] = history_quota['Category'].str[5:7]


history_achievement = pd.melt(output, id_vars = ['EmployeeID'], value_vars=achievement_col, var_name='Category', value_name='Achievement')
history_achievement['FiscalYear'] = history_achievement['Category'].str[:4]
history_achievement['Period'] = history_achievement['Category'].str[5:7]

history_attainment = pd.melt(output, id_vars = ['EmployeeID'], value_vars=attainment_col, var_name='Category', value_name='Attainment')
history_attainment['FiscalYear'] = history_attainment['Category'].str[:4]
history_attainment['Period'] = history_attainment['Category'].str[5:7]


history = pd.merge(history_quota[['Name','EmployeeID','FiscalYear','Period','Quota']],
                   history_achievement[['EmployeeID','Achievement','FiscalYear', 'Period']],
                   how='left', on=['EmployeeID', 'FiscalYear','Period'])

history = pd.merge(history,
                   history_attainment[['EmployeeID','Attainment','FiscalYear', 'Period']],
                   how='left', on=['EmployeeID', 'FiscalYear','Period'])



# Read FY17 & FY18 from Anaplan Performance file */
#target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 Annual - 07.25.2020.xlsx'
target = 'G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\DISPLAY_ QoQ Historical Performance M1 Annual - 08.12.2020.xlsx'
supplement = "Supplement.xlsx"

prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Anaplan_Performance', skiprows=3, header=0, usecols = "A:E")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

output = pd.read_excel(target, sheet_name='Sheet 1', skiprows=4, usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

output['EmployeeID'] = output['EmployeeID'].astype('str')
attainment_col = ['2017_FY_Attn', '2018_FY_Attn']

history_attainment = pd.melt(output, id_vars = ['Name','EmployeeID'], value_vars=attainment_col, var_name='Category', value_name='Attainment').reindex()
history_attainment['FiscalYear'] = history_attainment['Category'].str[:4]
history_attainment['Period'] = history_attainment['Category'].str[5:7]


history = history.append(history_attainment[['Name','EmployeeID','FiscalYear','Period','Attainment']], sort=False)
history['Measure'] = 'M1'

history.loc[(history.FiscalYear.astype('int')>= 2019) & ((history.Quota==0) | history.Quota.isna()), 'Attainment'] = None
history.loc[((history.FiscalYear=='2017') | (history.FiscalYear=='2018')) & (history.Attainment==0), 'Attainment'] = None

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 


#server = 'PS-SQL-Dev02'
#database = 'SalesOps_DM'
#conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 

history.to_sql('StackRank_History', con=conn_str_local, if_exists='replace', schema="dbo", index=False)


print('I am done')




