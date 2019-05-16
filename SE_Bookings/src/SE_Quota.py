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
from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types
import pyodbc


server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work

'''
cnxn = pyodbc.connect('DSN=ALIU-X1; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER='ALIU-X1', Database='ALIU_DB1')
cursor = cnxn.cursor()
# for Truncate table - wip
'''
supplment = "Supplement.xlsx"
db_columns_types = pd.read_excel(cfg.sup_folder + supplment, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")

#===============================================================================
# Read the Territory ID master
#===============================================================================
from getData import get_TerritoryID_Master
TerritoryID_Master = get_TerritoryID_Master(1)

#===============================================================================
# Reading SE Territory and Quota from the Individual Quota Master spreadsheet
# SE has a $ quota per month, quarter each year (regardless number of territory he/she cover
# A SE may be assigned to 1 or N Territories
#===============================================================================
#from getData import get_quota
#quota_master = get_quota(1)
#quota_master['Name'] = quota_master.FirstName.str.cat(quota_master.LastName, sep=' ')

from getData import get_anaplan_quota
quota_master = get_anaplan_quota(1)

## Joe Mercede
## Eugenue McCarth
## Coverage assignment vs Comm Plan Assignment 
#------------------------------------------------------------------------------ 
# Create report to show the Quota assignment , SE to AE mapping, using Anaplan coverage information
# The report helps user to verify the SE org compensation plan assignment
# Anaplan manages & maintains the Sales resources, account assignment
# Output: Territory_Assignment_W 
#         Territory_Assignment_L
#         SE_Hierarchy_2020 , this one provide the SFDC Sub-Division visibility information
#------------------------------------------------------------------------------ 

# Read the Quota assignment from Anaplan 
# Quota_assignement_W is by Name
Quota_assignment_W = quota_master[['Name', 'Title','Resource_Group','HC_Status', 'EmployeeID','SFDC_UserID', 'Email','Manager','Territory_IDs']]
Quota_assignment_W.Territory_IDs.fillna("", inplace=True)
len_header = len(Quota_assignment_W.columns)

# for user who carry quota for multiple territories, Split the multiple territory coverage into columns
temp = Quota_assignment_W['Territory_IDs'].str.split(';', expand=True)
Quota_assignment_W = pd.merge(Quota_assignment_W, temp, how='left', left_index=True, right_index=True)

Quota_assignment_col = Quota_assignment_W.columns[len_header:]
for i in Quota_assignment_col:
    Quota_assignment_W[i] = Quota_assignment_W[i].str.strip()

# Un-pivot the Territory IDs
Quota_assignment_L = pd.melt(Quota_assignment_W, id_vars=['Name','Title','Resource_Group', 'HC_Status', 'EmployeeID','SFDC_UserID', 'Email', 'Manager','Territory_IDs'], value_vars = Quota_assignment_col,
                var_name = 'Quota_assignment', value_name = 'Territory_ID')
Quota_assignment_L = Quota_assignment_L[~(Quota_assignment_L.Territory_ID.isnull())] #clean the null data

Quota_assignment_L = pd.merge(Quota_assignment_L, TerritoryID_Master, how='left', left_on='Territory_ID', right_on='Territory_ID')
Quota_assignment_L.sort_values(by=['Territory_ID','Name'], inplace=True)

# Write the Quota Assignment to a text file
# Quota_assignment_L.to_csv(cfg.output_folder+'Quota_Assignment_Anaplan.txt', sep="|", index=False)

# Writing to the database
to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Territory_assignment_byName']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

Quota_assignment_L.to_sql('Territory_assignment_byName', con=conn_str, if_exists='replace', schema="dbo", index=False)
    
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
    header_col = ['Name', 'Title', 'Resource_Group', 'HC_Status', 'EmployeeID','SFDC_UserID', 'Email', 'Manager', 'Territory_IDs', 'Quota_assignment']
    source_territory = input_series['Territory_ID']
    #print(source_territory)
    #print((input_series[header_col]))
    row_count = len(TerritoryID_Master[(TerritoryID_Master.Level == expand_to_level) & (TerritoryID_Master.Territory_ID.str.startswith(source_territory))])
    d1 = pd.DataFrame([input_series[header_col]]*row_count, columns = header_col)
    d2 = pd.DataFrame(TerritoryID_Master[(TerritoryID_Master.Level == expand_to_level) & (TerritoryID_Master.Territory_ID.str.startswith(source_territory))],
                      columns = TerritoryID_Master.columns)
    output = pd.concat([d1.reset_index(),d2.reset_index()],axis=1)
    return(output)

# Initiate the Coverage assignment with the Quota assignment
Coverage_assignment_L = Quota_assignment_L.copy()
Coverage_assignment_L = Coverage_assignment_L[(Coverage_assignment_L.Name.str.match('^[a-zA-Z]')) & ~(Coverage_assignment_L.Name.str.startswith('SR-'))]

No_assignment = Coverage_assignment_L[Coverage_assignment_L.Territory_ID.isna()]

### issue: computer cannot tell whether a SE is truly covering the entire district or put on a district during AE/SE ramp up period.
# replace SE assignment for those who is not carrying a territory quota, resolve the region/district into territories
temp = Coverage_assignment_L[(Coverage_assignment_L.Resource_Group == 'SE') & (Coverage_assignment_L.Level != 'Territory') & ~(Coverage_assignment_L.Level.isna())]

temp2 = pd.DataFrame()
for i in range(len(temp)):
    working_on_row = temp.index[i] 
    temp2 = temp2.append(expand_territory(temp.iloc[i],'Territory'))
    Coverage_assignment_L.drop([working_on_row], axis='rows', inplace=True) ##

extract_col = ['Name', 'Title', 'Resource_Group', 'HC_Status', 'EmployeeID', 'SFDC_UserID', 'Email', 'Manager', 'Territory_IDs', 'Quota_assignment']    
Coverage_assignment_L = Coverage_assignment_L.append(temp2[extract_col + list(TerritoryID_Master.columns)], sort="False")

temp = Coverage_assignment_L[(Coverage_assignment_L.Resource_Group == 'SEM') & (Coverage_assignment_L.Level != 'District') & ~(Coverage_assignment_L.Level.isna())]
temp2 = pd.DataFrame()
for i in range(len(temp)):
    working_on_row = temp.index[i] ##
    temp2 = temp2.append(expand_territory(temp.iloc[i],'District'))
    Coverage_assignment_L.drop([working_on_row], axis='rows', inplace=True) ##
   
Coverage_assignment_L = Coverage_assignment_L.append(temp2[extract_col + list(TerritoryID_Master.columns)], sort="False")

# Write the Coverage Assignment to a text file
#Coverage_assignment_L.to_csv(cfg.output_folder+'Coverage_Assignment_byName.txt', sep="|", index=False)
to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Coverage_assignment_byName']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

Coverage_assignment_L.to_sql('Coverage_assignment_byName', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)

''''''

# Make an output of Coverage_assignment by Territory
Coverage_assignment_L.fillna(" ", inplace=True) 
Coverage_assignment_W = pd.pivot_table(Coverage_assignment_L[['Name','Territory_ID','Resource_Group','EmployeeID','SFDC_UserID', 'Email', 'Manager']], \
                      index = 'Territory_ID', columns='Resource_Group', values=['Name','Email','EmployeeID','SFDC_UserID'], aggfunc=lambda x: ' | '.join(x))

new_name=[]
for i in Coverage_assignment_W.columns.levels[0]:
    for j in Coverage_assignment_W.columns.levels[1]:
        new_name.append(j + " " + i)
Coverage_assignment_W.columns = Coverage_assignment_W.columns.droplevel(0)
Coverage_assignment_W.columns=new_name
Coverage_assignment_W.drop(columns=['  Name','  Email','  EmployeeID','  SFDC_UserID'], inplace=True)

'''
check_dup = SE_org_coverage.duplicated(subset=['Territory_ID', 'Name'])
temp = SE_org_coverage.pivot(index = 'Territory_ID', columns = 'Name')
temp = SE_org_coverage.pivot(index = 'Territory_ID', columns = 'Resource_Group', values='Name')
'''

Coverage_assignment_W = Coverage_assignment_W[['Sales QBH Name','SE Name', 'Sales QBH Email', 'SE Email', 'SE EmployeeID', 'SE SFDC_UserID']].reset_index()
Coverage_assignment_W.rename(columns = {'Sales QBH Name' : 'Acct_Exec',
                                        'Sales QBH Email' : 'Acct_Exec_Email',
                                        'SE Name' : 'SE',
                                        'SE Email' : 'SE_Email',
                                        'SE EmployeeID' : 'SE_EmployeeID',
                                        'SE SFDC_UserID' : 'SE_SFDC_UserID'}, inplace=True)

# Write the Coverage Assignment to a text file
#Coverage_assignment_W.to_csv(cfg.output_folder+'Coverage_Assignment_byTerritory.txt', sep="|", index=False)

to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'Coverage_assignment_byTerritory']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

