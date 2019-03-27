'''
Created on Jan 11, 2019

@author: aliu
'''

import project_config as cfg
import pandas as pd

#===============================================================================
# Read the Date to PS Quarter mapping
#===============================================================================
from getData import get_Period_map, get_SFDC_Oppt
Date_Period = get_Period_map(0)

#===============================================================================
# Read the Territory ID master
#===============================================================================
from getData import get_TerritoryID_Master
TerritoryID_Master = get_TerritoryID_Master(1)

#===============================================================================
# Read the SE Territory Coverage
#===============================================================================
SE_org_coverage_byTerritory = pd.read_csv(cfg.output_folder + 'Coverage_Assignment_byTerritory.txt', delimiter = '|', header=0)
SE_org_coverage_byName = pd.read_csv(cfg.output_folder + 'Coverage_Assignment_byName.txt', delimiter = '|', header=0)

#===============================================================================
# Read Opportunity with Split data from SFDC
# Quota Retired Opportunity are those who AE's territory match the SE's territory
# BCR/Temp Coverage are Opportunity where the SE's territory is not the Opportunity blah blah
#===============================================================================

from getData import get_SFDC_Oppt_Split
Oppt_Split = get_SFDC_Oppt_Split(1)

# adding the Close Date Period
Oppt_Split.CloseDate = pd.to_datetime(Oppt_Split.CloseDate, format="%Y-%m-%d",errors='coerce')
Oppt_Split = pd.merge(Oppt_Split, Date_Period, how='left', left_on = 'CloseDate', right_on='Date') #add quarter field to the table


Oppt_Split = Oppt_Split[Oppt_Split.SplitPercentage > 0]

# adding SE_Oppt_Owner's District for Tableau permission
# remove the SE_org_coverage_byName the one with missing SFDC_User_ID
SE_org_coverage_byName = SE_org_coverage_byName[~SE_org_coverage_byName.SFDC_UserID.isnull()]
Oppt_Split = pd.merge(Oppt_Split, SE_org_coverage_byName[['SFDC_UserID','District']], how='left', left_on='SE_Oppt_Owner_ID', right_on='SFDC_UserID')
Oppt_Split.drop(columns=['SFDC_UserID'], inplace=True)
Oppt_Split.rename(columns={'District':'SE_Oppt_Owner_District'}, inplace=True)

Oppt_Split = pd.merge(Oppt_Split, SE_org_coverage_byName[['SFDC_UserID','District']], how='left', left_on='Acct_Exec_SFDC_UserID', right_on = 'SFDC_UserID')
Oppt_Split.loc[Oppt_Split.SE_Oppt_Owner_District.isnull(),'SE_Oppt_Owner_District'] = Oppt_Split.loc[Oppt_Split.SE_Oppt_Owner_District.isnull(),'District']
Oppt_Split.drop(columns=['SFDC_UserID', 'District'], inplace=True)
#Oppt_Split.SE_Oppt_Owner_District.fillna("None",inplace=True)  ## need to add the AE's district for Oppt wo SE Oppt Owner


# adding information of SE assigned to the the Oppt_Split_User (AE)
Oppt_Split = pd.merge(Oppt_Split, SE_org_coverage_byTerritory[['Territory_ID', 'Territory_Assigned_SE', 'Territory_Assigned_SE_SFDC_UserID']], how='left', left_on='Oppt_Split_User_Territory_ID', right_on='Territory_ID')
Oppt_Split.rename(columns = {'Territory_ID' : 'Assigned_SE_Territory_ID'}, inplace=True)
                             #'Territory_Assigned_SE' : 'Oppt_Split_SE',
                             #'Territory_Assigned_SE_SFDC_UserID' : 'Oppt_Split_SE_UserID'


#Scenario: when this is no split, i.e. AE fully owned the opportunity
#then compare the SE oppt owner vs the Territory assigned SE
Oppt_Split[['SE_Oppt_Owner_ID', 'Territory_Assigned_SE_SFDC_UserID']] = Oppt_Split[['SE_Oppt_Owner_ID', 'Territory_Assigned_SE_SFDC_UserID']].fillna(" ")
Oppt_Split['SE_Oppt_Comp'] = [(x[0] in x[1]) for x in zip(Oppt_Split['SE_Oppt_Owner_ID'],Oppt_Split['Territory_Assigned_SE_SFDC_UserID'])]
Oppt_Split['SE_Oppt_Comp'] = Oppt_Split['SE_Oppt_Comp'].map({True:"Retire Quota", False:"Temp Coverage"}) 

