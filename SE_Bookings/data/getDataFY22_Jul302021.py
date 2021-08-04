'''
Created on Jan 11, 2019

@author: aliu
   
'''
import pandas as pd
import pyodbc

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
def refresh_Anaplan_TerritoryID_Master():

# Moving the update into SQL Server Job = SEOps_Get_Territory_Quota using [Anaplan_DM].[dbo].[Territory Master SQL Export]

    print('Start process Anaplan Territory Quota file')
    
    server = 'PS-SQL-Dev02'
    database = 'Anaplan_DM'
#    table = 'Anaplan_DM.dbo.[Territory Master SQL Export]'
    
    cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    query = (' Select [ID], [Level], [Territory L5] Short_Description, [Territory Role Type] [Type], [Territory Segment] Segment,'
             ' right([Time],4) [Year], left([Time],2) [Period],'
             ' [Position Discrete Quota] [M1_Quota], [Position FlashBlade Overlay Quota] [FB_Quota], [Position Partner Sourced Quota] [PSource_Quota],'
             ' [Crediting Instructions]'
             ' FROM [Anaplan_DM].[dbo].[Territory Master SQL Export]'
             ' where [Time] like \'%FY22\''
             )
    ID_Master = pd.read_sql(query, cnxn)      
    ID_Master['Report_date'] = datetime.today().strftime('%b-%d-%Y')

    ID_Master['M1_Quota'] = ID_Master['M1_Quota'].astype('float', copy = False)
    ID_Master['FB_Quota'] = ID_Master['FB_Quota'].astype('float', copy = False)
    ID_Master['PSource_Quota'] = ID_Master['PSource_Quota'].astype('float', copy = False)

    # Calculate the half year quota
    Quota_col = ['ID','Period','M1_Quota','FB_Quota','PSource_Quota']
    temp = pd.pivot_table(data=ID_Master[ID_Master.ID!=''][Quota_col], index = 'ID', columns = 'Period', values = ['M1_Quota','FB_Quota','PSource_Quota'])
    temp.reset_index(inplace=True)
    
    temp['M1_Quota','1H'] = temp['M1_Quota','Q1'] + temp['M1_Quota','Q2']
    temp['M1_Quota','2H'] = temp['M1_Quota','Q3'] + temp['M1_Quota','Q4']
    temp['FB_Quota','1H'] = temp['FB_Quota','Q1'] + temp['FB_Quota','Q2']
    temp['FB_Quota','2H'] = temp['FB_Quota','Q3'] + temp['FB_Quota','Q4']
    temp['PSource_Quota','1H'] = temp['PSource_Quota','Q1'] + temp['PSource_Quota','Q2']
    temp['PSource_Quota','2H'] = temp['PSource_Quota','Q3'] + temp['PSource_Quota','Q4']
 
    temp.columns = ['_'.join(col) for col in temp.columns.values]
   
    # unpivot quota measures
    ID_Master_Long = pd.melt(temp, id_vars = ['ID_'], value_vars=temp.columns[1:], var_name='Measure_Period', value_name = 'Quota')
    ID_Master_Long['Measure'] = ID_Master_Long['Measure_Period'].str[:-3]
    ID_Master_Long['Period'] = ID_Master_Long['Measure_Period'].str[-2:]

    Master_col = ['ID','Level','Short_Description','Type','Segment','Year','Crediting Instructions','Report_date']
    ID_Master_Long = pd.merge(ID_Master_Long, ID_Master[ID_Master['Period']=='FY'][Master_col], how='left', left_on='ID_', right_on = 'ID')
    ID_Master_Long.drop(['ID_','Measure_Period'], axis=1, inplace=True)
    

    # Add the Hierarchy columns
    # Create the Geo Hierarchy Description Dictionary   
    Geo_Hierarchy = ['Hierarchy','Theater','Area','Region','District','Territory']    
    Geo_Hierarchy_Dict = []    
    for i in range(0,len(Geo_Hierarchy)) :
        keys = ID_Master_Long[ID_Master_Long.Level == Geo_Hierarchy[i]]['ID']
        values = ID_Master_Long[ID_Master_Long.Level == Geo_Hierarchy[i]]['Short_Description']        
        Geo_Hierarchy_Dict.append(dict(zip(keys,values)))       
        
    # Replace the Hierarchy description by looking up the code in dictionary
    Geo_Hierarchy_ID_Len = [2, 6, 10, 14, 18, 22]
    for i in range(0,len(Geo_Hierarchy)):
        ID_Len = Geo_Hierarchy_ID_Len[i]
        ID_Master_Long[Geo_Hierarchy[i]] = ID_Master_Long['ID'].str[:ID_Len]
        ID_Master_Long[Geo_Hierarchy[i]] = ID_Master_Long[Geo_Hierarchy[i]].map(Geo_Hierarchy_Dict[i])
          
    ## Load the data into data frame

    # Read the static Anaplan Hierarchy mapping with SFDC Hierarchy
    supplment = "TerritoryID_to_SFDC_SubDivision_Mapping.xlsx"        
    #xls = pd.ExcelFile(cfg.sup_folder + supplment, on_demand = True)
        
    #FY20
    #SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name=sheets[1], header=0, usecols = "F:I", names=['SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division', 'Territory_ID'])

    #FY21
    #SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Anaplan-SFDC Map FY21', header=0, skiprows=1, usecols = "B,E:G", names=['Territory_ID','SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division'])
        
    #FY22
    SFDC_sub_division = pd.read_excel(cfg.sup_folder + supplment, sheet_name='Anaplan-SFDC Map FY22', header=0, skiprows=1, usecols = "B,H:J", names=['Territory_ID','SFDC_Theater','SFDC_Division', 'SFDC_Sub_Division'])
    SFDC_sub_division = SFDC_sub_division[~SFDC_sub_division.Territory_ID.isnull()]
    ID_Master_Long = pd.merge(ID_Master_Long, SFDC_sub_division, how='left', left_on='ID', right_on='Territory_ID')     
    ID_Master_Long.drop(['Territory_ID'], axis=1, inplace=True)  
    ID_Master_Long.rename(columns = {'ID': 'Territory_ID'}, inplace=True)

    ## writing to the database
    from sqlalchemy import create_engine
    from sqlalchemy import types as sqlalchemy_types
           
    server = 'ALIU-X1'
    database = 'ALIU_DB1'
    conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work

    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 

    supplment = "Supplement.xlsx"        
    to_sql_type = pd.read_excel(cfg.sup_folder + supplment, sheet_name = 'Output_DataTypes', header=0, usecols= "B:D")
    TerritoryID_Master_type = to_sql_type[to_sql_type.DB_TableName == 'TerritoryID_Master']

    data_type={}
    for i in range(0,len(TerritoryID_Master_type.Columns)):
        data_type[TerritoryID_Master_type.iloc[i].Columns] = eval(TerritoryID_Master_type.iloc[i].DataType)
        
    Master_col = ['Territory_ID', 'Short_Description',
                  'Hierarchy', 'Theater', 'Area', 'Region', 'District', 'Territory',
                  'Level', 'Type', 'Segment',  'Crediting Instructions', 'Report_date',
                  'SFDC_Theater', 'SFDC_Division', 'SFDC_Sub_Division']
    
    # Write TerritoryID_Master
    ID_Master_Long[(ID_Master_Long['Period']=='FY') & (ID_Master_Long['Measure'] == 'M1_Quota')][Master_col].to_sql('TerritoryID_Master_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype = data_type)
    ID_Master_Long[(ID_Master_Long['Period']=='FY') & (ID_Master_Long['Measure'] == 'M1_Quota')][Master_col].to_sql('TerritoryID_Master_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
 
    Quota_col = ['Year','Period', 'Measure', 'Quota',
                 'Territory_ID', 'Short_Description', 
                  'Hierarchy', 'Theater', 'Area', 'Region', 'District', 'Territory',
                  'Level', 'Type', 'Segment', 'Report_date',
                  'SFDC_Theater', 'SFDC_Division', 'SFDC_Sub_Division']
       
    Territory_Quota_type = to_sql_type[to_sql_type.DB_TableName == 'Territory_Quota']
    data_type = {}
    for i in range(0, len(Territory_Quota_type.Columns)):
        data_type[Territory_Quota_type.Columns.iloc[i]] = eval(Territory_Quota_type.DataType.iloc[i])
        
    print('Writing to ALIU-X1')
    ID_Master_Long[Quota_col].to_sql('Territory_Quota_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype = data_type)

    print('Writing to PS-SQL-Dev02.SalesOps_DM')
    ID_Master_Long[Quota_col].to_sql('Territory_Quota_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)

    print('Done refresh Territory target')

#=======================================================================
# Read the Territory ID master
# from The Quota Master File - Reference - Territory Quotas sheet
#=======================================================================
def get_TerritoryID_Master():
    
    print ('Reading TerritoryID_Master from database')
    
    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    table = 'SalesOps_DM.dbo.TerritoryID_Master_FY22'
    
    cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    ID_Master = pd.read_sql('select * from ' + table, cnxn)
    
    return(ID_Master)

#===============================================================================
# Read Quota data from the Quota Master Spreadsheet
#===============================================================================
def get_anaplan_quota (refresh=1):
    
    print ("Reading anaplan quota file") 

    server = 'PS-SQL-Dev02'
    database = 'Anaplan_DM'
    # table = 'dbo.Employee_Territory_And_Quota'
    
    #[Headcount_Group]        
    cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
    query = (
    'select \'FY22\' [Year], [Time] [Report_Date],'
    '       [Workday Employees E1] Name, [Employee ID] [EmployeeID], [Email - Primary Work] [Email], [SFDC User ID] [SFDC_UserID],'
    '       Manager, [Manager ID] [Manager_EmployeeID], [Termination Date] Termination_Date,'
    '       [Hire Date] Hire_Date, '
    '       [Job Title] [Title], [Sales Group 4] [Resource_Group],'
    ''
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
    Emp_Territory_Quota = pd.read_sql(query, cnxn)
    
    # Read SE_Org
    query1 = ('Select cast(EmployeeID as varchar) EmployeeID, Role [SE_Role], Level [SE_Level] from [GPO_TSF_Dev ].[dbo].vSE_org')
    se_org = pd.read_sql(query1, cnxn)
    
    cnxn.close()


    output = pd.merge(Emp_Territory_Quota, se_org, how = 'left', on='EmployeeID')

    # Use Sales Group 4 from Anaplan and Role & Level from SE Org to derive the GTM_Role    
    output['GTM_Role'] = output['Resource_Group']
    output.loc[output['Resource_Group'].isin(['Sales Mgmt','Sales Mgmt QBH','RSD','DM','ISR Mgmt','SDR Mgmt']), 'GTM_Role'] = 'Sales Mgmt' 
    output.loc[output['Resource_Group'].isin(['Global AE', 'GSI AE', 'ISO ISR', 'ISO SDR']), 'GTM_Role'] = 'Sales AE'
    output.loc[output['Resource_Group'].isin(['GSI SE', 'Direct SE']), 'GTM_Role'] = 'SE'
    output.loc[output['Resource_Group'].isin(['FB SE']), 'GTM_Role'] = 'DA'
    output.loc[output['Resource_Group'].isin(['Solution Specialist IC']), 'GTM_Role'] = 'FSA'
    output.loc[output['Resource_Group'].isin(['Solution Specialist Mgmt']), 'GTM_Role'] = 'FSA Mgmt'
    output.loc[output['EmployeeID'] == '103058','GTM_Role'] = 'Sales Mgmt'  #overwrite for Brian Carpenter
    
    # overwrite by SE org
    output.loc[~(output['SE_Role'].isna()) & (output['SE_Level']=='Standard'), 'GTM_Role'] = output.loc[~(output['SE_Role'].isna()) & (output['SE_Level']=='Standard'), 'SE_Role']   
    output.loc[output['SE_Role'].isin(['ISE', 'GSI','MSP']), 'GTM_Role'] = 'SE'  # SEs assigned to 'special' territories
    output.loc[(output['SE_Role']=='SE') & (output['SE_Level']=='PRINCIPAL'), 'GTM_Role'] = 'PTS'  
    output.loc[(output['SE_Role']=='SE') & ~(output['SE_Level'].isin(['Standard','PRINCIPAL'])), 'GTM_Role'] = 'SE Mgmt'  
    output.loc[(output['SE_Role']=='FSA') & ~(output['SE_Level'].isin(['Standard','PRINCIPAL'])), 'GTM_Role'] = 'FSA Mgmt'  
    output.loc[(output['SE_Role']=='DA') & (output['SE_Level'] != 'Standard'), 'GTM_Role'] = 'DA Mgmt'  
    output.loc[(output['SE_Role']=='PTM') & (output['SE_Level'] != 'Standard'), 'GTM_Role'] = 'PTD'  

    # Hack
    output.loc[output.Name== 'Steven Keogh', 'M1_Territory_IDs'] = 'OL_EGA_EGA'

    output = output[(output.Termination_Date=='')] 
    return output
   
''' 
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
'''    
#   
#     update_type = ['Plan_Effective_Date','Plan_Change_Date','Termination_Plan_End_Date']
#     for i in update_type:
#         output[i] = pd.to_datetime(output[i], format="%Y-%m-%d",errors='coerce')
#   
    
    # remove the resources who do not have a quota/compensation territory assignment
    #output = output[(output.M1_Territory_IDs!='No Plan / No Coverage') & (~output.M1_Territory_IDs.isnull())]
    # drop the resources who left the company
    #output = output[(output.Termination_Date.isnull())] 


#===============================================================================
# Read 360Insight Wavemaker Report file
# 
# Folder : Shared With Me > CY2021
# Shared by Lorrayne Gilbert
#
#===============================================================================
def refresh_Wavemaker_Report(file_link, credential) :   
   
    from pydrive.auth import GoogleAuth
    from pydrive.drive import GoogleDrive
    
    print('Start refresh Wavemaker_report')
    
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
    
    print('done authentication')
    
    drive = GoogleDrive(gauth)
    downloaded = drive.CreateFile({'id': file_id})
    downloaded.GetContentFile(file_name) #download the google drive file into file_name
    report_date = datetime.strptime(downloaded.get('title')[23:32], "%d %b %y").date()
    
    print('got a stage file')  
    
    #read from the Excel Report, save into a temp file without password
    import win32com.client
    import os
    #from xlrd import *
    xlApp = win32com.client.Dispatch("Excel.Application")
    xlwb = xlApp.Workbooks.Open(file_name, False, True, None, 'W4veM4kers')
    xlsheet = xlwb.Worksheets["Pure WM - partners"] #####
    if os.path.exists('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv'):  #remove the file if exists
        os.remove('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    xlsheet.SaveAs('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv', FileFormat=62, Password = None) # answer overwrite
    xlwb.Close(SaveChanges=False) #answer do not save change
    
    df2 = pd.read_csv('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv',skiprows=0,header=1)
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
    
    print('Load Dataframe')
    
    sel_col = ['Report_date', 'ID','Name','Email', 'Company', 'WM_level','User_Id', 'Balance', 'Date_of_Registration', 'Last_Login',
           'Awarded_for_claims', 'Awarded_for_prizes','IsDisti?', 'PTM_Id', 'PTM_name','Activated?', 'Log_in_count']
    
    #write data into PS-SQL-Dev02.SalesOps_DM
    from sqlalchemy import create_engine
    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
    
    print('Write to PS-SQL-Dev02')
    df2[sel_col].to_sql('WaveMake_Rpt_Insight', con=conn_str, if_exists='replace', schema="dbo", index=False)
    df2[sel_col].to_sql('WaveMaker_Rpt_Insight', con=conn_str, if_exists='replace', schema="dbo", index=False)
    
    #######
    xlApp = win32com.client.Dispatch("Excel.Application")
    xlwb = xlApp.Workbooks.Open(file_name, False, True, None, 'W4veM4kers')
    xlsheet = xlwb.Worksheets["sql - pointsbreakdown"] #####
    if os.path.exists('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv'):  #remove the file if exists
        os.remove('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    xlsheet.SaveAs('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv', FileFormat=62, Password = None) # answer overwrite
    xlwb.Close(SaveChanges=False) #answer do not save change
    
    df3 = pd.read_csv('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    df3['Report_date'] = report_date
    
    df3.rename(columns = {'username' : 'User_Id',
                          'name' : 'Activity',
                          'id' : 'Activity ID',
                          'state' : 'state',
                          'Tag 1' : 'Category',
                          'Tag 2' : 'Type',
                          'points_approved' : 'points_approved'}, inplace=True)
    
    sel_col = ['Report_date','User_Id', 'Activity', 'Activity ID','state','Category','Type', 'points_approved']
    
    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
    
    print('Write to PS-SQL-Dev02')
    df3[sel_col].to_sql('WaveMaker_Activity_Report', con=conn_str, if_exists='replace', schema="dbo", index=False)


    #######
    xlApp = win32com.client.Dispatch("Excel.Application")
    xlwb = xlApp.Workbooks.Open(file_name, False, True, None, 'W4veM4kers')
    xlsheet = xlwb.Worksheets["activities export"] #####
    if os.path.exists('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv'):  #remove the file if exists
        os.remove('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    xlsheet.SaveAs('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv', FileFormat=62, Password = None) # answer overwrite
    xlwb.Close(SaveChanges=False) #answer do not save change
    
    df4 = pd.read_csv('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
    df4['Report_date'] = report_date
    
    df4.rename(columns = {'Enter an activity name' : 'Activity',
                          'Add link URL' : 'Activity URL',
                          'Choose a Pure Category tag' : 'Category',
                          'Choose an article category tag\r\n' : 'Article category',
                          'points_approved' : 'points_approved'}, inplace=True)
    
    sel_col = ['Report_date','Activity ID', 'Activity', 'Activity URL', 'Campaign Name', 'Category', 'Article category', 'Status','Created On', 'Date Added']
    
    server = 'PS-SQL-Dev02'
    database = 'SalesOps_DM'
    conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
    
    print('Write to PS-SQL-Dev02')
    df4[sel_col].to_sql('WaveMaker_Activity_Master', con=conn_str, if_exists='replace', schema="dbo", index=False)

    print('WaveMaker Report is loaded')