Coverage_assignment_W.to_sql('Coverage_assignment_byTerritory', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)

#------------------------------------------------------------------------------ 
# Read the individual quota information
# reading from Compensation team file
#SE_quota_W = quota_master[(quota_master.Group != 'Sales QBH') & (quota_master.Status=='Active')]\
#             [['Name','Group','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 'Year',
#               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]

#SE_quota_W = quota_master[(quota_master.Comp_Plan_Title.str.match('Systems Engineer*')) & (quota_master.Status=='Active')]\
#             [['Name','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 'Year',
#               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]

# reading from Anaplan data dump
#quota_master[(quota_master.Resource_Group.isin(['SE','SEM','SE Director','SE AVP']))]
SE_quota_W = quota_master[quota_master.Job_Family == 'Systems Engineering']\
             [['Name','Territory_IDs','Year', 'Resource_Group', 'EmployeeID', 'SFDC_UserID', 'Email',
               'M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 
               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]


# Un-pivot the SE quota information
SE_quota_L = pd.melt(SE_quota_W, id_vars=['Name', 'Resource_Group','Territory_IDs', 'EmployeeID', 'SFDC_UserID','Email','Year','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment'],
                     value_vars = ['M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned'],
                     var_name = 'Quarter', value_name = 'Quota')


rename_column = { 'M1_Theater' : 'Theater',
                  'M1_Super_Region' : 'Super_Region',
                  'M1_Region' : 'Region',
                  'M1_District' : 'District',
                  'M1_Segment' : 'Segment'}

SE_quota_L.rename(columns=rename_column, inplace=True)

relabel_quarters = {'M1_Q1_Quota_Assigned' : 'Q1',
                  'M1_Q2_Quota_Assigned' : 'Q2',
                  'M1_Q3_Quota_Assigned' : 'Q3',
                  'M1_Q4_Quota_Assigned' : 'Q4'}

for i in list(relabel_quarters.keys()):
    SE_quota_L.loc[SE_quota_L.Quarter==i,'Quarter'] = relabel_quarters[i]


#SE_quota_L.to_csv(cfg.output_folder+'SE_Quota.txt', sep="|", index=False)
to_sql_type = db_columns_types[db_columns_types.DB_TableName == 'SE_Org_Quota']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])


