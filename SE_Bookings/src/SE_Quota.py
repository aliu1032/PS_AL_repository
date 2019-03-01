'''
Created on Jan 11, 2019

@author: aliu
'''

import project_config as cfg
import pandas as pd

#===============================================================================
# Read the Date to PS Quarter mapping
#===============================================================================
from getData import get_Period_map
Date_Period = get_Period_map(0)

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

#------------------------------------------------------------------------------ 
# Since the SE Mgr covers the entire Region, AnaPlan assign the SE Mgr to a Region.
# The quota amount is less than assigning the Mgr to all Districts in a Region
# For report, need to breakout into region id into district ids
# John Bradley : replace 'WW_GLB_MSP_MSP' with 'WW_GLB_MSP_MSP_MSP; WW_GLB_MSP_MSP_TEL'
# SR-10115_SE Mgmt_Canada SEM : replace 'WW_AMS_COM_CAD' with 'WW_AMS_COM_CAD_CAD; WW_AMS_COM_CAD_TOR'
#------------------------------------------------------------------------------ 

a = quota_master[quota_master.Name == 'SR-10115_SE Mgmt_Canada SEM']['Territory_IDs']
b = a.str.replace("WW_AMS_COM_CAD", "WW_AMS_COM_CAD_CAD; WW_AMS_COM_CAD_TOR")
quota_master.loc[quota_master.Name == 'SR-10115_SE Mgmt_Canada SEM','Territory_IDs'] = b

a = quota_master[quota_master.Name == 'John Bradley']['Territory_IDs']
b = a.str.replace('WW_GLB_MSP_MSP', 'WW_GLB_MSP_MSP_MSP; WW_GLB_MSP_MSP_TEL')
quota_master.loc[quota_master.Name == 'John Bradley','Territory_IDs'] = b

# fill the Blank Coverage Assignment ID to 'No Plan / No Coverage'

#-----------------Create report to show the SE assignment , SE to AE mapping, using Anaplan coverage information--------
# Read the Territory assignment, Create a Long view for Tableau report
Territory_assignment_W = quota_master[['Name', 'Title','Resource_Group','HC_Status', 'Email','Manager','Territory_IDs']]
Territory_assignment_W.Territory_IDs.fillna("",inplace=True)
len_header = len(Territory_assignment_W.columns)


# Split the multiple territory coverage into columns
temp = Territory_assignment_W['Territory_IDs'].str.split(';', expand=True)
Territory_assignment_W = pd.merge(Territory_assignment_W, temp, how='left', left_index=True, right_index=True)

Coverage_Col = Territory_assignment_W.columns[len_header:]
for i in Coverage_Col:
    Territory_assignment_W[i] = Territory_assignment_W[i].str.strip()
    ## add the code to clean up the territory id to only include the XXX_XXX_XXX part

# Un-pivot the Territory IDs
Territory_assignment_L = pd.melt(Territory_assignment_W, id_vars=['Name','Title','Resource_Group', 'HC_Status', 'Email', 'Manager','Territory_IDs'], value_vars = Coverage_Col,
                var_name = 'Coverage_Area_', value_name = 'Territory_ID')
Territory_assignment_L = Territory_assignment_L[~(Territory_assignment_L.Territory_ID.isnull())] #clean the null data

Territory_assignment_L = pd.merge(Territory_assignment_L, TerritoryID_Master, how='left', left_on='Territory_ID', right_on='Territory_ID')
Territory_assignment_L.sort_values(by=['Territory_ID','Name'], inplace=True)

# Write the Territory Assignment to a text file
Territory_assignment_L.to_csv(cfg.output_folder+'Territory_Assignment_Anaplan.txt', sep="|", index=False)

                        
#------ Create a report on SE assignment w.r.t SFDC sub-division --------------------------------------
# Typically,
# SE AVP is assigned to a Theater, SE Director is assigned to Region, and SEM is assigned to District
# SFDC Sub-Division is mapped with District (~ roughly)
# SEM SFDC Sub-Division is the District coverage
# SE Director sub-division includes the District Territory IDs begin with the Region Territory ID
# SE AVP sub-division includes the District Territory IDs begin with the assigned Theater Territory ID
#
# But the America has Direct Sales and ISO in the same district and different sub-division
# I have to loop through to find the direct report to determine the sub division(s) which a Manager has access
# SE covers 1 or multiple Territory IDs, thus I have loop using the L view
#------------------------------------------------------------------------------------------------------- 

# create an new dataframe to host the information
# it has the Name, email, Sub-Division
mgr_level = ['SEM']  # how to do SE specialist? they are assigned at different levels, #'SE Director','SE AVP'
SE_org_coverage = pd.DataFrame(columns = ['Name','Email','Resource_Group','Sub_Division','Manager'])


