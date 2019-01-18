'''
Created on Jan 11, 2019

@author: aliu
'''

import project_config as cfg
import pandas as pd


#===============================================================================
# Read the Territory ID master
#===============================================================================
from getData import get_TerritoryID_Master
TerritoryID_Master = get_TerritoryID_Master(1,'Territory')
 
#===============================================================================
# Reading SE Territory and Quota from the Individual Quota Master spreadsheet
#===============================================================================
from getData import get_quota


quota_master = get_quota(1)
quota_master['Name'] = quota_master.FirstName.str.cat(quota_master.LastName, sep=' ')


#---------------------------------------------------------------------
# Read the overlay head count and the coverage territories information
SE_territory_W = quota_master[(quota_master.Group != 'Sales QBH') & (quota_master.Status=='Active')][['Name', 'Group', 'Title','Territory_IDs']]
SE_territory_W.Territory_IDs.fillna("",inplace=True)

# Expand the multiple territory coverage into columns
temp = SE_territory_W['Territory_IDs'].str.split('+', expand=True)
SE_territory_W = pd.merge(SE_territory_W, temp, how='left', left_index=True, right_index=True)
Coverage_Col = SE_territory_W.columns[4:]
for i in Coverage_Col:
    SE_territory_W[i] = SE_territory_W[i].str.strip()

# Un-pivot the Territory IDs
SE_territory_L = pd.melt(SE_territory_W, id_vars=['Name', 'Group','Title','Territory_IDs'], value_vars = Coverage_Col,
                var_name = 'Coverage_Area_', value_name = 'Territory_ID')
SE_territory_L = SE_territory_L[(SE_territory_L.Group == 'SE') & ~(SE_territory_L.Territory_ID.isnull())]

#missing the District, Region Territory ID for now
SE_territory_L = pd.merge(SE_territory_L, TerritoryID_Master, how='left', left_on = 'Territory_ID', right_on = 'Territory_ID')

SE_territory_L.to_csv(cfg.output_folder+'SE_Territory.txt', sep="|", index=False)

#------------------------------------------------------------------------------ 
# Read the overlay person quota information
SE_quota_W = quota_master[(quota_master.Group != 'Sales QBH') & (quota_master.Status=='Active')]\
             [['Name','Group','Territory_IDs','M1_Theater','M1_Super_Region','M1_Region','M1_District','M1_Segment',
               'M1_Q1_Quota_Assigned', 'M1_Q2_Quota_Assigned', 'M1_Q3_Quota_Assigned', 'M1_Q4_Quota_Assigned']]
SE_quota_W.columns = ['Name','Group','Territory_IDs','Theater','Super_Region','Region','District','Segment',
                       'Q1_Quota','Q2_Quota','Q3_Quota','Q4_Quota']

# Un-pivot the SE quota information
SE_quota_L = pd.melt(SE_quota_W, id_vars=['Name','Group','Territory_IDs','Theater','Super_Region','Region','District','Segment'],
                     value_vars = ['Q1_Quota','Q2_Quota','Q3_Quota','Q4_Quota'],
                     var_name = 'Period', value_name = 'Quota')

SE_quota_L.to_csv(cfg.output_folder+'SE_Quota.txt', sep="|", index=False)



#temp_pd = pd.pivot_table(SE_quota_data, index = 'Territory_ID', values='Name', aggfunc='count').rename(columns={'Name':'rec_count'})
# break the multiple ids into list -> to find the people covering multiple territory, 

QBH = quota_master[(quota_master.Group == 'Sales QBH') & (quota_master.Status == 'Active')][['Name', 'Territory_ID', 'Title']]
temp_pd = pd.pivot_table(QBH, index='Territory_ID', values='Name', aggfunc='count').rename(columns={'Name':'rec_count'})


#===============================================================================
# Read Opportunity Data from SFDC
#===============================================================================
from getData import get_SFDC_Oppt

Oppt = get_SFDC_Oppt(1)


temp = pd.pivot_table(Oppt, index = ['Opportunity', 'CloseDate','AE_Territory_Id'], values=['Amount'], aggfunc=['sum', 'count'])



#===============================================================================
# Left join Oppt with SE_Quota to find the associated SE 
# of the Opportunity using Opportunity Owner's Territory Id
# then summarize the opportunity by quarter and compare with the quarterly quota
#===============================================================================

temp = pd.merge(Oppt[['Id', 'Opportunity', 'Acct_Name', 'RecordType', 'Transaction_Type__c','Amount', 'Stage', 'ForecastCategoryName', 'CloseDate',
       'Theater__c', 'Division__c', 'Sub_Division__c', 'AE_Role', 'Acct_Exec', 'AE_Territory_Id']], SE_quota_L[['Name','Territory_ID','M1_Q1_Quota_Position','M1_Q1_Quota_Assigned']],how = 'left', left_on='AE_Territory_Id', right_on='Territory_ID')


#===============================================================================
# Write the output dataset
#===============================================================================

temp = temp[~(temp.AE_Territory_Id.isnull()) & ~(temp.Territory_ID.isnull())]
temp.to_csv(cfg.output_folder+'Oppt_Terr_Quota.txt', sep="|", index=False)