SE_quota_L.to_sql('SE_Org_Quota', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)

''' 
## dont' have the permission to drop table
server1 = 'PS-SQL-Dev02'
database1 = 'SalesOps_DM'
conn_str1 = create_engine('mssql+pyodbc://@' + server1 + '/' + database1 + '?driver=ODBC+Driver+13+for+SQL+Server') #work

SE_quota_L.to_sql('SE_Org_Quota', con=conn_str1, if_exists='replace', schema="dbo", index=False, dtype = data_type)
'''


# use cast([Quota] as decimal(15,2)) when reading from the database
                     
#------------------------------------------------------------------------------ 
# Create a report on SE assignment w.r.t SFDC sub-division 
# This is use to manage row visibility in Tableau. SFDC visibility is based on the Sub-division, (and add the Territory ID for SEs)
# Typically,
# SE AVP is assigned to a Theater, SE Director is assigned to Region, and SEM is assigned to District
# SFDC Sub-Division is mapped with District (~ roughly)
# SEM SFDC Sub-Division is the District coverage
# SE Director sub-division includes the District Territory IDs begin with the Region Territory ID
# SE AVP sub-division includes the District Territory IDs begin with the assigned Theater Territory ID
# 
# Reason for not using the Territory Naming Convention
# But the America has Direct Sales and ISO in the same district and different sub-division
# I have to loop through to find the direct report to determine the sub division(s) which a Manager has access
# SE covers 1 or multiple Territory IDs, thus I have loop using the L view
#------------------------------------------------------------------------------ 
#
# Step 1: Find Manager names of who has SEs reporting, pull the Sub_Divisions of the reporting SEs
SE_SubDivision_Permission = pd.DataFrame(columns = ['Name','Email','SFDC_UserID','Resource_Group','SFDC_Sub_Division','Manager'])