for i in mgr_level:
    # find the SEM's names
    mgr_names = Territory_assignment_L[(Territory_assignment_L.Theater=='Americas Theater') & 
                       (Territory_assignment_L.Resource_Group==i) & 
                       ~(Territory_assignment_L.Name.str.match('SR-*')) & 
                       ~(Territory_assignment_L.Name.str.match('^\d'))]['Name']
    mgr_names = list(dict.fromkeys(mgr_names)) # create a dictionary from the list items as keys, then pull the keys from the dictionary
    
    # find the sub-divisions reporting to the SEMs                 
    for j in mgr_names:        
        Sub_Division_List = pd.DataFrame(list(dict.fromkeys(Territory_assignment_L[Territory_assignment_L.Manager == j]['Sub_Division'])), columns=['Sub_Division'])
        if len(Sub_Division_List) == 0:  # new manager with no reporting
            Sub_Division_List = Territory_assignment_L[(Territory_assignment_L.Territory_ID.str.contains(Territory_assignment_L[Territory_assignment_L.Name == j]['Territory_ID'].values[0])) &
                                                       ~(Territory_assignment_L.Sub_Division.isnull())]['Sub_Division'][:1]
            
        temp = pd.concat([Territory_assignment_W.loc[Territory_assignment_W.Name==j,['Name','Email','Resource_Group','Manager']]]*(len(Sub_Division_List)), ignore_index=True)
        temp = pd.concat([temp, Sub_Division_List], axis=1)      
        SE_org_coverage = SE_org_coverage.append(temp, sort=False)


# remove the blank Sub_Division
SE_org_coverage = SE_org_coverage[~SE_org_coverage.Sub_Division.isnull()]
SE_org_coverage = pd.merge(SE_org_coverage,
                           TerritoryID_Master[(TerritoryID_Master.Theater=='Americas Theater') & ~(TerritoryID_Master.Sub_Division.isnull())][['Sub_Division','Theater','Region','District']],
                           how='left', left_on='Sub_Division', right_on='Sub_Division')
# for SEM whoes assignment is not at the district level, the Sub_Divsion cannot join
#------------------------------------------------------------------------------ 
# construct the sub-division list for SE Director and SE AVP
mgr_level = ['SEM','SE Director']

for i in mgr_level:
    # find the Manager's of the SEM and SE Director
    mgr_names = SE_org_coverage[(SE_org_coverage.Theater=='Americas Theater') & 
                                (SE_org_coverage.Resource_Group==i) &
                                (SE_org_coverage.Name.str.match('^[^SR-]*')) &
                                (SE_org_coverage.Name.str.match('^[^\d]*'))
                                ]['Manager']
    mgr_names = list(dict.fromkeys(mgr_names)) # create a dictionary from the list items as keys, then pull the keys from the dictionary
    
    # find the sub-divisions of the SEM reporting to the SE Director                 
    for j in mgr_names:        
        Sub_Division_List = pd.DataFrame(list(dict.fromkeys(SE_org_coverage[SE_org_coverage.Manager == j]['Sub_Division'])), columns=['Sub_Division'])
        if len(Sub_Division_List) == 0:
            print('bad') # need to add the code when the new manager has no reporting #I am too tired Mar 1, 2019
            
        temp = pd.concat([Territory_assignment_W.loc[Territory_assignment_W.Name==j,['Name','Email','Resource_Group','Manager']]]*(len(Sub_Division_List)), ignore_index=True)
        temp = pd.concat([temp, Sub_Division_List], axis=1)
        temp = pd.merge(temp,TerritoryID_Master[(TerritoryID_Master.Theater=='Americas Theater') & ~(TerritoryID_Master.Sub_Division.isnull())][['Sub_Division','Theater','Region','District']],
                           how='left', left_on='Sub_Division', right_on='Sub_Division')
        SE_org_coverage = SE_org_coverage.append(temp, sort=False)


SE_org_coverage = SE_org_coverage[~(SE_org_coverage.Name.isnull())]
SE_org_coverage.to_csv(cfg.output_folder+'SE_Hierarchy_2020.txt', sep="|", index=False)

