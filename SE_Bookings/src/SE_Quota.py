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

# Clean the Hierarchy & Theater values for report
TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Account Quotas') & (TerritoryID_Master.Theater == 'GIobals Account Quotas'), 'Super-Region'] = 'Globals Account program activity'
TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Account Quotas') & (TerritoryID_Master.Theater == 'GIobals Account Quotas'), 'Theater'] = 'Globals Account Quotas'

TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Account Quotas') & (TerritoryID_Master.Theater == 'Enterprise account activity, Globally'), 'Theater'] = 'Enterprise account'
TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Account Quotas') & (TerritoryID_Master.Theater == 'Global Systems Integrator (GSI) program SELL TO and SELL-THROUGH/WITH activity, Globally (Accenture & ATOS & CapGemini & CGI & Cognizant-Trizetto & Deloitte & DXC & Fujitsu & HCL & IBM Global Services & Infosys & PricewaterhouseCoopers & Sopra & TCS & Tech Mahindra & Tsystems & Wipro)'), 'Theater'] \
                                                                                                            = 'Global Systems Integrator'
TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Account Quotas') & (TerritoryID_Master.Theater == 'G2K Target Account activity, Globally (Alphabet Inc. & American International Group & Apple Inc. & ATOS IDM & Automatic Data Processing Inc. & Aviva PLC & Bank of America Corporation & BT Group PLC & Cisco Systems Inc. & Credit Agricole SA & CVS Health Corporation & Deutsche Telecom AG & Fidelity National Information Services, Inc. & Fiserv, Inc. & FMR LLC & Ford Motor Company & General Motors Company & Honeywell International Inc. & Intel Corporation & Johnson & Johnson & MetLife Inc. & Nationwide Mutual Insurance Company & PayPal Holdings Inc. & PepsiCo, Inc. & The PNC Financial Services Group Inc & Prudential Financial, Inc. & Royal Bank of Canada & Salesforce.com, Inc. & Siemens AG & StateFarm Insurance & Target Corporation & Toyota Motor Corporation & UnitedHealth Group & United Parcel Service Inc. & U.S. Bancorp & Visa Inc. & Volkswagen Aktiengesellschaft & Wal-Mart Stores, Inc. & Wells Fargo & Company & Zurich Insurance Group)'), \
                                                                                                            'Theater'] \
                                                                                                            = 'G2K Target Accounts'
TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Verticals') & (TerritoryID_Master.Theater == 'Healthcare Vertical (Providers, Life Sciences & Healthcare Technology) activity, Globally'), 'Theater'] \
                                                                                                            = 'Healthcare Vertical'
TerritoryID_Master.loc[(TerritoryID_Master.Theater == 'National Partner program activity in AMER (CDW & Dimension Data & ePlus & Forsythe & Insight Investments & Presidio & SHI & Sirius Solutions & Worldwide Technology) and in EMEA ('),\
                                                                                                            'Hierarchy'] \
                                                                                                            = 'National Partner'
TerritoryID_Master.loc[(TerritoryID_Master.Theater == 'National Partner program activity in AMER (CDW & Dimension Data & ePlus & Forsythe & Insight Investments & Presidio & SHI & Sirius Solutions & Worldwide Technology) and in EMEA ('),\
                                                                                                            'Theater'] \
                                                                                                            = 'National Partner'

TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy'), 'Theater'] \
            = TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy')].Theater.apply(lambda x : x.replace(' Super-Region',''))

TerritoryID_Master[TerritoryID_Master.Territory_ID=='WW_EMA_EEM_EMS_ZAR_002']['Territory_Description'].str.replace('\\n', " ")                                                                                                            
#TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy'), 'Theater'] \
#            = TerritoryID_Master.loc[(TerritoryID_Master.Hierarchy == 'Pro Services') & (TerritoryID_Master.Level != 'Hierarchy')].Theater.str.extract('^(.*?)\ Super-Region')                                                                                             
#TerritoryID_Master[TerritoryID_Master.Theater.str.match('National Partner*', na=False)]

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


# fill the Blank Coverage Assignment ID to 'No Plan / No Coverage'

#-----------------Create report using Anaplan coverage inforamtion----------------------------------------------------
# Read the Territory assignment, Create a Long view for Tableau report
Territory_assignment_W = quota_master[['Name', 'Title','Resource_Group','HC_Status', 'Manager','Territory_IDs']]
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
Territory_assignment_L = pd.melt(Territory_assignment_W, id_vars=['Name','Title','Resource_Group', 'HC_Status', 'Manager','Territory_IDs'], value_vars = Coverage_Col,
                var_name = 'Coverage_Area_', value_name = 'Territory_ID')
Territory_assignment_L = Territory_assignment_L[~(Territory_assignment_L.Territory_ID.isnull())] #clean the null data

Territory_assignment_L = pd.merge(Territory_assignment_L, TerritoryID_Master, how='left', left_on='Territory_ID', right_on='Territory_ID')
Territory_assignment_L.sort_values(by=['Territory_ID','Name'], inplace=True)

# Write the Territory Assignment to a text file
Territory_assignment_L.to_csv(cfg.output_folder+'Territory_Assignment_Anaplan.txt', sep="|", index=False)


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