# find the 1st level Manager's name of who have SE reporting to 
Manager_of_SE = Coverage_assignment_L[Coverage_assignment_L.Resource_Group=='SE']['Manager']
Manager_of_SE = list(dict.fromkeys(Manager_of_SE))
Manager_of_SE = [x for x in Manager_of_SE if ((str(x) != 'nan') & (str(x) != 'NaN'))]


## Chris Farmand / Euguen someone are inside sales. and the territory is a direct sales. different from central where the inside sales is overlay

for i in Manager_of_SE:
    # find the sub-divisions of reporting SE and SE in Territory of (Account Quotas, FlashBlade, Direct Sales                 
    Sub_Division_List = pd.DataFrame(list(dict.fromkeys(Coverage_assignment_L[(Coverage_assignment_L.Manager == i) &
                                                                              (Coverage_assignment_L.Hierarchy.isin(['Account Quotas','FlashBlade','Direct Sales', 'Other Overlay']))]\
                                                                              ['SFDC_Sub_Division'])), columns=['SFDC_Sub_Division'])
    Sub_Division_List.dropna(inplace=True)
    if len(Sub_Division_List) > 0:   # for the SE Territory is not assigned a Sub_Division value
        temp = pd.concat([Quota_assignment_W.loc[Quota_assignment_W.Name==i,['Name','Email','SFDC_UserID','Resource_Group','Manager']]]*(len(Sub_Division_List)), ignore_index=True)
        temp = pd.concat([temp, Sub_Division_List], axis=1)      
        SE_SubDivision_Permission = SE_SubDivision_Permission.append(temp, sort=False)

SE_SubDivision_Permission = SE_SubDivision_Permission[(SE_SubDivision_Permission.SFDC_Sub_Division!=" ") & ~(SE_SubDivision_Permission.SFDC_Sub_Division.isna())]

# Step2: construct the sub-division list for SE Director and SE AVP
mgr_level = ['SEM','SE Director']
for i in mgr_level:
    # find the Manager's of the SEM and SE Director
    mgr_names = SE_SubDivision_Permission[ 
                                (SE_SubDivision_Permission.Resource_Group==i) &
                                (SE_SubDivision_Permission.Name.str.match('^[^SR-]*')) &
                                (SE_SubDivision_Permission.Name.str.match('^[^\d]*'))
                                ]['Manager']
    mgr_names = list(dict.fromkeys(mgr_names)) # create a dictionary from the list items as keys, then pull the keys from the dictionary
    
    # find the sub-divisions of the SEM reporting to the SE Director                 
    for j in mgr_names: 
    #mgr_names[:1]:        
        Sub_Division_List = pd.DataFrame(list(dict.fromkeys(SE_SubDivision_Permission[SE_SubDivision_Permission.Manager == j]['SFDC_Sub_Division'])), columns=['SFDC_Sub_Division'])
        if len(Sub_Division_List) == 0:
            print('bad') # need to add the code when the new manager has no reporting #I am too tired Mar 1, 2019
        
        # The SE Directors are reporting to Nathan Hall (interim for Zack Murphy)  who do have territory/quota assignment
        header = Quota_assignment_W.loc[Quota_assignment_W.Name==j,['Name','Email','SFDC_UserID','Resource_Group','Manager']]
        if j == "Nathan Hall" :
            header = pd.DataFrame([{'Name':'Nathan Hall', 'Email':'nhall@purestorage.com', 'SFDC_UserID':'0050z000006lcFnAAI', 'Resource_Group':'SE AVP', 'Manager':'Alex McMullan'}])
        
        #[Quota_assignment_W.loc[Quota_assignment_W.Name==j,['Name','Email','SFDC_UserID','Resource_Group','Manager']]]
        temp = pd.concat([header]*(len(Sub_Division_List)), ignore_index=True)
        temp = pd.concat([temp, Sub_Division_List], axis=1)
        SE_SubDivision_Permission = SE_SubDivision_Permission.append(temp, sort=False)
        
    SE_SubDivision_Permission = SE_SubDivision_Permission[(SE_SubDivision_Permission.SFDC_Sub_Division!=" ") & ~(SE_SubDivision_Permission.SFDC_Sub_Division.isna())]