#Scenario: when this is a split
# assume all entry are Retire quote
# it is a low chance that we will have a SE who is not assigned to any of the AE's Territory and temporary cover the oppt
Oppt_Split.loc[Oppt_Split.SplitPercentage < 100, 'SE_Oppt_Comp'] = 'Retire Quota w Split'

# Flag the oppt where the SE Oppt Owner is blank. Until a SE Oppt Owner is populated, system cannot determine if this is Retire quota or Temp Coverage
Oppt_Split.loc[Oppt_Split.SE_Oppt_Owner.isna(), 'SE_Oppt_Comp'] = 'Need SE Oppt Owner'


# finding the temp coverage record
from getData import get_SFDC_Oppt_Split_Temp_Coverage
Temp_Coverage = get_SFDC_Oppt_Split_Temp_Coverage(1)


Oppt_Split = pd.merge(Oppt_Split, Temp_Coverage[['Id','SE_Oppt_Owner_ID','Opportunity Split Type', 'Reason_Code__c','TC_Amount__c']], how='left', left_on=['Id','SE_Oppt_Owner_ID'], right_on=['Id','SE_Oppt_Owner_ID'])

Oppt_Split.loc[Oppt_Split.SE_Oppt_Comp=='Temp Coverage', 'Missing_TempCoverage_Entry'] = ((Oppt_Split.SE_Oppt_Comp == 'Temp Coverage') & (Oppt_Split['Opportunity Split Type'].isna())).map({True:"YES",False:""}, na_action='ignore')
Oppt_Split.loc[Oppt_Split.SE_Oppt_Comp=='Retire Quota', 'Missing_TempCoverage_Entry'] = (Oppt_Split['Opportunity Split Type'].isna()).map({True:"", False:"Question?"})


Oppt_Split.to_csv(cfg.output_folder+'Opportunity.txt', sep="|", index=False)


#Oppt_Split[Oppt_Split.Id == '0060z00001w9HP4AAM']
#Oppt_Split[Oppt_Split.Id == '0060z00001xJuiyAAC']

### summary view is work in process, since the pooled model ###
#===============================================================================
#
# Case 1: If Acct_Exec = Oppt_Split_User and Split Percentage = 100, no split, SE on it because he is assigned to the AE
# Case 2: If Acct_Exec = Oppt_Split_User and Split Percentage < 100, this is a Split Oppt
#         Question: will the paired SE has a split?
# Case 3: Oppt Split MasterLabel = Temp Coverage, the Oppt_Split_User is a temp coverage. I don't know if he is a AE or SE temp coverage
#
# I am an SE, find the opportunity 
# - i am the assigned SE because I am paired with AE
# - i am the assigned SE because my name is on SE Oppt Owner
# - i am the assigned SE because I am temp covered
# - i am the assigned SE because my paired AE is on the split?
#===============================================================================


# group the opportunity by Oppt_Split_User, Oppt_Split_User_Territory_Id, Quarter + ForecastCategory
# question: do all commissioned user has opportunity id? how about new hirer?
# what is the process to load AE territory id into SFDC? impact, cannot rely on SFDC for territory id if the process is unreliable
# question: if AE receive a split, does the assigned SE receive a split?
#'Period', 
######Problem here
Territory_Qtrly_Pipeline = pd.pivot_table(Oppt_Split, index = ['SE_Oppt_Owner_ID','SE_Oppt_Owner_District', 'Quarter', 'Year','ForecastCategoryName'],
                                          values=['SplitAmount'], aggfunc=['sum']).reset_index()
Territory_Qtrly_Pipeline.columns = Territory_Qtrly_Pipeline.columns.droplevel(1)
Territory_Qtrly_Pipeline.rename(columns = {'sum' : 'Amount', 'SE_Oppt_Owner_ID' : 'SFDC_UserID', 'SE_Oppt_Owner_District':'District'}, inplace=True)

sel_row = ['Q1', 'Q2', 'Q3', 'Q4']  # because SFDC label is a year behind
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[Territory_Qtrly_Pipeline.Quarter.isin(sel_row)]


# Read the FY20 Quota information
SE_Quota = pd.read_csv(cfg.output_folder + 'SE_Quota.txt', delimiter = '|', header=0)
SE_Quota.rename(columns={'Name':'SE_Oppt_Owner', 'Quota':'Amount'}, inplace=True)
SE_Quota['ForecastCategoryName'] = 'Quota'

Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline.append(SE_Quota[['SFDC_UserID','District','Year','Quarter','Amount','ForecastCategoryName']], sort=False)
# merge the SE_Oppt_Owner Territory & Theater information
temp = pd.pivot_table(SE_Quota, index = ['SFDC_UserID','SE_Oppt_Owner','Resource_Group','Theater','Region','District','Segment','Territory_IDs'],
                      values='ForecastCategoryName', aggfunc='count').reset_index()

