'''
Created on Jan 11, 2019

@author: aliu

'''
import pandas as pd
import project_config as cfg
import pyodbc


#=======================================================================
# Read the Territory ID master
# from The Quota Master File - Reference - Territory Quotas sheet
#=======================================================================
def get_TerritoryID_Master(refresh = 1):
   
    #target = "FY2019 Quota Master - Local Research.xlsx"
    #target = "FY2020 Quota Master - PRELIM Local.xlsx"
    target = "FY2020 Quota Master - PRELIM 02222019.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='TerritoryID_Master', skiprows=3, header=0, usecols = "I:M")
    prep_file = prep_file[prep_file.Include == 1.0]
    read_cols = ",".join(list(prep_file.Column))
    new_names = list(prep_file.NewName)
    data_type = dict(zip(prep_file.NewName, prep_file.DataType))
      
    output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Reference - Territory Quotas', skiprows=3, usecols=read_cols, names=new_names,
                           dtypes=data_type, keep_default_na=True)
    
    ''' check for duplicate Territory IDs
    temp_pd = pd.pivot_table(output, index=["Territory_ID"], values=["Level"], aggfunc='count').rename(columns={'Level':'Rec_Count'})
    temp = output.groupby('Territory_ID').tail(1) #select the tail of each group
    '''

    Territory_Hierarchy = {0 : 'Hierarchy', 
                           1 : 'Theater',
                           2 : 'Super-Region',
                           3 : 'Region',
                           4 : 'District',
                           5 : 'Territory'}
    
    # in case there is duplicate, take the last of the duplicate
    output = output[output.Level.isin(Territory_Hierarchy.values())]
    output = output.groupby('Territory_ID').tail(1)

    # Using the Territory ID convention, find the territory hierarchy descriptions
    temp = output['Territory_ID'].str.split('_', expand=True)
    output = pd.merge(output, temp, how='left', left_index=True, right_index=True)
    
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

    # Clean the Hierarchy & Theater values for report
    output.loc[(output.Hierarchy == 'Account Quotas') & (output.Theater == 'GIobals Account Quotas'), 'Super-Region'] = 'Globals Account program activity'
    output.loc[(output.Hierarchy == 'Account Quotas') & (output.Theater == 'GIobals Account Quotas'), 'Theater'] = 'Globals Account Quotas'
    
    output.loc[(output.Hierarchy == 'Account Quotas') & (output.Theater == 'Enterprise account activity, Globally'), 'Theater'] = 'Enterprise account'
    output.loc[(output.Hierarchy == 'Account Quotas') & (output.Theater == 'Global Systems Integrator (GSI) program SELL TO and SELL-THROUGH/WITH activity, Globally (Accenture & ATOS & CapGemini & CGI & Cognizant-Trizetto & Deloitte & DXC & Fujitsu & HCL & IBM Global Services & Infosys & PricewaterhouseCoopers & Sopra & TCS & Tech Mahindra & Tsystems & Wipro)'), 'Theater'] \
                                                                                                                = 'Global Systems Integrator'
    output.loc[(output.Hierarchy == 'Account Quotas') & (output.Theater == 'G2K Target Account activity, Globally (Alphabet Inc. & American International Group & Apple Inc. & ATOS IDM & Automatic Data Processing Inc. & Aviva PLC & Bank of America Corporation & BT Group PLC & Cisco Systems Inc. & Credit Agricole SA & CVS Health Corporation & Deutsche Telecom AG & Fidelity National Information Services, Inc. & Fiserv, Inc. & FMR LLC & Ford Motor Company & General Motors Company & Honeywell International Inc. & Intel Corporation & Johnson & Johnson & MetLife Inc. & Nationwide Mutual Insurance Company & PayPal Holdings Inc. & PepsiCo, Inc. & The PNC Financial Services Group Inc & Prudential Financial, Inc. & Royal Bank of Canada & Salesforce.com, Inc. & Siemens AG & StateFarm Insurance & Target Corporation & Toyota Motor Corporation & UnitedHealth Group & United Parcel Service Inc. & U.S. Bancorp & Visa Inc. & Volkswagen Aktiengesellschaft & Wal-Mart Stores, Inc. & Wells Fargo & Company & Zurich Insurance Group)'), \
                                                                                                                'Theater'] \
                                                                                                                = 'G2K Target Accounts'
    output.loc[(output.Hierarchy == 'Verticals') & (output.Theater == 'Healthcare Vertical (Providers, Life Sciences & Healthcare Technology) activity, Globally'), 'Theater'] \
                                                                                                                = 'Healthcare Vertical'
    output.loc[(output.Theater == 'National Partner program activity in AMER (CDW & Dimension Data & ePlus & Forsythe & Insight Investments & Presidio & SHI & Sirius Solutions & Worldwide Technology) and in EMEA ('),\
                                                                                                                'Hierarchy'] \
                                                                                                                = 'National Partner'
    output.loc[(output.Theater == 'National Partner program activity in AMER (CDW & Dimension Data & ePlus & Forsythe & Insight Investments & Presidio & SHI & Sirius Solutions & Worldwide Technology) and in EMEA ('),\
                                                                                                                'Theater'] \
                                                                                                                = 'National Partner'
    
    output.loc[(output.Hierarchy == 'Pro Services') & (output.Level != 'Hierarchy'), 'Theater'] \
                = output.loc[(output.Hierarchy == 'Pro Services') & (output.Level != 'Hierarchy')].Theater.apply(lambda x : x.replace(' Super-Region',''))
                
    #TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy'), 'Theater'] \
    #            = TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy')].Theater.str.extract('^(.*?)\ Super-Region')                                                                                             
    #TerritoryID_Master[TerritoryID_Master.Theater.str.match('National Partner*', na=False)]
    
    a = output[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002']['Territory_Description']
    b = a.str.replace('\n', " ") 
    output.loc[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002','Territory_Description'] = b   


    # append the SFDC-sub-division mapped to Territory_ID
    supplment = "TerritoryID_to_SFDC_SubDivision_Mapping.xlsx"
    
    xls = pd.ExcelFile(cfg.sup_folder + supplment, on_demand = True)
    sheets = xls.sheet_names
    
    SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name=sheets[0], header=0, usecols = "A:B", names=['Sub_Division', 'Territory_ID'])
    #SFDC_sub_division['Source'] = sheets[0]
    for i in sheets[1:]:
        temp = pd.read_excel(cfg.sup_folder + supplment, sheet_name=i, header=0, usecols = "A:B",names=['Sub_Division', 'Territory_ID'])
        #temp['Source'] = i
        SFDC_sub_division= SFDC_sub_division.append(temp)

    SFDC_sub_division = SFDC_sub_division[~SFDC_sub_division.Territory_ID.isnull()]
        
    output = pd.merge(output, SFDC_sub_division, how='left', left_on='Territory_ID', right_on='Territory_ID')       
    output.to_csv(cfg.output_folder+'TerritoryID_Master.txt', sep="|", index=False)      
    
    return(output)
#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_anaplan_quota (refresh=1):
    
    print ("Reading anaplan quota file") 
    
    #target = "FY2019 Quota Master - Local 01312019.xlsx"
    #target = "Employee Coverage and Quota Report 02.14.2019.xlsx"
    target = "Employee and New Hire Coverage and Quota Report 02.27.2019.xlsx"
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='AnaplanMaster', skiprows=3, header=0, usecols="H,K:M")
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
    #output['HC_Status'] = output['HC_Status'].map({False:'Onboard',True:'TBH'})
    output['HC_Status'] = output.Employee_ID.str.match("SR-*").map({False:'Onboard',True:'TBH'})
    
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


''' Retired function
#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_quota (refresh=1):
    
    print ("Reading territory quota file") 
    
    #target = "FY2019 Quota Master - Local 01312019.xlsx"
    #target = "FY2020 Quota Master - PRELIM Local.xlsx"
    target = "FY2020 Quota Master - PRELIM 02222019.xlsx"
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

'''