#remove the duplicates. They are there when a for example SE Director has SE and SEM reporting him.
SE_SubDivision_Permission.drop_duplicates(subset=['SFDC_UserID', 'SFDC_Sub_Division'], keep='first', inplace=True)

# Step 3: adding exception cases: Users in the supporting organization and needed access
# dictionary values: email, name, resource group, manager, copy from who
extra_users = { 'April Liu' : ['aliu@purestorage.com','SE Support', 'Manager', ['Carl McQuillan', 'Nathan Hall','Mark Jobbins','Mike Canavan']],
                'Shawn Rosemarin' : ['srosemarin@purestorage.com', 'SE Support', 'Manager', ['Nathan Hall']],
                'Dustin Vo' :['dustin@purestorage.com','SE Support','Manager', ['Nathan Hall']]
              }

for i in list(extra_users.keys()) :
    for j in range(0, len(extra_users[i][3])):
        temp = SE_SubDivision_Permission[SE_SubDivision_Permission.Name == extra_users[i][3][j]].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.Resource_Group = extra_users[i][1]
        temp.Manager = extra_users[i][2]
    
        SE_SubDivision_Permission = SE_SubDivision_Permission.append(temp)

SE_SubDivision_Permission.rename(columns={'Email':'User', 'SFDC_Sub_Division':'Sub_Division'}, inplace=True)

# get the unique district values with region, super-region, theater
temp_master = pd.pivot_table(data=TerritoryID_Master, index=['SFDC_Sub_Division','SFDC_Division','SFDC_Theater'], values = ['Territory'], aggfunc='count').rename(columns={'Territory':'No. of Territory'})
#temp_master = pd.pivot_table(data=TerritoryID_Master, index=['District','Region','Super_Region','Theater'], values = ['Territory'], aggfunc='count').rename(columns={'Territory':'No. of Territory'})
temp_master.reset_index(inplace=True)
temp_master.rename(columns={'SFDC_Sub_Division':'Sub_Division','SFDC_Division':'Division','SFDC_Theater':'Theater'}, inplace=True)

SE_SubDivision_Permission = pd.merge(SE_SubDivision_Permission, temp_master, how='left', left_on='Sub_Division', right_on='Sub_Division')

#SE_org_coverage.to_csv(cfg.output_folder+'SE_SubDivision_Permission.txt', sep="|", index=False)
to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_SubDivision_Permission']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

SE_SubDivision_Permission.to_sql('SE_SubDivision_Permission', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)


#------------------------------------------------------------------------------ 
# Step 1: Find the SEs reporting to a SEM, pull the Divisions the SEM have access to
#------------------------------------------------------------------------------ 
SE_District_Permission = pd.DataFrame(columns = ['Name','Email','SFDC_UserID','Resource_Group','District','Manager'])

# find the Manager's name of who have SE reporting to 
Manager_of_SE = Coverage_assignment_L[Coverage_assignment_L.Resource_Group=='SE']['Manager']
Manager_of_SE = list(dict.fromkeys(Manager_of_SE))
Manager_of_SE = [x for x in Manager_of_SE if ((str(x) != 'nan') & (str(x) != 'NaN'))]

for i in Manager_of_SE:
    # find the District of reporting SE                 
    District_List = pd.DataFrame(list(dict.fromkeys(Coverage_assignment_L[(Coverage_assignment_L.Manager == i) &
                                                                          (Coverage_assignment_L.Hierarchy.isin(['Account Quotas','FlashBlade','Direct Sales', 'Other Overlay']))] \
                                                                          ['District'])), columns=['District'])
    District_List.dropna(inplace=True)
    if len(District_List) > 0:   # for the SE Territory is not assigned a Sub_Division value
        temp = pd.concat([Quota_assignment_W.loc[Quota_assignment_W.Name==i,['Name','Email','SFDC_UserID','Resource_Group','Manager']]]*(len(District_List)), ignore_index=True)
        temp = pd.concat([temp, District_List], axis=1)      
        SE_District_Permission = SE_District_Permission.append(temp, sort=False)

SE_District_Permission = SE_District_Permission[(SE_District_Permission.District!=" ") & ~(SE_District_Permission.District.isna())]

