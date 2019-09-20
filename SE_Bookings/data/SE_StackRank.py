'''
Created on Jun 13, 2019

@author: aliu

'''
import pandas as pd
import project_config as cfg
import pyodbc
import datetime

def read_FY19():
    
    target = 'FY19 Webi StackRank 0215 Final.xlsx'
    supplement = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='StackRank', skiprows=3, header=0, usecols = "A:E")
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Main StackRank', skiprows=5, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
    output.EmployeeID = output.EmployeeID.astype('str')
    output['Year'] = output.Period.str[-4:]
    Month_Qtr = { 1 :'Q1', 2 :'Q1', 3 :'Q1',
                  4 :'Q2', 5 :'Q2', 6 :'Q2',
                  7 :'Q3', 8 :'Q3', 9 :'Q3',
                  10:'Q4', 11:'Q4', 12:'Q4'
                 }
    
    for i in list(Month_Qtr.keys()):
        output.loc[(output.Month == i), 'Quarter'] = Month_Qtr[i]
    
    return (output)
         
def read_FY20():

    target = 'FY20 Stack Rank Achievement Only - M03 - 19.05.24.xlsx'
    supplement = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='StackRank', skiprows=3, header=0, usecols = "J:N")
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Main StackRank', skiprows=5, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
    Month_Qtr = { 1 :'Q1', 2 :'Q1', 3 :'Q1',
                  4 :'Q2', 5 :'Q2', 6 :'Q2',
                  7 :'Q3', 8 :'Q3', 9 :'Q3',
                  10:'Q4', 11:'Q4', 12:'Q4'
                 }
    
    for i in list(Month_Qtr.keys()):
        output.loc[(output.Month == i), 'Quarter'] = Month_Qtr[i]
        
    output.EmployeeID = output.EmployeeID.astype('str')
    output['Year'] = output.Period.str[-4:]
    
    server = 'ALIU-X1'
    database = 'ALIU_DB1'
    table = 'SE_Org_Quota'
    cnxn = pyodbc.connect('DSN=ALIU-X1; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    SE_FY20Quota = pd.read_sql('select EmployeeID, Year, Quarter, Quota Quarterly_Quota from ' + table, cnxn)
     
    output = pd.merge(output, SE_FY20Quota[['EmployeeID','Quarter','Quarterly_Quota']], how='inner', on=['EmployeeID','Quarter'])

    return(output)



#--------------------------------#
FY19 = read_FY19()
FY20 = read_FY20()
temp = pd.concat([FY19,FY20], sort=False).sort_values(['EmployeeID','Year','Month'])

temp[temp.Full_Name == 'Jeffrey LaCamera']
temp[temp.Full_Name == 'Jonathan May']
temp[temp.Full_Name.str.contains('Chudzik')]
temp[temp.Full_Name.str.contains('Kalaf')]