'''
#-----------------Code using Override Territory IDs if needed -------------------------------------------------------------
#Populate the Anaplan Id to override column
quota_master.loc[(quota_master.Override_Territory_IDs.isna()),'Override_Territory_IDs'] = quota_master.Territory_IDs

Territory_assignment_W = quota_master[['Name', 'Title', 'Resource_Group','HC_Status', 'Manager','Override_Territory_IDs']]
Territory_assignment_W.Override_Territory_IDs.fillna("",inplace=True)
len_header = len(Territory_assignment_W.columns)

# Split the multiple territory coverage into columns
temp = Territory_assignment_W['Override_Territory_IDs'].str.split(';', expand=True)
Territory_assignment_W = pd.merge(Territory_assignment_W, temp, how='left', left_index=True, right_index=True)

Coverage_Col = Territory_assignment_W.columns[len_header:]
for i in Coverage_Col:
    Territory_assignment_W[i] = Territory_assignment_W[i].str.strip()
    ## add the code to clean up the territory id to only include the XXX_XXX_XXX part

# Un-pivot the Territory IDs
Territory_assignment_L = pd.melt(Territory_assignment_W, id_vars=['Name','Title','Resource_Group', 'HC_Status', 'Manager','Override_Territory_IDs'], value_vars = Coverage_Col,
                var_name = 'Coverage_Area_', value_name = 'Territory_ID')
Territory_assignment_L = Territory_assignment_L[~(Territory_assignment_L.Territory_ID.isnull())] #clean the null data

Territory_assignment_L = pd.merge(Territory_assignment_L, TerritoryID_Master, how='left', left_on='Territory_ID', right_on='Territory_ID')
Territory_assignment_L.sort_values(by=['Territory_ID','Name'], inplace=True)

# Write the Territory Assignment to a text file
Territory_assignment_L.to_csv(cfg.output_folder+'Territory_Assignment_w_Override.txt', sep="|", index=False)
'''

#------------------------------------------------------------------------------ 
# Read the individual quota information
#SE_quota_W = quota_master[(quota_master.Group != 'Sales QBH') & (quota_master.Status=='Active')]\
#             [['Name','Group','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 'Year',
#               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]