# Step2: construct the division list for SE Director and SE AVP
mgr_level = ['SEM','SE Director']
for i in mgr_level:
    # find the Manager's of the SEM and SE Director
    mgr_names = SE_District_Permission[ 
                                (SE_District_Permission.Resource_Group==i) &
                                (SE_District_Permission.Name.str.match('^[^SR-]*')) &
                                (SE_District_Permission.Name.str.match('^[^\d]*'))
                                ]['Manager']
    mgr_names = list(dict.fromkeys(mgr_names)) # create a dictionary from the list items as keys, then pull the keys from the dictionary
    
    # find the sub-divisions of the SEM reporting to the SE Director                 
    for j in mgr_names:        
        District_List = pd.DataFrame(list(dict.fromkeys(SE_District_Permission[SE_District_Permission.Manager == j]['District'])), columns=['District'])
        if len(District_List) == 0:
            print('bad') # need to add the code when the new manager has no reporting #I am too tired Mar 1, 2019

        # The SE Directors are reporting to Nathan Hall (interim for Zack Murphy)  who do have territory/quota assignment
        header = Quota_assignment_W.loc[Quota_assignment_W.Name==j,['Name','Email','SFDC_UserID','Resource_Group','Manager']]
        if j == "Nathan Hall" :
            header = pd.DataFrame([{'Name':'Nathan Hall', 'Email':'nhall@purestorage.com', 'SFDC_UserID':'0050z000006lcFnAAI', 'Resource_Group':'SE AVP', 'Manager':'Alex McMullan'}])
            
        temp = pd.concat([header]*(len(District_List)), ignore_index=True)
        temp = pd.concat([temp, District_List], axis=1)
        SE_District_Permission = SE_District_Permission.append(temp, sort=False)
        
    SE_District_Permission = SE_District_Permission[(SE_District_Permission.District!=" ") & ~(SE_District_Permission.District.isna())]

#remove the duplicates. They are there when a for example SE Director has SE and SEM reporting him.
SE_District_Permission.drop_duplicates(subset=['SFDC_UserID', 'District'], keep='first', inplace=True)


# Step 3: adding exception cases: Users in the supporting organization and needed access
# dictionary values: email, name, resource group, manager, copy from who
extra_users = { 'April Liu' : ['aliu@purestorage.com','SE Support', 'Manager', ['Carl McQuillan', 'Nathan Hall','Mark Jobbins','Mike Canavan']],
                'Shawn Rosemarin' : ['srosemarin@purestorage.com', 'SE Support', 'Manager', ['Nathan Hall']],
                'Dustin Vo' :['dustin@purestorage.com','SE Support','Manager', ['Nathan Hall']]
              }

for i in list(extra_users.keys()) :
    for j in range(0, len(extra_users[i][3])):
        temp = SE_District_Permission[SE_District_Permission.Name == extra_users[i][3][j]].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.Resource_Group = extra_users[i][1]
        temp.Manager = extra_users[i][2]
    
        SE_District_Permission = SE_District_Permission.append(temp)
                
SE_District_Permission.rename(columns={'Email':'User'}, inplace=True)
#SE_District_Permission.to_csv(cfg.output_folder+'SE_District_Permission.txt', sep="|", index=False)

# get the unique district values with region, super-region, theater
temp_master = pd.pivot_table(data=TerritoryID_Master, index=['District','Region','Super_Region','Theater'], values = ['Territory'], aggfunc='count').rename(columns={'Territory':'No. of Territory'})
temp_master.reset_index(inplace=True)

SE_District_Permission = pd.merge(SE_District_Permission, temp_master, how='left', left_on='District', right_on='District')

to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_District_Permission']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])

SE_District_Permission.to_sql('SE_District_Permission', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype=data_type)


##########################################################################################
# Step 1: Find Manager names of who has SEs reporting, pull the Sub_Divisions of the reporting SEs
SE_Subordinate_Permission = pd.DataFrame(columns = ['Name','Email','SFDC_UserID','Resource_Group','Subordinate','Manager'])

# find the 1st level Manager's name of who have SE reporting to 
Manager_of_SE = Coverage_assignment_L[Coverage_assignment_L.Resource_Group=='SE']['Manager']
Manager_of_SE = list(dict.fromkeys(Manager_of_SE))
Manager_of_SE = [x for x in Manager_of_SE if ((str(x) != 'nan') & (str(x) != 'NaN'))]

