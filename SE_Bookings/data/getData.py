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
    
    #target = "FY2019 Quota Master - Local 01312019.xlsx"
    target = "FY2020 Quota Master - PRELIM Local.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='QuotaMaster', skiprows=3, header=0, usecols="G:K")
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
    output['Year'] = 'FY 2020'
    # the Year information is from the spreadsheet file name
    
    return output


#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_anaplan_quota (refresh=1):
    
    print ("Reading anaplan quota file") 
    
    #target = "FY2019 Quota Master - Local 01312019.xlsx"
    #target = "Employee Coverage and Quota Report 02.14.2019.xlsx"
    target = "Employee and New Hire Coverage and Quota Report 02.19.2019.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='AnaplanMaster', skiprows=3, header=0, usecols="A,E:K")
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
      
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Sheet 1', skiprows=3, skipfooter=1, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
#   
#     update_type = ['Plan_Effective_Date','Plan_Change_Date','Termination_Plan_End_Date']
#     for i in update_type:
#         output[i] = pd.to_datetime(output[i], format="%Y-%m-%d",errors='coerce')
#   
    output['Year'] = 'FY 2020'
    output['HC_Status'] = output['HC_Status'].map({False:'Onboard',True:'TBH'})
    
    #-----Derive Resource_Group from Headcount_Group ------------------------------------------
    Resource_Headcount_Group = {
                            'DM_group' : ["Sales Mgmt", "Sales Management" "Sales Mgmt QBH", "Field Sales"], 
                            'AE_group' : ["Sales QBH", "Sales-QBH"],
                            'SE_Mgr_group' : ["SE Mgmt", "SE Management"],
                            'SE_group' : ["SE", "System Engineer"],
                            'SE_Specialist_group' : ["SE Specialist"]
                            }
    
    Resource_Group_label = {'DM_group' : 'DM',
                            'AE_group' : 'Sales QBH',
                            'SE_Mgr_group' : 'SEM',
                            'SE_group' : 'SE',
                            'SE_Specialist_group' : 'SE Specialist'}

    for i in list(Resource_Group_label.keys()):
        output.loc[(output.Headcount_Group.isin(Resource_Headcount_Group[i]), 'Resource_Group')] = Resource_Group_label[i]
    
    #------Read the override values ------------------------------------------------------------------------ 
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Mgmt_Roster_nonDefault', skiprows=3, header=0, usecols="A:B")
    output = pd.merge(output, prep_file, how='left', left_on = 'Name', right_on = 'Name')
    output.loc[(~output.Override_Resource_Group.isna()),'Resource_Group'] = output.Override_Resource_Group
    
    output.drop('Override_Resource_Group', axis=1, inplace=True)
    
    # the Year information is from the spreadsheet file name
    
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

#===============================================================================
# Read SFDC Opportunity with Split Data
#===============================================================================

def get_SFDC_Oppt_Split (refresh = 1):
    print("Reading opportunity with Split data from SFDC")
    server = 'PS-SQL-PROD01'
    database = 'PureDW_SFDC_staging'
    target = 'PureDW_SFDC_staging_Opportunity_wSplit'
    
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
# from The Quota Master File - Reference - Territory Quotas sheet
#=======================================================================
def get_TerritoryID_Master(refresh = 1):
   
    #target = "FY2019 Quota Master - Local Research.xlsx"
    target = "FY2020 Quota Master - PRELIM Local.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='TerritoryQuota', skiprows=3, header=0, usecols = "I:M")
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
      
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Reference - Territory Quotas', skiprows=3, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
    Territory_Hierarchy = {0 : 'Hierarchy', 
                           1 : 'Theater',
                           2 : 'Super-Region',
                           3 : 'Region',
                           4 : 'District',
                           5 : 'Territory'}
    
    output = output[output.Level.isin(Territory_Hierarchy.values())]
    output = output.groupby('Territory_ID').tail(1)
    
    temp = output['Territory_ID'].str.split('_', expand=True)
    output = pd.merge(output, temp, how='left', left_index=True, right_index=True)
    
    # Using the Territory ID convention, find the territory hierarchy descriptions
    for i in Territory_Hierarchy.keys():
        temp = output[output.Level == Territory_Hierarchy[i]][['Territory_ID','Territory_Description']]
        output['temp_key'] = output[0]
        for j in range(1,i+1):
            output['temp_key'] = output['temp_key'].str.cat(output[j],sep='_')
        output = pd.merge(output, temp, how = 'left', left_on=output['temp_key'], right_on='Territory_ID')
        output.drop(['Territory_ID','Territory_ID_y'], axis=1, inplace=True)
        output.rename(columns={'Territory_Description_x':'Territory_Description',
                               'Territory_Description_y': Territory_Hierarchy[i], 
                               'Territory_ID_x':'Territory_ID'}, inplace=True)
        
    output.drop(Territory_Hierarchy.keys(), axis=1, inplace=True)
    output.drop(['temp_key'], axis=1, inplace=True)

    
    '''
    temp_pd = pd.pivot_table(output, index=["Territory_ID"], values=["Level"], aggfunc='count').rename(columns={'Level':'Rec_Count'})
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
    
    temp = pd.DataFrame(columns=['Date','Period'])    
    for i in range(0, len(output)):
        temptemp = pd.DataFrame()
        temptemp['Date'] = pd.date_range(output['startDate'][i], output['EndDate'][i])
        temptemp['Period'] = output['FullyQualifiedLabel'][i]
        temp = temp.append(temptemp)
    
    temp['Quarter'] = temp.Period.str[1:3]
    temp['Year'] = temp.Period.str[4:]
    temp.to_csv(cfg.source_data_folder + target +'.txt', sep='|', index=False)

    return (temp)

