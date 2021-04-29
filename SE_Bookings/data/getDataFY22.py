'''
Created on Jan 11, 2019

@author: aliu
   
'''
import pandas as pd
import pyodbc

from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive

from datetime import datetime
import project_config as cfg

#==============++++++++++=========================================================
# Read the Territory ID master
# from The Quota Master File - Reference - Territory Quotas sheet
# Process the Territory Quote File exported from Anaplan and save in Google Drive
#
# Anaplan Report
# Google Folder: My Drive > SE Analytics > Analytics > Territory_Target
#===============++++++++++========================================================
def get_Anaplan_TerritoryID_Master(file_link, credential):
    #import pydrive.files

    print('Start process Anaplan Territory Quota file')
    
    file_id = file_link[file_link.find('/file/d')+8:file_link.find('/view')]
    file_name = "C:\\Users\\aliu\\Downloads\\stage_google_sheet.xlsx"
    
    GoogleAuth.DEFAULT_SETTINGS['client_config_file'] = credential
    gauth = GoogleAuth()

    gauth.LoadCredentialsFile("mycreds.txt")
    if gauth.credentials is None:
        # Authenticate if they're not there
        gauth.LocalWebserverAuth()
    elif gauth.access_token_expired:
        # Refresh them if expired
        gauth.Refresh()
    else:
        # Initialize the saved creds
        gauth.Authorize()
        # Save the current credentials to a file
    gauth.SaveCredentialsFile("mycreds.txt")

    drive = GoogleDrive(gauth)
    downloaded = drive.CreateFile({'id': file_id})
    downloaded.GetContentFile(file_name) #download the google drive file into file_name
        
    report_date = datetime.strptime(downloaded.get('title')[37:47], "%m.%d.%Y").date()

    print(report_date)

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
        #target = 'Coverage and Quota Report by Month - 04.15.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 05.04.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 05.14.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 06.09.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 06.12.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 08.17.2020.xlsx'        
        #target = 'Coverage and Quota Report by Month - 09.04.2020.xlsx'
        #target = 'Coverage and Quota Report by Month - 03.01.2021.xlsx'
        #target = 'Coverage and Quota Report by Month - 03.05.2021.xlsx'
        target = 'Coverage and Quota Report by Month - 04.01.2021.xlsx'

        supplment = "Supplement.xlsx"
             
        prep_file = pd.read_excel(cfg.sup_folder + supplment, sheet_name='TerritoryID_Master', skiprows=3, header=0, usecols = "V:Z")
        prep_file = prep_file[prep_file.Include == 1.0]
        read_cols = ",".join(list(prep_file.Column))
        new_names = list(prep_file.NewName)
        data_type = dict(zip(prep_file.NewName, prep_file.DataType))
          
        output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Sheet 1', skiprows=1, usecols=read_cols, names=new_names,
                               dtypes=data_type, keep_default_na=True)        
        
        output = output[~output.Territory_ID.isnull()]
        output['Short_Description'].replace('\n', "", regex=True, inplace=True)
        #output.loc[output.Territory_ID=='OL_GLO_EMA_EMA_EG1','Short_Description'] = 'EMEA Globals (team 1)'
        #output.loc[output.Territory_ID=='OL_GLO_EMA_EMA_EG2','Short_Description'] = 'EMEA Globals (team 2)'
        #output.loc[output.Territory_ID=='OL_GLO_EMA_EMA','Short_Description'] = 'EMEA Globals'  
        #a = output[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002']['Territory_Description']
        #b = a.str.replace('\n', " ") 
        #output.loc[output.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002','Territory_Description'] = b   
        
        Territory_Hierarchy = {0 : 'Hierarchy', 
                               1 : 'Theater',
    #                           2 : 'Super-Region',
                               2 : 'Area',
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
   
        #output.rename(columns = {'Super-Region':'Super_Region'}, inplace=True)
                    
        supplment = "TerritoryID_to_SFDC_SubDivision_Mapping.xlsx"
        
        xls = pd.ExcelFile(cfg.sup_folder + supplment, on_demand = True)
        sheets = xls.sheet_names
        
        #FY20
        #SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name=sheets[1], header=0, usecols = "F:I", names=['SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division', 'Territory_ID'])

        #FY21
        #SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Anaplan-SFDC Map FY21', header=0, skiprows=1, usecols = "B,E:G", names=['Territory_ID','SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division'])
        
        #FY22
        SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Anaplan-SFDC Map FY22', header=0, skiprows=1, usecols = "B,H:J", names=['Territory_ID','SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division'])

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
               #'Super_Region',
        Territory_Quota = pd.melt(ID_Master, id_vars = ['Hierarchy','Theater','Area','Region','District', 'Territory','Territory_ID','SFDC_Theater','SFDC_Division','SFDC_Sub_Division','Level'],
                       value_vars=Quota_assignment_col, var_name='Period',value_name='Quota')
        Territory_Quota['Measure'] = Territory_Quota.Period.str[3:]
        Territory_Quota['Period'] = Territory_Quota.Period.str[0:2]
        Territory_Quota['Year'] = 'FY22'
       
        ## writing to the database
        # import pyodbc
        from sqlalchemy import create_engine
        from sqlalchemy import types as sqlalchemy_types
            
        server = 'ALIU-X1'
        database = 'ALIU_DB1'
        conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work
        #sqlcon = create_engine("mssql+pyodbc://user:pwd@ALIU-X1") #work

        server = 'PS-SQL-Dev02'
        database = 'SalesOps_DM'
        conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 

        supplment = "Supplement.xlsx"        
        to_sql_type = pd.read_excel(cfg.sup_folder + supplment, sheet_name = 'Output_DataTypes', header=0, usecols= "B:D")
        TerritoryID_Master_type = to_sql_type[to_sql_type.DB_TableName == 'TerritoryID_Master']

        data_type={}
        for i in range(0,len(TerritoryID_Master_type.Columns)):
            data_type[TerritoryID_Master_type.iloc[i].Columns] = eval(TerritoryID_Master_type.iloc[i].DataType)
        
        a = list(set(ID_Master.columns) - set(Quota_assignment_col))
        ID_Master[a].to_sql('TerritoryID_Master_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        ID_Master[a].to_sql('TerritoryID_Master_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        #[ID_Master.Hierarchy != 'Other Overlay']
        #ID_Master.to_csv(cfg.output_folder+'TerritoryID_Master_FY21.txt', sep="|", index=False)
        
        Territory_Quota_type = to_sql_type[to_sql_type.DB_TableName == 'Territory_Quota']
        data_type = {}
        for i in range(0, len(Territory_Quota_type.Columns)):
            data_type[Territory_Quota_type.Columns.iloc[i]] = eval(Territory_Quota_type.DataType.iloc[i])
        
        #Territory_Quota.to_csv(cfg.output_folder+'Territory_Quota_FY21.txt', sep="|", index=False)
        #Territory_Quota[Territory_Quota.Hierarchy != 'Other Overlay'].to_sql('Territory_Quota_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        Territory_Quota.to_sql('Territory_Quota_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        Territory_Quota.to_sql('Territory_Quota_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
        
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

    server = 'PS-SQL-Dev02'
    database = 'Anaplan_DM'
    table = 'dbo.Employee_Territory_And_Quota'
    
   #[Headcount_Group]        
    cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    query = (
    'select \'FY22\' [Year], [Time] [Report_Date], [Workday Employees E1] Name, [Employee ID] [EmployeeID], [Email - Primary Work] [Email], [SFDC User ID] [SFDC_UserID],'
    '       Manager, [Manager ID] [Manager_EmployeeID], [Termination Date] Termination_Date,'
    '       [Job Title] [Title], [Sales Group 4] [Resource_Group],'
    '       [Plan Name] [Plan_Name], substring([Plan Name], CHARINDEX(\'(\',[Plan Name])+1, CHARINDEX(\')\',[Plan Name]+\')\')-CHARINDEX(\'(\',[Plan Name]) -1  ) [Plan_Code],'
    '       [Measure 1 Plan Effective Date] [Effective_Date],'
    '       [Measure 1 Coverage Assignment ID] [M1_Territory_IDs], [Measure 1 Theater] [M1_Theater], [Measure 1 Super-Region] [M1_Area], [Measure 1 Region] [M1_Region],'
    '       [Measure 1 District] [M1_District], [Measure 1 Territory Type] [M1_Territory_Type], [Measure 1 Territory Segment] [M1_Segments], '
    '       [Measure 1 Comp Plan Measure Weight%] [M1_Weight], [Measure 1 FY BCR Quota] [M1_FY_BCR_Quota],'
    '       [Measure 1 Q1 Assigned Quota] [M1_Q1_Quota_Assigned], [Measure 1 Q2 Assigned Quota] [M1_Q2_Quota_Assigned], [Measure 1 Q3 Assigned Quota] [M1_Q3_Quota_Assigned], [Measure 1 Q4 Assigned Quota] [M1_Q4_Quota_Assigned],'
    ''
    '       [Measure 2 Coverage Assignment ID] [M2_Territory_IDs], [Measure 2 Theater] [M2_Theater], [Measure 2 Super-Region] [M2_Area], [Measure 2 Region] [M2_Region],'
    '       [Measure 2 District] [M2_District], [Measure 2 Territory Type] [M2_Territory_Type], [Measure 2 Territory Segment] [M2_Segments],'
    '       [Measure 2 Comp Plan Measure Weight%] [M2_Weight], [Measure 2 FY BCR Quota] [M2_FY_BCR_Quota],'
    '       [Measure 2 Q1 Assigned Quota] [M2_Q1_Quota_Assigned], [Measure 2 Q2 Assigned Quota] [M2_Q2_Quota_Assigned], [Measure 2 Q3 Assigned Quota] [M2_Q3_Quota_Assigned], [Measure 2 Q4 Assigned Quota] [M2_Q4_Quota_Assigned]'
    '' 
    'from Anaplan_DM.dbo.Employee_Territory_And_Quota'
    )
    
    output = pd.read_sql(query, cnxn)
    cnxn.close()

  
    #override [Sales Group 4] to get some AE : SE mapping , Global Accounts : OL_EGA_EGA*
    #1 : Put Steven Keogh's group, i.e. to Global SE, since the AE resource Global AE
    output.loc[output.Manager == 'Steven Keogh', 'Resource_Group'] = 'Global SE'
    
    #2 : Marking the MSP : Territory OL_MSP* OL_SPR
    output.loc[output.Name== 'Chris Callander','Resource_Group'] =  'DM'  # change value from CAM to DM
    # Manager == 'Rami Douenias'
    output.loc[output.Name.isin(['Mark Chauvin','Simon Kavalki','Mike Richards','Ben Taylor','Cindy Finkel','Chris Fuller','Robert Ibbitson','Frank Muller']), 'Resource_Group'] = 'Direct SE'
    
    
    #3 : Marking the PTMs
    output.loc[output.Manager.isin(['Mark Hirst','Markus Wolf','Karen Hoong']), 'Resource_Group'] = 'PTM'
    output.loc[output.Name.isin(['Mark Hirst','Markus Wolf','Karen Hoong']), 'Resource_Group'] = 'PTD'
    
    #4: other misc
    output.loc[output.Name== 'Glenn McIntosh', 'Resource_Group'] = 'SE' # in Sylvain Gagne Solution Architect
    output.loc[output.Name== 'Sanjay Sharma', 'Resource_Group'] = 'SE' # in Sylvain Gagne Solution Architect
    output.loc[output.Name== 'Michael Richards', 'Resource_Group'] = 'Direct SE' # in Rami  Douenias, SE
    output.loc[output.Name== 'Simon Kavakli', 'Resource_Group'] = 'Direct SE' # in Rami  Douenias, SE
    output.loc[output.Name.isin(['Seth Kindley']), 'Resource_Group'] = 'SE Mgmt'  # FB DA SE Mgmt
    

    #5: Hack
    output.loc[output.Name== 'Steven Keogh', 'Resource_Group'] = 'SE Mgmt'
    output.loc[output.Name== 'Steven Keogh', 'M1_Territory_IDs'] = 'OL_EGA_EGA'
    
#   
#     update_type = ['Plan_Effective_Date','Plan_Change_Date','Termination_Plan_End_Date']
#     for i in update_type:
#         output[i] = pd.to_datetime(output[i], format="%Y-%m-%d",errors='coerce')
#   
    
    # remove the resources who do not have a quota/compensation territory assignment
    #output = output[(output.M1_Territory_IDs!='No Plan / No Coverage') & (~output.M1_Territory_IDs.isnull())]
    # drop the resources who left the company
    #output = output[(output.Termination_Date.isnull())] 
    output = output[(output.Termination_Date=='')] 
    return output

#===============================================================================
# Read 360Insight Wavemaker Report file
# 
# Folder : Shared With Me > CY2021
# Shared by Lorrayne Gilbert
#
#===============================================================================
    # help: https://medium.com/@ammar.nomany.tanvir/read-write-update-drive-excel-file-with-pydrive-f63134120ff9
    
def get_Wavemaker_Report(file_link, credential) :   
    
    file_id = file_link[file_link.find('/file/d')+8:file_link.find('/view')]
    file_name = "C:\\Users\\aliu\\Downloads\\stage_google_sheet.xlsx"
    
    GoogleAuth.DEFAULT_SETTINGS['client_config_file'] = credential
    gauth = GoogleAuth()

    gauth.LoadCredentialsFile("mycreds.txt")
    if gauth.credentials is None:
        # Authenticate if they're not there
        gauth.LocalWebserverAuth()
    elif gauth.access_token_expired:
        # Refresh them if expired
        gauth.Refresh()
    else:
        # Initialize the saved creds
        gauth.Authorize()
        # Save the current credentials to a file
    gauth.SaveCredentialsFile("mycreds.txt")
    
    drive = GoogleDrive(gauth)
    downloaded = drive.CreateFile({'id': file_id})
    downloaded.GetContentFile(file_name) #download the google drive file into file_name
    report_date = datetime.strptime(downloaded.get('title')[23:32], "%d %b %y").date()
      
    #read from the Excel Report, save into a temp file without password
    import win32com.client
    import os
    #from xlrd import *
    xlApp = win32com.client.Dispatch("Excel.Application")
    xlwb = xlApp.Workbooks.Open(file_name, False, True, None, 'W4veM4kers')
    xlsheet = xlwb.Worksheets["Pure WM - partners"]
    if os.path.exists('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv'):  #remove the file if exists
        os.remove('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    xlsheet.SaveAs('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv', FileFormat=62, Password = None) # answer overwrite
    xlwb.Close(SaveChanges=False) #answer do not save change
    
    import pandas as pd
    df2 = pd.read_csv('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    df2['Report_date'] = report_date
    
    df2.rename(columns = {"User Group" : "WM_level",
                          "Username" : "User_Id",
                          "Dated of registration" : "Date_of_Registration",
                          "Date of last log in" : "Last_Login",
                          "Awarded for claims" : "Awarded_for_claims",
                          "Awarded for prizes" : "Awarded_for_prizes",
                          "Full name" : "Name",
                          "PTM" : "PTM_Id",
                          "PTM name" : "PTM_name",
                          "Log in count" : "Log_in_count"
                          }, inplace=True)
    
    sel_col = ['Report_date', 'ID','Name','Email', 'Company', 'WM_level','User_Id', 'Balance', 'Date_of_Registration', 'Last_Login',
           'Awarded_for_claims', 'Awarded_for_prizes','IsDisti?', 'PTM_Id', 'PTM_name','Activated?', 'Log_in_count']
    
    #write data into PS-SQL-Dev02.SalesOps_DM
    #import pyodbc
    from sqlalchemy import create_engine
    #from sqlalchemy import types as sqlalchemy_types
    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
    df2[sel_col].to_sql('WaveMake_Rpt_Insight', con=conn_str, if_exists='replace', schema="dbo", index=False)

    print('WaveMaker Report is loaded')