for i in Manager_of_SE:
    # find the sub-divisions of reporting SE and SE in Territory of (Account Quotas, FlashBlade, Direct Sales                 
    Subordinate_List = pd.DataFrame(list(dict.fromkeys(Coverage_assignment_L[(Coverage_assignment_L.Manager == i) &
                                                                              (Coverage_assignment_L.Hierarchy.isin(['Account Quotas','FlashBlade','Direct Sales', 'Other Overlay']))]\
                                                                              ['Name'])), columns=['Subordinate'])
    Subordinate_List.dropna(inplace=True)
    if len(Subordinate_List) > 0:   # for the SE Territory is not assigned a Sub_Division value
        temp = pd.concat([Quota_assignment_W.loc[Quota_assignment_W.Name==i,['Name','Email','SFDC_UserID','Resource_Group','Manager']]]*(len(Subordinate_List)), ignore_index=True)
        temp = pd.concat([temp, Subordinate_List], axis=1)      
        SE_Subordinate_Permission = SE_Subordinate_Permission.append(temp, sort=False)

SE_Subordinate_Permission = SE_Subordinate_Permission[(SE_Subordinate_Permission.Subordinate!=" ") & ~(SE_Subordinate_Permission.Subordinate.isna())]

# Step2: construct the sub-division list for SE Director and SE AVP
mgr_level = ['SEM','SE Director']
for i in mgr_level:
    # find the Manager's of the SEM and SE Director
    mgr_names = SE_Subordinate_Permission[ 
                                (SE_Subordinate_Permission.Resource_Group==i) &
                                (SE_Subordinate_Permission.Name.str.match('^[^SR-]*')) &
                                (SE_Subordinate_Permission.Name.str.match('^[^\d]*'))
                                ]['Manager']
    mgr_names = list(dict.fromkeys(mgr_names)) # create a dictionary from the list items as keys, then pull the keys from the dictionary
    
    # find the sub-divisions of the SEM reporting to the SE Director                 
    for j in mgr_names: 
    #mgr_names[:1]:        
        Subordinate_List = pd.DataFrame(list(dict.fromkeys(SE_Subordinate_Permission[SE_Subordinate_Permission.Manager == j]['Subordinate'])), columns=['Subordinate'])
        if len(Subordinate_List) == 0:
            print('bad') # need to add the code when the new manager has no reporting #I am too tired Mar 1, 2019
        
        # The SE Directors are reporting to Nathan Hall (interim for Zack Murphy)  who do have territory/quota assignment
        header = Quota_assignment_W.loc[Quota_assignment_W.Name==j,['Name','Email','SFDC_UserID','Resource_Group','Manager']]
        if j == "Nathan Hall" :
            header = pd.DataFrame([{'Name':'Nathan Hall', 'Email':'nhall@purestorage.com', 'SFDC_UserID':'0050z000006lcFnAAI', 'Resource_Group':'SE AVP', 'Manager':'Alex McMullan'}])
        
        #[Quota_assignment_W.loc[Quota_assignment_W.Name==j,['Name','Email','SFDC_UserID','Resource_Group','Manager']]]
        temp = pd.concat([header]*(len(Subordinate_List)), ignore_index=True)
        temp = pd.concat([temp, Subordinate_List], axis=1)
        SE_Subordinate_Permission = SE_Subordinate_Permission.append(temp, sort=False)
        
    SE_Subordinate_Permission = SE_Subordinate_Permission[(SE_Subordinate_Permission.Subordinate!=" ") & ~(SE_Subordinate_Permission.Subordinate.isna())]


#remove the duplicates. They are there when a for example SE Director has SE and SEM reporting him.
SE_Subordinate_Permission.drop_duplicates(subset=['SFDC_UserID', 'Subordinate'], keep='first', inplace=True)

