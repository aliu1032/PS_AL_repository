'''
Created on Jan 11, 2019

@author: aliu
   
'''
import pandas as pd
import project_config as cfg
import pyodbc
import datetime
from builtins import str

#=======================================================================
# Read the Territory ID master
# from The Quota Master File - Reference - Territory Quotas sheet
#=======================================================================
def get_TerritoryID_Master(refresh = 1):

    if (refresh == 1):
        print ('Refreshing TerritoryID_Master', datetime.datetime.now().strftime("%Y-%m-%d %I:%M:%S %p"))
        
        #target = "FY2019 Quota Master - Local Research.xlsx"
        #target = "FY2020 Quota Master - PRELIM Local.xlsx"
        #target = "FY2020 Quota Master - PRELIM 03192019.xlsx"
        #target = "Export Org Hierarchy 04.11.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 05.01.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 06.04.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 07.08.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 08.05.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 09.04.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 10.08.2019.xls"
        #target = "Export Org Coverage and Quota SE Ops 11.05.2019.xls"
        ####target = "Export Org Coverage and Quota SE Ops 12.06.2019.xls" ## last FY20 file
        #target = 'SE Territory Quota Report.xls'
        #target = 'Coverage and Quota Report by Month - 03.18.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 03.31.2020.xlsx'
        target = 'Coverage and Quota Report by Month - 04.15.2020.xlsx'

        supplment = "Supplement.xlsx"
             
        prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='TerritoryID_Master', skiprows=3, header=0, usecols = "I:M")
        prep_file = prep_file[prep_file.Include == 1.0]
        read_cols = ",".join(list(prep_file.Column))
        new_names = list(prep_file.NewName)
        data_type = dict(zip(prep_file.NewName, prep_file.DataType))
          
        output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Sheet 1', skiprows=1, usecols=read_cols, names=new_names,
                               dtypes=data_type, keep_default_na=True)        
            
        output['Short_Description'].replace('\n', "", regex=True, inplace=True)
        output.loc[output.Territory_ID=='OL_GLO_EMA_EMA_EG1','Short_Description'] = 'EMEA Globals (team 1)'
        output.loc[output.Territory_ID=='OL_GLO_EMA_EMA_EG2','Short_Description'] = 'EMEA Globals (team 2)'
        output.loc[output.Territory_ID=='OL_GLO_EMA_EMA','Short_Description'] = 'EMEA Globals'  
        #a = output[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002']['Territory_Description']
        #b = a.str.replace('\n', " ") 
        #output.loc[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002','Territory_Description'] = b   
        
        Territory_Hierarchy = {0 : 'Hierarchy', 
                               1 : 'Theater',
                               2 : 'Super-Region',
                               3 : 'Region',
                               4 : 'District',
                               5 : 'Territory'}
    
        # check for duplicate Territory IDs
        #temp_pd = pd.pivot_table(output, index=["Territory_ID"], values=["Level"], aggfunc='count').rename(columns={'Level':'Rec_Count'})
        #temp = output.groupby('Territory_ID').tail(1) #select the tail of each group
        
        # in case there is duplicate, take the last of the duplicate
        output = output[output.Level.isin(Territory_Hierarchy.values())]
        output = output.groupby('Territory_ID').tail(1)
        
        # Using the Territory ID convention, find the territory hierarchy descriptions
        temp = output['Territory_ID'].str.split('_', expand=True)
        output = pd.merge(output, temp, how='left', left_index=True, right_index=True)
        
        for i in Territory_Hierarchy.keys():
            temp = output[output.Level == Territory_Hierarchy[i]][['Territory_ID','Short_Description']]
            output['temp_key'] = output[0]
            for j in range(1,i+1):
                output['temp_key'] = output['temp_key'].str.cat(output[j],sep='_')
            output = pd.merge(output, temp, how = 'left', left_on=output['temp_key'], right_on='Territory_ID')
            output.drop(['Territory_ID','Territory_ID_y'], axis=1, inplace=True)
            output.rename(columns={'Short_Description_x':'Short_Description',
                                   'Short_Description_y': Territory_Hierarchy[i], 
                                   'Territory_ID_x':'Territory_ID'}, inplace=True)
            
        output.drop(Territory_Hierarchy.keys(), axis=1, inplace=True)
        output.drop(['temp_key'], axis=1, inplace=True)
   
        output.rename(columns = {'Super-Region':'Super_Region'}, inplace=True)
                    
        supplment = "TerritoryID_to_SFDC_SubDivision_Mapping.xlsx"
        
        xls = pd.ExcelFile(cfg.sup_folder + supplment, on_demand = True)
        sheets = xls.sheet_names
        
        #FY20
        #SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name=sheets[1], header=0, usecols = "F:I", names=['SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division', 'Territory_ID'])

        #FY21
        SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Anaplan-SFDC Map FY21', header=0, skiprows=1, usecols = "B,E:G", names=['Territory_ID','SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division'])

        '''
        for i in sheets[:1]:  # use the manual patched sheet
            temp = pd.read_excel(cfg.sup_folder + supplment, sheet_name=i, header=0, usecols = "J:M",names=['SFDC_Theater','Division','Sub_Division', 'Territory_ID'])
            #temp['Source'] = i
            SFDC_sub_division= SFDC_sub_division.append(temp, sort=False)
        '''
        SFDC_sub_division = SFDC_sub_division[~SFDC_sub_division.Territory_ID.isnull()]
            
        ID_Master = pd.merge(output, SFDC_sub_division, how='left', left_on='Territory_ID', right_on='Territory_ID')       
        #ID_Master.loc[output.Theater=='Global Systems Integrator','Sub_Division'] = 'GSI'
        #ID_Master.to_csv(cfg.output_folder+'TerritoryID_Master.txt', sep="|", index=False)     

        
        ## calculate the 1H, 2H and Annual quota
        ID_Master['1H_M1_Quota'] = ID_Master['Q1_M1_Quota'] + ID_Master['Q2_M1_Quota']
        ID_Master['2H_M1_Quota'] = ID_Master['Q3_M1_Quota'] + ID_Master['Q4_M1_Quota']
        ID_Master['FY_M1_Quota'] = ID_Master['Q1_M1_Quota'] + ID_Master['Q2_M1_Quota'] + ID_Master['Q3_M1_Quota'] + ID_Master['Q4_M1_Quota']

        ## calculate the 1H, 2H and Annual quota
        ID_Master['1H_FB_Quota'] = ID_Master['Q1_FB_Quota'] + ID_Master['Q2_FB_Quota']
        ID_Master['2H_FB_Quota'] = ID_Master['Q3_FB_Quota'] + ID_Master['Q4_FB_Quota']
        ID_Master['FY_FB_Quota'] = ID_Master['Q1_FB_Quota'] + ID_Master['Q2_FB_Quota'] + ID_Master['Q3_FB_Quota'] + ID_Master['Q4_FB_Quota']

        Quota_assignment_col = ['Q1_M1_Quota','Q2_M1_Quota','Q3_M1_Quota', 'Q4_M1_Quota', '1H_M1_Quota','2H_M1_Quota','FY_M1_Quota',\
                                'Q1_FB_Quota','Q2_FB_Quota','Q3_FB_Quota', 'Q4_FB_Quota', '1H_FB_Quota','2H_FB_Quota','FY_FB_Quota']
               
        Territory_Quota = pd.melt(ID_Master, id_vars = ['Hierarchy','Theater','Super_Region','Region','District', 'Territory','Territory_ID','SFDC_Theater','SFDC_Division','SFDC_Sub_Division','Level'],
                       value_vars=Quota_assignment_col, var_name='Period',value_name='Quota')
        Territory_Quota['Measure'] = Territory_Quota.Period.str[3:]
        Territory_Quota['Period'] = Territory_Quota.Period.str[0:2]
        Territory_Quota['Year'] = 'FY21'
       
        ## writing to the database
        # import pyodbc
        from sqlalchemy import create_engine
        from sqlalchemy import types as sqlalchemy_types
    
        '''
        import urllib
        params = urllib.parse.quote_plus(r'DRIVER={ODBC Driver 13 for SQL Server};'
                                         r'SERVER=ALIU-X1;'
                                         r'DATABASE=ALIU_DB1;'
                                         r'Trusted_Connection=yes')
        conn_str = 'mssql+pyodbc:///?={}'.format(params)
        engine = create_engine(sqlcon)
        '''
        
        server = 'ALIU-X1'
        database = 'ALIU_DB1'
        conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work
        #sqlcon = create_engine("mssql+pyodbc://user:pwd@ALIU-X1") #work

        supplment = "Supplement.xlsx"        
        to_sql_type = pd.read_excel(cfg.sup_folder + supplment, sheet_name = 'Output_DataTypes', header=0, usecols= "B:D")
        TerritoryID_Master_type = to_sql_type[to_sql_type.DB_TableName == 'TerritoryID_Master']

        data_type={}
        for i in range(0,len(TerritoryID_Master_type.Columns)):
            data_type[TerritoryID_Master_type.iloc[i].Columns] = eval(TerritoryID_Master_type.iloc[i].DataType)
        
        a = list(set(ID_Master.columns) - set(Quota_assignment_col))
        ID_Master[a].to_sql('TerritoryID_Master_FY21', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        #[ID_Master.Hierarchy != 'Other Overlay']
        #ID_Master.to_csv(cfg.output_folder+'TerritoryID_Master_FY21.txt', sep="|", index=False)
        
        Territory_Quota_type = to_sql_type[to_sql_type.DB_TableName == 'Territory_Quota']
        data_type = {}
        for i in range(0, len(Territory_Quota_type.Columns)):
            data_type[Territory_Quota_type.Columns.iloc[i]] = eval(Territory_Quota_type.DataType.iloc[i])
        
        #Territory_Quota.to_csv(cfg.output_folder+'Territory_Quota_FY21.txt', sep="|", index=False)
        Territory_Quota[Territory_Quota.Hierarchy != 'Other Overlay'].to_sql('Territory_Quota_FY21', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        
    else: # not refreshing
        print ('Reading TerritoryID_Master from database')
        
        server = 'ALIU-X1'
        database = 'ALIU_DB1'
        table = 'TerritoryID_Master'
        
        cnxn = pyodbc.connect('DSN=ALIU-X1; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
        ID_Master = pd.read_sql('select * from ' + table, cnxn)
    
    
    return(ID_Master)

    # Code to refresh the District to Sub-Division mapping
    '''
    # Since there is not a master in SFDC, export from SFDC User an inventory of Theater, Division, Sub-Division & Territory
    # to get a close to master list
    # Territory ID is included to the dump if and only if a Active QBH is assigned to the territory
    server = 'PS-SQL-PROD01'
    database = 'PureDW_SFDC_staging'
    target = 'SFDC_QBH_Territory'
    
    cnxn = pyodbc.connect('DSN=PS-SQL-PROD01; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    f = open(cfg.sql_folder + target + '.sql')
    tsql = f.read()
    f.close()
        
    supplment = pd.read_sql(tsql,cnxn)
    supplment_pivot = pd.pivot_table(supplment, index=['Theater__c','Division','Sub_Division__c','Territory_ID__c'], values = 'Name', aggfunc='count').reset_index()
    supplment_pivot.drop(columns=['Name'], inplace=True)
    
    verify_map = pd.merge(output, supplment_pivot, how = 'left', left_on='Territory_ID', right_on='Territory_ID__c')  
    
    ## Special treatment for Global Systems Integrator since the Territory ID is not load into SFDC User
    verify_map.loc[(output.Theater == 'Global Systems Integrator') & (output.Level=='Territory'), 'Division'] = 'Global System Integrators'
    verify_map.loc[(output.Theater == 'Global Systems Integrator') & (output.Level=='Territory'), 'Sub_Division__c'] = 'GSI'
   
    verify_map = verify_map[['Level', 'Hierarchy', 'Theater', 'Super_Region', 'Region', 'District','Territory_ID','Segment','Type', 'Theater__c','Division', 'Sub_Division__c','Territory_ID__c']]
    
    # export a version for manual data clean up. 
    verify_map.to_csv(cfg.output_folder+'TerritoryID_Master_4_verify_map.txt', sep="|", index=False)
    '''
           
#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_anaplan_quota (refresh=1):
    
    print ("Reading anaplan quota file") 
    
    #target = "FY2019 Quota Master - Local 01312019.xlsx"
    #target = "Employee Coverage and Quota Report 02.14.2019.xlsx"
    #target = "Employee and New Hire Coverage and Quota Report 03.18.2019.xlsx"
    #target = "Export Employee and New Hire Coverage and Quota 04.11.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 05.01.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 05.08.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 06.04.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 07.08.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 08.05.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 09.04.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 10.08.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 11.05.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 12.06.2019.xls"
    #target = "Export Employee and New Hire Coverage and Quota 01.08.2020.xls"
    #target = "Employee Coverage and Quota Report - 02.27.2020.xlsx"
    #target = "Employee Coverage and Quota Report - 03.04.2020.xlsx"
    #target = "Employee Coverage and Quota Report - 03.18.2020.xlsx"
    target = "Employee Coverage and Quota Report - 03.31.2020.xlsx"
   
    supplment = "Supplement.xlsx"
    
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='AnaplanMaster', skiprows=3, header=0, usecols="Q,S:U")
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
    
    #remove the resources who do not have a quota/compensation territory assignment
    output = output[output.Territory_IDs!='No Plan / No Coverage']
    output.loc[output.Territory_IDs.str.contains('OL_GLO_EMA_EMA_EG1', na=False),'M1_District'] = 'EMEA Globals (team 1)'
    output.loc[output.Territory_IDs.str.contains('OL_GLO_EMA_EMA_EG1', na=False),'M1_Region'] = 'EMEA Globals'
    output.loc[output.Territory_IDs.str.contains('OL_GLO_EMA_EMA_EG2', na=False),'M1_District'] = 'EMEA Globals (team 2)'
    output.loc[output.Territory_IDs.str.contains('OL_GLO_EMA_EMA_EG2', na=False),'M1_Region'] = 'EMEA Globals'
    output.loc[output.Territory_IDs.str.contains('OL_GLO_EMA_EMA', na=False),'M1_Region'] = 'EMEA Globals'
  
    #Lookup the missing SFDC ID & email
    '''
    lookup = output[(output.SFDC_UserID.isnull()) & ~(output.Name.str.match('SR-*')) & (output.Name.str.match('^[a-zA-Z]'))][['Name']]    
    lookup_str = '(\'' + lookup['Name'][:1].values[0] + '\','
    for i in range(1, len(lookup)-1):       
        #print(lookup.iloc[i]['Name'])
        lookup_str =  lookup_str + "'" + lookup.iloc[i]['Name'] + "',"
    lookup_str = lookup_str + '\'' + lookup['Name'][-1:].values[0]+ '\')'

    query = 'select Id, email, Name, LastModifiedDate from ' +\
            ' (select Id, email, Name, LastModifiedDate,' +\
            '    Row_Number() Over (Partition by Name order by LastModifiedDate desc) rn ' +\
            '    from [PureDW_SFDC_staging].[dbo].[User]' +\
            '    where Name in ' + lookup_str + ') st' +\
            ' where rn = 1' 
    
    cnxn = pyodbc.connect('DSN=PS-SQL-PROD01; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER='PS-SQL-PROD01', Database='PureDW_SFDC_staging')
    Missing_SFDC_ID = pd.read_sql(query,cnxn)
    
    output = pd.merge(output, Missing_SFDC_ID[['Id','Name']], how='left', left_on='Name', right_on='Name')
    output.loc[output.SFDC_UserID.isnull(),'SFDC_UserID'] = output.loc[output.SFDC_UserID.isnull(),'Id']
    output.drop(columns=['Id'], inplace=True)
    '''
    
    output['Year'] = 'FY21'  ##because to match with SFDC, which the FY is a year 'behind'????
    #output['HC_Status'] = output['HC_Status'].map({False:'Onboard',True:'TBH'})
    #FY21 file has only onboarded employee 
    #output['HC_Status'] = (output.Name.str.match('^\d') | output.Name.str.match('SR-*')).map({False:'Onboard',True:'TBH'})
    
    #-----Derive Resource_Group from Headcount_Group ------------------------------------------
    Resource_Headcount_Group = {
                            'DM_group' : ["Sales Mgmt", "Sales Mgmt QBH"], #"Sales Management" , "Field Sales"
                            'AE_group' : [ "Sales AE", "Overlay AE"],  # adding Sales AE on Jun 17 #"Sales QBH", "Sales-QBH",
                            'SE_Mgr_group' : ["SE Mgmt"], #, "SE Management"
                            'SE_group' : ["SE"], #, "System Engineer"
                            'SE_Specialist_group' : ["SE Specialist IC"]
                            }
    
    Resource_Group_label = {'DM_group' : 'DM',
                            'AE_group' : 'AE',
                            'SE_Mgr_group' : 'SEM',
                            'SE_group' : 'SE',
                            'SE_Specialist_group' : 'SE Specialist'}
    
    for i in list(Resource_Group_label.keys()):
        output.loc[(output.Headcount_Group.isin(Resource_Headcount_Group[i]), 'Resource_Group')] = Resource_Group_label[i]
    
    #------Read the override values ------------------------------------------------------------------------ 
    prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Mgmt_Roster_nonDefault', skiprows=3, header=0, usecols="B,C")
    prep_file = prep_file[~prep_file['EmployeeID'].isna()]
    prep_file['EmployeeID'] = prep_file['EmployeeID'].astype('int').astype('str')
    output.EmployeeID = output.EmployeeID.fillna(0).astype(int).astype(str)
    
    output = pd.merge(output, prep_file, how='left', on = 'EmployeeID')
    output.loc[(~output.Override_Resource_Group.isna()),'Resource_Group'] = output.Override_Resource_Group
    
    output.drop('Override_Resource_Group', axis=1, inplace=True)
    
    output.Manager_EmployeeID = output.Manager_EmployeeID.fillna(0).astype(int).astype(str)
    output.loc[output.Manager_EmployeeID=='0','Manager_EmployeeID'] = ''   
    # the Year information is from the spreadsheet file name
    
    return output




''' Retired function
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
# Read SFDC Opportunity Split for Temp Coverage
#===============================================================================

def get_SFDC_Oppt_Split_Temp_Coverage (refresh = 1):
    print("Reading opportunity with Split data from SFDC")
    server = 'PS-SQL-PROD01'
    database = 'PureDW_SFDC_staging'
    target = 'PureDW_SFDC_staging_Opportunity_Split_4TempCoverage'
    
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
        # Reference SFDC Forecast label. The label is a year off
        #temptemp['Period'] = output.FullyQualifiedLabel[i][:-4] + str((int(output['FullyQualifiedLabel'][i][-4:])+1))
        temp = temp.append(temptemp)
    
    temp['Quarter'] = temp.Period.str[1:3]
    temp['Year'] = temp.Period.str[4:]
    temp.to_csv(cfg.source_data_folder + target +'.txt', sep='|', index=False)

    return (temp)


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


'''
    # Clean the Hierarchy & Theater values for report
    output.loc[output.Theater.str.match("G2K Target Account activity*", na=False), 'Theater'] = "G2K Target Account activity, Globally"
    output.loc[output.Theater.str.match("Global Systems Integrator*", na=False), 'Theater'] = "Global Systems Integrator"
    output.loc[output.Theater.str.match("National Partner program*", na=False), 'Theater'] = "National Partner program"
    output.loc[output.Theater.str.match('GIobals Account Quotas', na=False), 'Theater'] = 'Globals Account Quotas'
    
    output.loc[output['Super-Region'].str.match("G2K Target Account activity, Globally*", na=False),'Super-Region'] = "G2K Target Account activity, Globally" 
    output.loc[output['Super-Region'].str.match("Global Accounts program activity, Globally*", na=False),'Super-Region'] = "Global Accounts program activity, Globally" 
    output.loc[output['Super-Region'].str.startswith("Global Systems Integrator (GSI) program SELL-TO", na=False), 'Super-Region'] = "Global Systems Integrator (GSI) program SELL-TO activity, Globally" 
    output.loc[output['Super-Region'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH", na=False), 'Super-Region'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, Globally" 
    output.loc[output['Super-Region'].str.match("National Partner program activity in AMER*", na=False),'Super-Region'] = "National Partner program activity in AMER" 

    output.loc[output['Region'].str.startswith("Global Systems Integrator (GSI) program SELL-TO", na=False), 'Region'] = "Global Systems Integrator (GSI) program SELL-TO activity, Globally" 
    output.loc[output['Region'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH", na=False), 'Region'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, Globally" 
    output.loc[output['Region'].str.match("Enterprise Target Account activity*", na=False),'Region'] = "Enterprise Target Account activity" 
    output.loc[output['Region'].str.match("National Partner program activity in AMER*", na=False),'Region'] = "National Partner program activity in AMER" 

    output.loc[output['District'].str.startswith("National Partner program activity in AMER", na=False), 'District'] = "National Partner program activity in AMER" 
    output.loc[output['District'].str.startswith("National Partner program activity in the United Kingdom", na=False), 'District'] = "National Partner program activity in the United Kingdom" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-TO activity, in the Americas", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-TO activity, in the Americas" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-TO activity, in EMEA", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-TO activity, in EMEA" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-TO activity, in APJ", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-TO activity, in APJ" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-TO activity, in LATAM", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-TO activity, in LATAM" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-TO activity, for I6", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-TO activity, for I6" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in the Americas", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in the Americas" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in EMEA", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in EMEA" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in APJ", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in APJ" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in LATAM", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, in LATAM" 
    output.loc[output['District'].str.startswith("Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, for I6", na=False), 'District'] = "Global Systems Integrator (GSI) program SELL-THROUGH/WITH activity, for I6" 
'''  