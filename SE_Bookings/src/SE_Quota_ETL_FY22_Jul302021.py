'''
Created on Jan 11, 2019

@author: aliu
'''
#===============================================================================
# From Anaplan files,
# Read the Territory Master
# Coverage assignment
# Quota amount assignment
#===============================================================================

import project_config as cfg
import pandas as pd
import pyodbc
from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

'''
cnxn = pyodbc.connect('DSN=ALIU-X1; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER='ALIU-X1', Database='ALIU_DB1')
cursor = cnxn.cursor()
# for Truncate table - wip
'''
supplment = "Supplement.xlsx"
db_columns_types = pd.read_excel(cfg.sup_folder + supplment, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")

#===============================================================================
# Read the Territory ID master, and writing the Territory ID Master with mapped SFDC Theater/Division/Sub_Division , and Theater Target $
# Source data is manual export from Anaplan
#===============================================================================
from getDataFY22_Jul302021 import get_TerritoryID_Master
TerritoryID_Master = get_TerritoryID_Master()

#===============================================================================
# Reading SE Territory and Quota from the Individual Quota Master spreadsheet
# SE has a $ quota per month, quarter each year (regardless number of territory he/she cover
# A SE may be assigned to 1 or N Territories
# Source data is from Anaplan_DM.dbo.Employee_Territory_And_Quota
# Not all quota employee are loaded yet
#===============================================================================
from getDataFY22_Jul302021 import get_anaplan_quota
quota_master = get_anaplan_quota(1)


server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 

server = 'PS-SQL-Dev02'
database = 'SalesOps_DM'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 


#------------------------------------------------------------------------------ 
# Create report to show the Quota assignment , SE to AE mapping, using Anaplan coverage information
# The report helps user to verify the SE org compensation plan assignment
# Anaplan manages & maintains the Sales resources, account assignment
# Output: Territory_Assignment_W 
#         Territory_Assignment_L
#         SE_Hierarchy_2020 , this one provide the SFDC Sub-Division visibility information
#------------------------------------------------------------------------------ 

# Read the territory assignment from Anaplan 
# Quota_assignement_W is by Name   -- FY21 has only onboarded rep. 'HC_Status', 
Territory_assignment_W = quota_master[['Name','EmployeeID','M1_Territory_IDs', 'M1_Segments']].copy()
Territory_assignment_W.M1_Territory_IDs.fillna("", inplace=True)
len_header = len(Territory_assignment_W.columns) #reassign the numbering

# for user who carry quota for multiple territories, Split the multiple territory coverage into columns
temp = Territory_assignment_W['M1_Territory_IDs'].str.split(',', expand=True)
temp.columns = range(1,len(temp.columns)+1,1)
Territory_assignment_W = pd.merge(Territory_assignment_W, temp, how='left', left_index=True, right_index=True)

Territory_assignment_col = Territory_assignment_W.columns[len_header:]
for i in Territory_assignment_col:
    Territory_assignment_W[i] = Territory_assignment_W[i].str.strip()

# Un-pivot the Territory IDs
Territory_assignment_W.fillna('',inplace=True)
Territory_assignment_L = pd.melt(Territory_assignment_W, id_vars=['Name','EmployeeID','M1_Territory_IDs', 'M1_Segments'],\
                            value_vars = Territory_assignment_col, var_name = 'Territory_assignment', value_name = 'Territory_ID')
Territory_assignment_L = Territory_assignment_L[(~(Territory_assignment_L.Territory_ID.isnull())) & (Territory_assignment_L.Territory_ID!='')].reindex() #clean the null data

Territory_assignment_L.rename(columns = {'M1_Territory_IDs' : 'Territory_IDs',
                                         'M1_Segments' : 'Segments'},
                                         inplace = True)

sel_col = ['Title','Resource_Group','SE_Role','SE_Level','GTM_Role', 'Plan_Code','EmployeeID','Email','Hire_Date', 'IC_MGR', 'Manager', 'Manager_EmployeeID', 'SFDC_UserID']
Territory_assignment_L = pd.merge(Territory_assignment_L, quota_master[sel_col], how = 'left', on='EmployeeID')

sel_col = ['Short_Description','Territory_ID','Level','Hierarchy','Theater','Area','Region','Territory','District','Segment','Type',
            'SFDC_Theater','SFDC_Division','SFDC_Sub_Division']
Territory_assignment_L = pd.merge(Territory_assignment_L, TerritoryID_Master[sel_col], how='left', left_on='Territory_ID', right_on='Territory_ID')
Territory_assignment_L.sort_values(by=['Territory_ID','Name'], inplace=True)

# Write the Quota Assignment to a text file
# Quota_assignment_L.to_csv(cfg.output_folder+'Quota_Assignment_Anaplan.txt', sep="|", index=False)

Territory_assignment_L.Territory_assignment=Territory_assignment_L.Territory_assignment.astype('float')
Territory_assignment_L[['Name', 'Title', 'EmployeeID', 'Resource_Group', 'SE_Role', 'SE_Level','GTM_Role','IC_MGR','Hire_Date',
                    'SFDC_UserID', 'Email', 'Manager', 'Manager_EmployeeID', 'Territory_IDs', 'Segments',
                    'Territory_ID', 'Short_Description', 'Level', 'Segment', 'Type',
                    'Hierarchy', 'Theater', 'Area', 'Region', 'District',
                    'Territory', 'SFDC_Theater', 'SFDC_Division', 'SFDC_Sub_Division']]\
                    = Territory_assignment_L[['Name', 'Title', 'EmployeeID', 'Resource_Group', 'SE_Role', 'SE_Level','GTM_Role','IC_MGR','Hire_Date',
                    'SFDC_UserID', 'Email', 'Manager', 'Manager_EmployeeID', 'Territory_IDs', 'Segments',
                    'Territory_ID', 'Short_Description', 'Level', 'Segment', 'Type',
                    'Hierarchy', 'Theater', 'Area', 'Region', 'District',
                    'Territory', 'SFDC_Theater', 'SFDC_Division', 'SFDC_Sub_Division']].fillna(value='')
                    
''' #check length         ##  'EmployeeID',            
for i in ['Name', 'Title', 'Resource_Group','SFDC_UserID', 'Email', 'Manager', 'Territory_IDs', 'Segments', 
          'Territory_ID', 'Short_Description','Level','Segment', 'Type', 'Hierarchy', 'Theater', 'Super_Region', 'Region', 'District',
          'Territory', 'SFDC_Theater', 'SFDC_Division', 'SFDC_Sub_Division']:
    j = Quota_assignment_L[i].map(lambda x: len(x)).max()
    print (i + '  : ' + str(j))
'''    
# Writing to the database
to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Territory_assignment_byName']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
                  
Territory_assignment_L.to_sql('Territory_assignment_byName_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype=data_type)
Territory_assignment_L.to_sql('Territory_assignment_byName_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)

#------------------------------------------------------------------------------ 
# Theoretically,
# A SE is assigned to territories; a SEM is assigned to districts
# in some cases, SE is assigned to a district/region quota; SEM is assigned to region quota
# For the SE & SEM who are assigned to the 'level' above, create a report to resolve quota assignment to coverage assignment
# Some reasons are:
# A user is ramping up / down, the partnered AE is ramping up/down, then the SE is assigned to the district quota and not a territory quota
# A user is part of a pool for a district/region, then the SE is assigned to the district/region
# The quota amount is less than assigning the Mgr to all Districts in a Region, then the SEM is assigned to Region and not multiple districts
#------------------------------------------------------------------------------ 
#------------------------------------------------------------------------------ 
# Since the SE Mgr covers the entire Region, AnaPlan assign the SE Mgr to a Region.
# 
# For report, need to breakout into region id into district ids
# John Bradley : replace 'WW_GLB_MSP_MSP' with 'WW_GLB_MSP_MSP_MSP; WW_GLB_MSP_MSP_TEL'
# SR-10115_SE Mgmt_Canada SEM : replace 'WW_AMS_COM_CAD' with 'WW_AMS_COM_CAD_CAD; WW_AMS_COM_CAD_TOR'
#------------------------------------------------------------------------------ 

def expand_territory(input_series, expand_to_level):
    # input: a row in the source database, when passed in it is a series
    #print (type(input_series))
    #print (expand_to_level)
    header_col = ['Name', 'Title','EmployeeID', 'SFDC_UserID', 'Email', 'Hire_Date',
                  'GTM_Role','Resource_Group','Plan_Code','SE_Role', 'SE_Level', 'IC_MGR',
                  'Manager', 'Manager_EmployeeID', 'Territory_IDs', 'Segments']
    
    source_territory = input_series['Territory_ID']
    #print(source_territory)
    #print((input_series[header_col]))
    row_count = len(TerritoryID_Master[(TerritoryID_Master.Level == expand_to_level) &\
                                       (TerritoryID_Master.Territory_ID.str.startswith(source_territory)) \
                                       ])
    d1 = pd.DataFrame([input_series[header_col]]*row_count, columns = header_col)
    d2 = pd.DataFrame(TerritoryID_Master[(TerritoryID_Master.Level == expand_to_level) &\
                                         (TerritoryID_Master.Territory_ID.str.startswith(source_territory))], \
                      columns = TerritoryID_Master.columns)
    output = pd.concat([d1.reset_index(),d2.reset_index()],axis=1)
    return(output)

# Initiate the Coverage assignment with the Quota assignment
sel_col = ['Name', 'Title', 'EmployeeID', 'SFDC_UserID', 'Email', 'Hire_Date',
           'GTM_Role', 'Resource_Group', 'Plan_Code', 'SE_Role', 'SE_Level','IC_MGR',
           'Manager', 'Manager_EmployeeID', 'Territory_IDs', 'Segments',
           'Territory_ID', 'Short_Description', 'Level',
           'Hierarchy', 'Theater', 'Area', 'Region', 'District', 'Territory','Segment', 'Type',
           'SFDC_Theater', 'SFDC_Division','SFDC_Sub_Division']

Coverage_assignment_L = Territory_assignment_L[sel_col].copy()
Coverage_assignment_L = Coverage_assignment_L[(Coverage_assignment_L.Name.str.match('^[a-zA-Z]')) & ~(Coverage_assignment_L.Name.str.startswith('SR-')) &\
                                              (Coverage_assignment_L.Territory_ID != '') & ~(Coverage_assignment_L.Territory_ID.isna())]

# Convert the overlay to core territory
cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
query = ('Select * from Anaplan_DM.dbo.Overlay_Territory_Mapping')
overlay_map = pd.read_sql(query, cnxn)

Coverage_assignment_L = pd.merge(Coverage_assignment_L, overlay_map, how='left', left_on='Territory_ID', right_on='FB_Node')
Coverage_assignment_L.loc[~Coverage_assignment_L.WW_Node.isna(),'Territory_ID'] = Coverage_assignment_L.loc[~Coverage_assignment_L.WW_Node.isna(),'WW_Node']      

# Hack for Zach Duncan, 
Coverage_assignment_L.loc[(Coverage_assignment_L.Name=='Zach Duncan') & (Coverage_assignment_L.Territory_ID=='FB_AMS_FED_FED_FED_001'), 'Territory_ID'] = 'WW_AMS_PUB_FED_CIV'
Coverage_assignment_L.loc[(Coverage_assignment_L.Name=='Zach Duncan') & (Coverage_assignment_L.Territory_ID=='FB_AMS_FED_FED_FED_002'), 'Territory_ID'] = 'WW_AMS_PUB_FED_DDI'
Coverage_assignment_L.loc[(Coverage_assignment_L.Name=='Zach Duncan') , 'Level'] = 'District'
                                                                                                           
# Jul 30 : Resolve whoever coverage level is not a Territory level into Territory
temp = Coverage_assignment_L[(Coverage_assignment_L.Level != 'Territory') & ~(Coverage_assignment_L.Level=='')]                                                                                                                             #.isna())]

## Mar 2-2021, data loaded are SEs assigned with Territory
temp2 = pd.DataFrame()
for i in range(len(temp)):
    temp2 = temp2.append(expand_territory(temp.iloc[i],'Territory'))

Coverage_assignment_L = Coverage_assignment_L.append(temp2[sel_col], sort="False")

to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Coverage_assignment_byName']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

Coverage_assignment_L.to_sql('Coverage_assignment_byName_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype=data_type)
Coverage_assignment_L.to_sql('Coverage_assignment_byName_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)

'''    
            ####
            ###FY22 Using the Anaplan [Sales Group 4] need to check here to construct the Resource Role Coverage map 
            ###If going to construct the report in Tableau, this table is not needed
            # Make an output of Coverage_assignment by Territory
            
            sel_Resource_Group = ['RSD','DM','Sales AE', 'FB AE',\
                                  'SE Mgmt', 'Direct SE', 'FB SE', 'SE',\
                                  'Global AE', 'Global SE',\
                                  'CAM', 'Channel Mgmt', 'PTD', 'PTM',\
                                  'Global AE','Global SE',
                                  'SE Specialist IC']
            
            temp = Coverage_assignment_L[(Coverage_assignment_L.Resource_Group.isin(sel_Resource_Group)) & ~(Coverage_assignment_L.Territory_ID=='')]\
                                                   [['Name','Territory_ID','Resource_Group','EmployeeID','SFDC_UserID', 'Email']]
            temp['EmployeeID'] = temp['EmployeeID'].astype('str')
            
            #change the Global AE and Global SE resource_group value, so their records are include to the output
            temp.loc[temp.Resource_Group == 'Global AE', 'Resource_Group'] = 'Sales AE'
            temp.loc[temp.Resource_Group == 'Global SE', 'Resource_Group'] = 'Direct SE'
            
            Coverage_assignment_W = pd.pivot_table(temp, \
                                                   index = 'Territory_ID', columns='Resource_Group', values=['Name','Email','SFDC_UserID','EmployeeID'], aggfunc=lambda x: ' | '.join(x))
            
            new_name=[]
            for i in Coverage_assignment_W.columns.levels[0]:
                for j in Coverage_assignment_W.columns.levels[1]:
                    new_name.append(j + " " + i)
            Coverage_assignment_W.columns = Coverage_assignment_W.columns.droplevel(0)
            Coverage_assignment_W.columns=new_name
            #Coverage_assignment_W.drop(columns=[' Name',' Email',' EmployeeID',' SFDC_UserID'], inplace=True)  # dropping the users who is not tag to a resource group
            
            Coverage_assignment_W = Coverage_assignment_W[['Sales AE Name','Direct SE Name', 'Sales AE Email', 'Direct SE Email', 'Direct SE EmployeeID', 'Direct SE SFDC_UserID']].reset_index()
            Coverage_assignment_W.rename(columns = {'Sales AE Name' : 'Acct_Exec',
                                                    'Sales AE Email' : 'Acct_Exec_Email',
                                                    'Direct SE Name' : 'SE',
                                                    'Direct SE Email' : 'SE_Email',
                                                    'Direct SE EmployeeID' : 'SE_EmployeeID',
                                                    'Direct SE SFDC_UserID' : 'SE_SFDC_UserID'}, inplace=True)
            
            # Write the Coverage Assignment to a text file
            #Coverage_assignment_W.to_csv(cfg.output_folder+'Coverage_Assignment_byTerritory.txt', sep="|", index=False)
            
            to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Coverage_assignment_byTerritory']
            
            data_type={}
            for i in range(0,len(to_sql_type.Columns)):
                data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
                
            Coverage_assignment_W.fillna('', inplace=True)   
            
            ##check length                     
            #for i in Coverage_assignment_W.columns:
            #    j = Coverage_assignment_W[i].map(lambda x: len(x)).max()
            #    print (i + '  : ' + str(j))    
            
            Coverage_assignment_W.to_sql('Coverage_assignment_byTerritory_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype=data_type)
            #Coverage_assignment_W.to_sql('Coverage_assignment_byTerritory_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)
'''

#------------------------------------------------------------------------------ 
'''
            # Read the individual quota information
            # This output is not needed after all dashboards have moved to read from Anaplan_DM
            
            SE_quota_W = quota_master[['Name', 'M1_Territory_IDs','M1_Segments', 'EmployeeID', 'SFDC_UserID', 'Email', 'Year', 
                           'Resource_Group', 'M1_Theater','M1_Area','M1_Region','M1_District', 
                           'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned',
                           'M1_Weight', 'M1_FY_BCR_Quota']].copy()
            
            ## calculate the 1H, 2H and Annual quota
            SE_quota_W['M1_1H'] = SE_quota_W['M1_Q1_Quota_Assigned'] + SE_quota_W['M1_Q2_Quota_Assigned']
            SE_quota_W['M1_2H'] = SE_quota_W['M1_Q3_Quota_Assigned'] + SE_quota_W['M1_Q4_Quota_Assigned']
            SE_quota_W['M1_FY'] = SE_quota_W['M1_Q1_Quota_Assigned'] + SE_quota_W['M1_Q2_Quota_Assigned'] + SE_quota_W['M1_Q3_Quota_Assigned'] + SE_quota_W['M1_Q4_Quota_Assigned']
            
            
            # Un-pivot the SE quota information
            SE_quota_L = pd.melt(SE_quota_W, id_vars=['Name', 'M1_Territory_IDs', 'EmployeeID', 'SFDC_UserID', 'Email', 'Year',
                                                      'Resource_Group','M1_Theater','M1_Area','M1_Region','M1_District','M1_Segments', 'M1_Weight','M1_FY_BCR_Quota'],
                                 value_vars = ['M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned', 'M1_1H','M1_2H','M1_FY'],
                                 var_name = 'Period', value_name = 'Quota').reindex()
            
            
            rename_column = { 'M1_Territory_IDs' : 'Territory_IDs',
                              'M1_Theater' : 'Theater',
                              'M1_Area' : 'Area',
                              'M1_Region' : 'Region',
                              'M1_District' : 'District',
                              'M1_Segments' : 'Segments',
                              'M1_Weight' : 'Weight',
                              'M1_FY_BCR_Quota' : 'FY_BCR_Quota'}
            
            SE_quota_L.rename(columns=rename_column, inplace=True)
            
            relabel_quarters = ['M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned', 'M1_1H','M1_2H','M1_FY']
            
            for i in relabel_quarters:
                SE_quota_L.loc[SE_quota_L.Period == i, 'Measure'] = i[:2]
                SE_quota_L.loc[SE_quota_L.Period == i, 'Period'] = i[3:5]
            
            ## reshape M2 
            SE_quota_W_M2 = quota_master[['Name', 'M2_Territory_IDs', 'M2_Segments', 'EmployeeID', 'SFDC_UserID', 'Email', 'Year', 
                           'Resource_Group', 'M2_Theater','M2_Area','M2_Region','M2_District',
                           'M2_Q1_Quota_Assigned', 'M2_Q2_Quota_Assigned', 'M2_Q3_Quota_Assigned', 'M2_Q4_Quota_Assigned',
                           'M2_Weight','M2_FY_BCR_Quota']].copy()
            
            SE_quota_W_M2['M2_1H'] = SE_quota_W_M2['M2_Q1_Quota_Assigned'] + SE_quota_W_M2['M2_Q2_Quota_Assigned']
            SE_quota_W_M2['M2_2H'] = SE_quota_W_M2['M2_Q3_Quota_Assigned'] + SE_quota_W_M2['M2_Q4_Quota_Assigned']
            SE_quota_W_M2['M2_FY'] = SE_quota_W_M2['M2_Q1_Quota_Assigned'] + SE_quota_W_M2['M2_Q2_Quota_Assigned'] + SE_quota_W_M2['M2_Q3_Quota_Assigned'] + SE_quota_W_M2['M2_Q4_Quota_Assigned']
            
            # Un-pivot the SE quota information
            SE_quota_L_M2 = pd.melt(SE_quota_W_M2, id_vars=['Name', 'M2_Territory_IDs', 'EmployeeID', 'SFDC_UserID', 'Email', 'Year',
                                                      'Resource_Group','M2_Theater','M2_Area','M2_Region','M2_District','M2_Segments', 'M2_Weight','M2_FY_BCR_Quota'],
                                 value_vars = ['M2_Q1_Quota_Assigned', 'M2_Q2_Quota_Assigned', 'M2_Q3_Quota_Assigned', 'M2_Q4_Quota_Assigned', 'M2_1H','M2_2H','M2_FY'],
                                 var_name = 'Period', value_name = 'Quota').reindex()
            
            rename_column = { 'M2_Territory_IDs' : 'Territory_IDs',
                              'M2_Theater' : 'Theater',
                              'M2_Area' : 'Area',
                              'M2_Region' : 'Region',
                              'M2_District' : 'District',
                              'M2_Segments' : 'Segments',
                              'M2_Weight' : 'Weight',
                              'M2_FY_BCR_Quota' : 'FY_BCR_Quota'}
            
            SE_quota_L_M2.rename(columns=rename_column, inplace=True)
            
            relabel_quarters = ['M2_Q1_Quota_Assigned', 'M2_Q2_Quota_Assigned', 'M2_Q3_Quota_Assigned', 'M2_Q4_Quota_Assigned', 'M2_1H','M2_2H','M2_FY']
            
            for i in relabel_quarters:
                SE_quota_L_M2.loc[SE_quota_L_M2.Period == i, 'Measure'] = i[:2]
                SE_quota_L_M2.loc[SE_quota_L_M2.Period == i, 'Period'] = i[3:5]
            
            SE_quota_L = SE_quota_L.append(SE_quota_L_M2, ignore_index=True, sort=False)
            
            
            #SE_quota_L.to_csv(cfg.output_folder+'SE_Quota.txt', sep="|", index=False)
            to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'SE_Org_Quota']
            
            data_type={}
            for i in range(0,len(to_sql_type.Columns)):
                data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
            
            SE_quota_L.fillna('', inplace=True)
            
            #check length                     
            #for i in list(SE_quota_L.columns[:-3]):
            #    j = SE_quota_L[i].map(lambda x: len(x)).max()
            #    print (i + '  : ' + str(j))    
            #    
            
            SE_quota_L.to_sql('SE_Org_Quota_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype = data_type)
            SE_quota_L.to_sql('SE_Org_Quota_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)
'''
#----------------------------------------------------------------------------------------------------- 
# Construct a list of District where a User have view permission
# for SE, Specialist (the leaves of SE org), assign District permission based on one's Territory assignment
# for Management, assign District permission based on their subordinate.
#
# A user is given visibility to Geo/Region/District that are under the assigned Territory
# GVP, AVP, Director are given permission to the Geo/Region/District based on their sub-ordinate
#------------------------------------------------------------------------------------------------------

# Initialize the dataframe
#District_Permission = pd.DataFrame(columns = ['Name','Email','EmployeeID', 'SFDC_UserID','Resource_Group','Plan_Code','Territory_ID','Manager', 'Manager_EmployeeID'])
#District_Permission = pd.DataFrame(columns = ['Name','Email','EmployeeID', 'SFDC_UserID','SE_Role','SE_Level','GTM_Role','Territory_ID','Manager', 'Manager_EmployeeID'])

# Using Coverage assignment_L which has already translate into Territory
# Step 1: All SE Resources - provide permission to the district in his/her assigned territories
District_Permission = Coverage_assignment_L[Coverage_assignment_L.Level=='Territory'][['Name','Email','EmployeeID', 'SFDC_UserID','Resource_Group','SE_Role','SE_Level','GTM_Role','Territory_ID','Manager', 'Manager_EmployeeID']].copy()
District_Permission['Territory_ID'] = District_Permission['Territory_ID'].str[:18]
District_Permission.drop_duplicates(subset=['SFDC_UserID', 'Territory_ID'], keep='first', inplace=True)

# Step 2: Give User access because of the reporting hierarchy
#Resource_List = ['SE Mgmt','PTS','PTD','FSA Mgmt']
#Users_need_access = list(dict.fromkeys(District_Permission[District_Permission.GTM_Role.isin(Resource_List)]['Name']))
Users_need_access = ['Adrian Simays']

for i in Users_need_access:
    #User_assigned_coverage = list(dict.fromkeys(Coverage_assignment_L[Coverage_assignment_L.Name==i]['Territory_ID']))
    User_assigned_coverage = list(dict.fromkeys(Coverage_assignment_L[Coverage_assignment_L.Manager==i]['Territory_ID']))
    
    for j in User_assigned_coverage:
        # find the Territory Id of Districts roll under the user's coverage
        Coverage_List = pd.DataFrame(list(TerritoryID_Master[TerritoryID_Master.Territory_ID.str.startswith(j, na=False) & (TerritoryID_Master.Level == 'District')]['Territory_ID'])
                                    , columns=['Territory_ID'])

        if len(Coverage_List) == 0 :
            for x in User_assigned_coverage:
                Coverage_List = Coverage_List.append({'Territory_ID':x[:18]}, ignore_index=True)
            
        temp = pd.concat([quota_master.loc[quota_master.Name==i,['Name','Email','EmployeeID','SFDC_UserID','SE_Role','SE_Level','GTM_Role','Manager', 'Manager_EmployeeID']]]*(len(Coverage_List)), ignore_index=True)
        temp = pd.concat([temp, Coverage_List], axis=1)      
        District_Permission = District_Permission.append(temp, sort=False)           
District_Permission.drop_duplicates(subset=['SFDC_UserID', 'Territory_ID'], keep='first', inplace=True)


# Step 3: Give User who is not in the SE Org or who does not have coverage the district access
# {Name : [User email, Resource_Group,Manager], [Names to copy]}
extra_users = { 'April Liu' : ['aliu@purestorage.com','104663','SE Support', 'Steve Gordon', ['Carl McQuillan', 'Nathan Hall','Zack Murphy']],
                'Thomas Waung' : ['twaung@purestorage.com', '103800', 'SE Support', 'Naomi Newport', ['Carl McQuillan', 'Nathan Hall','Zack Murphy']],
                'Andrew May' : ['amay@purestorage.com', '102638', 'SE Support', 'Victoria Sanchez', ['Carl McQuillan', 'Nathan Hall','Zack Murphy']],
                'Steve Gordon' :['sgordon@purestorage.com','105394', 'SE Support','Gary Kortye', ['Carl McQuillan', 'Nathan Hall','Zack Murphy']],
                'Lauren Futris' :['lfutris@purestorage.com','108451', 'SE Support','Gary Kortye', ['Carl McQuillan', 'Nathan Hall','Zack Murphy']]
              }

for i in list(extra_users.keys()) :
    for j in range(0, len(extra_users[i][4])):
        temp = District_Permission[District_Permission.Name == extra_users[i][4][j]].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.EmployeeID = extra_users[i][1]
        temp.SFDC_UserID = ''
        temp.Resource_Group = extra_users[i][2]
        temp.Manager = extra_users[i][3]
        temp.Manager_EmployeeID = ''
    
        District_Permission = District_Permission.append(temp)
               
District_Permission.drop_duplicates(subset=['Email', 'Territory_ID'], keep='first', inplace=True)        
District_Permission.rename(columns={'Email':'User'}, inplace=True)

sel_col = ['Short_Description', 'Territory_ID', 'Level', 'Hierarchy', 
           'Theater', 'Area', 'Region', 'District']
SE_District_Permission = pd.merge(District_Permission[['Name','User','EmployeeID','SFDC_UserID','Resource_Group','Manager','Territory_ID']], TerritoryID_Master[sel_col], how='left', left_on='Territory_ID', right_on='Territory_ID')

to_sql_type = db_columns_types[db_columns_types.DB_TableName=='District_Permission']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

District_Permission.to_sql('SE_District_Permission_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False, dtype=data_type)
District_Permission.to_sql('SE_District_Permission_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)


print('I am so done updating Territory and District Permission')