# Step 3: adding exception cases: Users in the supporting organization and needed access
# dictionary values: email, name, resource group, manager, copy from who
extra_users = { 'April Liu' : ['aliu@purestorage.com','SE Support', 'Manager', ['Carl McQuillan', 'Nathan Hall','Mark Jobbins','Mike Canavan']],
                'Shawn Rosemarin' : ['srosemarin@purestorage.com', 'SE Support', 'Manager', ['Carl McQuillan', 'Nathan Hall','Mark Jobbins','Mike Canavan']],
                'Thomas Waung' : ['twaung@purestorage.com', 'SE Support', 'Manager', ['Carl McQuillan', 'Nathan Hall','Mark Jobbins','Mike Canavan']],
                'Dustin Vo' :['dustin@purestorage.com','SE Support','Manager', ['Nathan Hall']]
              }

for i in list(extra_users.keys()) :
    for j in range(0, len(extra_users[i][3])):
        temp = SE_Subordinate_Permission[SE_Subordinate_Permission.Name == extra_users[i][3][j]].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.Resource_Group = extra_users[i][1]
        temp.Manager = extra_users[i][2]
    
        SE_Subordinate_Permission = SE_Subordinate_Permission.append(temp)

SE_Subordinate_Permission.rename(columns={'Email':'User'}, inplace=True)

## needing the subordinate roles, territory
temp_master = quota_master[quota_master.Job_Family.isin(['Systems Engineering', 'Inside Sales'])]\
                [['Name','EmployeeID','SFDC_UserID','Resource_Group','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District', 'M1_Segment']]
temp_master.rename(columns = {'M1_Theater':'Theater',
                              'M1_Super_Region' : 'Super_Region',
                              'M1_Region' : 'Region',
                              'M1_District' : 'District',
                              'M1_Segment' : 'Segment',
                              'Resource_Group' : 'Subordinate_Resource_Group',
                              'Name' : 'Subordinate',
                              'SFDC_UserID' : 'Subordinate_SFDC_UserId'}, inplace=True)

SE_Subordinate_Permission = pd.merge(SE_Subordinate_Permission[['Name', 'User', 'SFDC_UserID', 'Resource_Group', 'Subordinate']], temp_master, how='left', on='Subordinate').sort_values(by = ['Name', 'Subordinate'])

'''
# get the unique district values with region, super-region, theater
temp_master = pd.pivot_table(data=TerritoryID_Master, index=['SFDC_Sub_Division','SFDC_Division','SFDC_Theater'], values = ['Territory'], aggfunc='count').rename(columns={'Territory':'No. of Territory'})
#temp_master = pd.pivot_table(data=TerritoryID_Master, index=['District','Region','Super_Region','Theater'], values = ['Territory'], aggfunc='count').rename(columns={'Territory':'No. of Territory'})
temp_master.reset_index(inplace=True)
temp_master.rename(columns={'SFDC_Sub_Division':'Sub_Division','SFDC_Division':'Division','SFDC_Theater':'Theater'}, inplace=True)

SE_SubDivision_Permission = pd.merge(SE_SubDivision_Permission, temp_master, how='left', left_on='Sub_Division', right_on='Sub_Division')
'''
#SE_org_coverage.to_csv(cfg.output_folder+'SE_SubDivision_Permission.txt', sep="|", index=False)

to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_Subordinate_Permission']

data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
    
SE_Subordinate_Permission.to_sql('SE_Subordinate_Permission', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)



print('I am so done')
             
''' notes for multi level column header
#Territory_assignment[Territory_assignment.index.get_level_values('Territory_ID') == 'WW_AMS_COM_CEN_IWC_006']
Territory_assignment.loc[:, (slice(None),('Sales QBH','SE'))][:3]
Territory_assignment.loc['WW_AMS_COM_CEN_IWC_006', (slice(None),('Sales QBH','SE'))][:3]
Territory_assignment.loc['WW_AMS_COM_CEN_IWC_006', (slice(),('Sales QBH','SE'))][:3]
idx=pd.IndexSlice
Territory_assignment.loc[idx[:],idx[:, ('Sales QBH','SE')]][:3] # select everything by row index, column Name: select everything of name level 1, name level 2(resource group) = Sales QBH and SE 
#Territory_assignment[['Name']][:3]
#Territory_assignment[['SFDC_UserID']][:3]

temp = Territory_assignment.loc[:, (slice(None),('Sales QBH','SE'))].reindex()[:3]

'''


'''
check = Coverage_assignment_L
for x in ID_Master.columns:
    if ID_Master[x].dtypes == "O":
        print (x + '  ' + str(max(ID_Master[x].str.len())))
'''