SE_quota_W = quota_master[(quota_master.Comp_Plan_Title.str.match('Systems Engineer*')) & (quota_master.Status=='Active')]\
             [['Name','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 'Year',
               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]


# Un-pivot the SE quota information
SE_quota_L = pd.melt(SE_quota_W, id_vars=['Name', 'Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment', 'Year'],
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

SE_quota_L.to_csv(cfg.output_folder+'SE_Quota.txt', sep="|", index=False)

'''
#===============================================================================
# Read Opportunity Data from SFDC
#===============================================================================
from getData import get_SFDC_Oppt

Oppt = get_SFDC_Oppt(1)
Oppt.CloseDate = pd.to_datetime(Oppt.CloseDate, format="%Y-%m-%d",errors='coerce')
Oppt = pd.merge(Oppt, Date_Period, how='left', left_on = 'CloseDate', right_on='Date') #add quarter field to the table


# group the opportunity by AE/AE_Territory Id, Quarter + ForecastCategory
Territory_Qtrly_Pipeline = pd.pivot_table(Oppt, index = ['Acct_Exec', 'Territory_ID', 'Period', 'Quarter', 'Year','ForecastCategoryName'], values=['Amount'], aggfunc=['sum']).reset_index()
Territory_Qtrly_Pipeline.columns = Territory_Qtrly_Pipeline.columns.droplevel(1)

sel_row = ['FQ1 FY 2020', 'FQ2 FY 2020', 'FQ3 FY 2020', 'FQ4 FY 2020']
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[Territory_Qtrly_Pipeline.Period.isin(sel_row)]

#===============================================================================
# Left join Oppt with SE_Quota to find the associated SE(s) to a Opportunity Territory
# of the Opportunity using Opportunity Owner's Territory Id
#===============================================================================
# Bring in the SE(s) assigned to the opportunity territory by merging with the Territory Id
Territory_Pipeline_SEQuota = pd.merge(Territory_Qtrly_Pipeline, Territory_assignment_L, how = 'left', left_on=['Territory_ID'], right_on=['Territory_ID'])
# Bring in the SE quota by merging with SE name
Territory_Pipeline_SEQuota = pd.merge(Territory_Pipeline_SEQuota, SE_quota_L[['Name','Quarter','Quota']], how = 'left', left_on=['Name','Quarter'], right_on=['Name', 'Quarter'])
Territory_Pipeline_SEQuota = Territory_Pipeline_SEQuota[Territory_Pipeline_SEQuota.ForecastCategoryName != 'Omitted']


Territory_Pipeline_temp = Territory_Qtrly_Pipeline[['Territory_ID', 'Quarter','ForecastCategoryName','sum']]
Territory_Pipeline_temp = pd.merge(Territory_Pipeline_temp, Territory_assignment_L, how = 'left', left_on=['Territory_ID'], right_on=['Territory_ID'])

Territory_Pipeline_temp1 = Territory_Pipeline_temp[['Name','Territory_ID','Theater','Super_Region','Region','District','Segment','Quarter','ForecastCategoryName','sum']]
SE_quota_L_temp1 = SE_quota_L[['Name','Territory_IDs','Theater','Super_Region','Region','District','Segment','Quarter','Quota']]
SE_quota_L_temp1['ForecastCategoryName'] = 'Quota'
SE_quota_L_temp1.rename(columns={'Territory_IDs':'Territory_ID', 'Quota':'sum'}, inplace=True)

Territory_Pipeline_Quota_L = Territory_Pipeline_temp.append(SE_quota_L_temp1, sort = 'Name', ignore_index=False)
Territory_Pipeline_Quota_L1 = pd.pivot_table(Territory_Pipeline_Quota_L, index=['Name','Quarter','Theater','Region','District'], columns=['ForecastCategoryName'], values='sum' )


Territory_Pipeline_Quota_L1.to_csv(cfg.output_folder+'Territory_Pipeline_Quota_LONG.txt', sep="|", index=True)
#===============================================================================
# Write the output dataset
#===============================================================================
Territory_Pipeline_SEQuota.to_csv(cfg.output_folder+'Territory_Pipeline_Quota.txt', sep="|", index=False)

'''

#===============================================================================
# Read Opportunity with Split data from SFDC
#===============================================================================

from getData import get_SFDC_Oppt_Split
Oppt = get_SFDC_Oppt_Split(1)

Oppt.CloseDate = pd.to_datetime(Oppt.CloseDate, format="%Y-%m-%d",errors='coerce')
Oppt = pd.merge(Oppt, Date_Period, how='left', left_on = 'CloseDate', right_on='Date') #add quarter field to the table

# group the opportunity by Oppt_Split_User, Oppt_Split_User_Territory_Id, Quarter + ForecastCategory
# question: do all commissioned user has opportunity id? how about new hirer?
# what is the process to load AE territory id into SFDC? impact, cannot rely on SFDC for territory id if the process is unreliable
# question: if AE receive a split, does the assigned SE receive a split?
Territory_Qtrly_Pipeline = pd.pivot_table(Oppt, index = ['Oppt_Split_User', 'Oppt_Split_User_Territory_Id', 'Period', 'Quarter', 'Year','ForecastCategoryName'],
                                          values=['SplitAmount'], aggfunc=['sum']).reset_index()
Territory_Qtrly_Pipeline.columns = Territory_Qtrly_Pipeline.columns.droplevel(1)

sel_row = ['FQ1 FY 2020', 'FQ2 FY 2020', 'FQ3 FY 2020', 'FQ4 FY 2020']
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[Territory_Qtrly_Pipeline.Period.isin(sel_row)]

#===============================================================================
# Left join Oppt with SE_Quota to find the associated SE(s) to a Opportunity Territory
# of the Opportunity using Opportunity Owner's Territory Id
#===============================================================================
# Bring in the SE(s) assigned to the opportunity territory by merging with the Territory Id
Territory_Pipeline_SEQuota = pd.merge(Territory_Qtrly_Pipeline, Territory_assignment_L, how = 'left', left_on=['Oppt_Split_User_Territory_Id'], right_on=['Territory_ID'])
# Bring in the SE quota by merging with SE name
Territory_Pipeline_SEQuota = pd.merge(Territory_Pipeline_SEQuota, SE_quota_L[['Name','Quarter','Quota']], how = 'left', left_on=['Name','Quarter'], right_on=['Name', 'Quarter'])
Territory_Pipeline_SEQuota = Territory_Pipeline_SEQuota[Territory_Pipeline_SEQuota.ForecastCategoryName != 'Omitted']


Territory_Pipeline_temp = Territory_Qtrly_Pipeline[['Oppt_Split_User_Territory_Id', 'Quarter','ForecastCategoryName','sum']]
Territory_Pipeline_temp = pd.merge(Territory_Pipeline_temp, Territory_assignment_L, how = 'left', left_on=['Oppt_Split_User_Territory_Id'], right_on=['Territory_ID'])

Territory_Pipeline_temp1 = Territory_Pipeline_temp[['Name','Oppt_Split_User_Territory_Id','Theater','Super_Region','Region','District','Segment','Quarter','ForecastCategoryName','sum']]
SE_quota_L_temp1 = SE_quota_L[['Name','Territory_IDs','Theater','Super_Region','Region','District','Segment','Quarter','Quota']]
SE_quota_L_temp1['ForecastCategoryName'] = 'Quota'
SE_quota_L_temp1.rename(columns={'Territory_IDs':'Territory_ID', 'Quota':'sum'}, inplace=True)

Territory_Pipeline_Quota_L = Territory_Pipeline_temp.append(SE_quota_L_temp1, sort = 'Name', ignore_index=False)
Territory_Pipeline_Quota_L1 = pd.pivot_table(Territory_Pipeline_Quota_L, index=['Name','Quarter','Theater','Region','District'], columns=['ForecastCategoryName'], values='sum' )


Territory_Pipeline_Quota_L1.to_csv(cfg.output_folder+'Territory_Pipeline_Quota_LONG.txt', sep="|", index=True)


### yet to add Flashblade Bookings. Look for FA AE name on the Flashblade deal
### double check if the FB deal is retiring quota or only extra commission

