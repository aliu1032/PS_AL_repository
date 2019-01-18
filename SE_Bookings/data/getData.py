'''
Created on Jan 11, 2019

@author: aliu

'''
import pandas as pd
import project_config as cfg
import pyodbc

#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_quota (refresh=1):
    
    print ("Reading territory quota file") 
    
    target = "FY2019 Quota Master - Local Research.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='QuotaMaster', skiprows=3, header=0)
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
      
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Individual Quota Master', skiprows=3, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
#   
#     update_type = ['Plan_Effective_Date','Plan_Change_Date','Termination_Plan_End_Date']
#     for i in update_type:
#         output[i] = pd.to_datetime(output[i], format="%Y-%m-%d",errors='coerce')
#   

    return output

#===============================================================================
# Read SFDC Opportunity Data
#===============================================================================

def get_SFDC_Oppt (refresh = 1):
    print("Reading opportunity data from SFDC")
    server = 'PS-SQL-PROD01'
    database = 'PureDW_SFDC_staging'
    target = 'PureDW_SFDC_staging_Opportunity'
    
    if refresh:
        cnxn = pyodbc.connect('DSN=PS-SQL-PROD01; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
        f = open(cfg.sql_folder + target + '.sql')
        tsql = f.read()
        f.close()
        
        output = pd.read_sql(tsql,cnxn)
        output.to_csv(cfg.source_data_folder + target +'.txt', sep='|', index=False)
        
    else:
        target = target +'.txt'
        output = pd.read_csv(cfg.source_data_folder)
        
    return output

#=======================================================================
# Read the Territory ID master
#=======================================================================
def get_TerritoryID_Master(refresh = 1, level='Territory'):
   
    target = "FY2019 Quota Master - Local Research.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='TerritoryQuota', skiprows=3, header=0)
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
      
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Reference - Territory Quotas', skiprows=3, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)

    output = output[output.Level==level]
    output = output.groupby('Territory_ID').tail(1)  # pick the last record of any duplicates
    
    '''
    temp_pd = pd.pivot_table(output, index=["Territory_ID", "Level"], values=["Theater"], aggfunc='count', margins = 'True').rename(columns={'Theater':'Rec_Count'})
    temp = output.groupby('Territory_ID').tail(1) #select the tail of each group
    '''
    
    return(output)


#===============================================================================
# Read the date period information
#===============================================================================
def get_Period_map(refresh = 1):
    
    server = 'PS-SQL-PROD01'
    database = 'PureDW_SFDC_staging'
    target = 'PureDW_SFDC_staging_Period'

    cnxn = pyodbc.connect('DSN=PS-SQL-PROD01; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    f = open(cfg.sql_folder + target + '.sql')
    tsql = f.read()
    f.close()

    output = pd.read_sql(tsql,cnxn)
    
    temp = pd.DataFrame(columns=['Date','Quarter'])    
    for i in range(0, len(output)):
        print(i)
        temptemp = pd.DataFrame()
        temptemp['Date'] = pd.date_range(output['startDate'][i], output['EndDate'][i])
        temptemp['Quarter'] = output['FullyQualifiedLabel'][i]
        temp = temp.append(temptemp)
    
    temp.to_csv(cfg.source_data_folder + target +'.txt', sep='|', index=False)

    return (temp)