Territory_Qtrly_Pipeline = pd.merge(Territory_Qtrly_Pipeline, temp[['SFDC_UserID','SE_Oppt_Owner','Resource_Group','Theater','Region']] , how='left', left_on='SFDC_UserID',right_on='SFDC_UserID')
## remove non employee
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[~(Territory_Qtrly_Pipeline.SE_Oppt_Owner.isnull())]   
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[~(Territory_Qtrly_Pipeline.SE_Oppt_Owner.str.match('SR-*')) & ~(Territory_Qtrly_Pipeline.SE_Oppt_Owner.str.match('^\d'))]

Territory_Qtrly_Pipeline.to_csv(cfg.output_folder+'Territory_Qtrly_Pipeline.txt', sep="|", index=False)

'''
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

###### when reading quota from Anaplan, there is not the Theater,Region, District, Segment, information

Territory_Pipeline_temp1 = Territory_Pipeline_temp[['Name','Oppt_Split_User_Territory_Id','Theater','Super_Region','Region','District','Segment','Quarter','ForecastCategoryName','sum']]
SE_quota_L_temp1 = SE_quota_L[['Name','Territory_IDs','Theater','Region','District','Segment','Quarter','Quota']]
SE_quota_L_temp1['ForecastCategoryName'] = 'Quota'
SE_quota_L_temp1.rename(columns={'Territory_IDs':'Territory_ID', 'Quota':'sum'}, inplace=True)

Territory_Pipeline_Quota_L = Territory_Pipeline_temp.append(SE_quota_L_temp1, sort = 'Name', ignore_index=False)
Territory_Pipeline_Quota_L1 = pd.pivot_table(Territory_Pipeline_Quota_L, index=['Name','Quarter','Theater','Region','District'], columns=['ForecastCategoryName'], values='sum' )


Territory_Pipeline_Quota_L1.to_csv(cfg.output_folder+'Territory_Pipeline_Quota_LONG.txt', sep="|", index=True)


### yet to add Flashblade Bookings. Look for FA AE name on the Flashblade deal
### double check if the FB deal is retiring quota or only extra commission
'''
'''

#===============================================================================
# Read Opportunity from SFDC
# Use the ForecastCategory to calculate the pipeline
#===============================================================================

from getData import get_SFDC_Oppt
Oppt = get_SFDC_Oppt(1)

# adding the Close Date Period
Oppt.CloseDate = pd.to_datetime(Oppt.CloseDate, format="%Y-%m-%d",errors='coerce')
Oppt = pd.merge(Oppt, Date_Period, how='left', left_on = 'CloseDate', right_on='Date') #add quarter field to the table

Oppt = pd.merge(Oppt, Territory_assignment, how='left', left_on='Acct_Exec', right_on='Acct_Exec')
Oppt.rename(columns = {'Territory_ID_x' : 'SFDC_Oppt_Territory_ID',
                       'Territory_ID_y' : 'SE_assigned_Territory_ID'}, inplace=True)

Oppt['SE_True_Owned'] = (Oppt.SE_Oppt_Owner == Oppt.Territory_Assigned_SE).map({True:1, False:0})

Oppt.to_csv(cfg.output_folder+'Opportunity.txt', sep="|", index=False)


# group the opportunity by SE_Oppt_Owner, Oppt:Territory_Id, Quarter + ForecastCategory
# question: do all commissioned user has opportunity id? how about new hirer?
# what is the process to load AE territory id into SFDC? impact, cannot rely on SFDC for territory id if the process is unreliable
# question: if AE receive a split, does the assigned SE receive a split?
Territory_Qtrly_Pipeline = pd.pivot_table(Oppt, index = ['SE_Oppt_Owner', 'Period', 'Quarter', 'Year','ForecastCategoryName'],
                                          values=['Amount'], aggfunc=['sum']).reset_index()
Territory_Qtrly_Pipeline.columns = Territory_Qtrly_Pipeline.columns.droplevel(1)
Territory_Qtrly_Pipeline.rename(columns={'sum':'Amount'}, inplace=True)

sel_row = ['FQ1 FY 2019', 'FQ2 FY 2019', 'FQ3 FY 2019', 'FQ4 FY 2019']
Territory_Qtrly_Pipeline = Territory_Qtrly_Pipeline[Territory_Qtrly_Pipeline.Period.isin(sel_row)]

'''

