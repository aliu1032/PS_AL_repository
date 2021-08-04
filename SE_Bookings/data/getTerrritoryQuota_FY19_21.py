'''
Created on Jan 11, 2019

@author: aliu
   
'''

import pandas as pd
#import pyodbc

#from pydrive.auth import GoogleAuth
#from pydrive.drive import GoogleDrive

from datetime import datetime
#import project_config as cfg


sup_folder = "G:\\My Drive\\Sync Laptop on Google Drive\\workspace\\SE_Performance\\"
supplment = "Supplement.xlsx"
file_path = 'G:\\My Drive\\SE Analytics\\Analytics\\'


FY19_file = 'FY19 Territory Master.xlsx' 

Fields = pd.read_excel(file_path+FY19_file, header=None, skiprows=1, nrows=1, usecols='A:C,J,R,V,Z,AD').iloc[0].tolist()
FY19 = pd.read_excel(file_path+FY19_file,skiprows=8,header=None, usecols='A:C,J,R,V,Z,AD', names=Fields)

FY19.rename(columns = {'Territory Coverage Selection (name)':'Short_Description',
                       'Territory ID' : 'Territory_ID',
                       'Assigned Segment' : 'Segment',
                       'Q1 Quota' : 'Q1_M1_Quota',
                       'Q2 Quota' : 'Q2_M1_Quota',
                       'Q3 Quota' : 'Q3_M1_Quota',
                       'Q4 Quota' : 'Q4_M1_Quota'
                       }, inplace=True)
FY19['Year'] = 'FY19'
FY19['Type'] = ''



prep_file = pd.read_excel(sup_folder + supplment, sheet_name='TerritoryID_Master', skiprows=3, header=0, usecols = "I:M")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

FY20_file = 'FY20 Territory Master 6.29.2021.xls'
FY20 = pd.read_excel(file_path+FY20_file, skiprows=1, usecols=read_cols, names=new_names, dtypes=data_type, keep_default_na=True)        
FY20['Year'] = 'FY20'

FY21_file = 'FY21 Territory Quota Master.xlsx'
FY21 = pd.read_excel(file_path+FY21_file, skiprows=1, usecols=read_cols, names=new_names, dtypes=data_type, keep_default_na=True)        
FY21['Year'] = 'FY21'


output = pd.concat([FY19, FY20, FY21], sort=False, ignore_index=True)
output.loc[(output.Level == 'Super-Region'), 'Level'] = 'Area'


Territory_Hierarchy = {0 : 'Hierarchy',
                       1 : 'Theater',
                       2 : 'Area',
                       3 : 'Region',
                       4 : 'District',
                       5 : 'Territory'}
    
        # check for duplicate Territory IDs
        #temp_pd = pd.pivot_table(output, index=["Territory_ID"], values=["Level"], aggfunc='count').rename(columns={'Level':'Rec_Count'})
        #temp = output.groupby('Territory_ID').tail(1) #select the tail of each group
        
        # in case there is duplicate, take the last of the duplicate
output = output[output.Level.isin(Territory_Hierarchy.values())]
output = output.groupby(['Territory_ID','Year']).tail(1)
        
        # Using the Territory ID convention, find the territory hierarchy descriptions
temp = output['Territory_ID'].str.split('_', n=5, expand=True)
output = pd.merge(output, temp, how='left', left_index=True, right_index=True)
        
for i in Territory_Hierarchy.keys():
    temp = output[output.Level == Territory_Hierarchy[i]][['Territory_ID','Short_Description', 'Year']]
    output['temp_key'] = output[0]
    for j in range(1,i+1):
        output['temp_key'] = output['temp_key'].str.cat(output[j],sep='_')
    output = pd.merge(output, temp, how = 'left', left_on=['temp_key','Year'], right_on=['Territory_ID','Year'])
    output.drop(['Territory_ID_y'], axis=1, inplace=True)
    output.rename(columns={'Short_Description_x':'Short_Description',
                           'Short_Description_y': Territory_Hierarchy[i], 
                           'Territory_ID_x':'Territory_ID'}, inplace=True)
            
output.drop(Territory_Hierarchy.keys(), axis=1, inplace=True)
output.drop(['temp_key'], axis=1, inplace=True)


## calculate the 1H, 2H and Annual quota
output['1H_M1_Quota'] = output['Q1_M1_Quota'] + output['Q2_M1_Quota']
output['2H_M1_Quota'] = output['Q3_M1_Quota'] + output['Q4_M1_Quota']
output['FY_M1_Quota'] = output['Q1_M1_Quota'] + output['Q2_M1_Quota'] + output['Q3_M1_Quota'] + output['Q4_M1_Quota']

## calculate the 1H, 2H and Annual quota
output['1H_FB_Quota'] = output['Q1_FB_Quota'] + output['Q2_FB_Quota']
output['2H_FB_Quota'] = output['Q3_FB_Quota'] + output['Q4_FB_Quota']
output['FY_FB_Quota'] = output['Q1_FB_Quota'] + output['Q2_FB_Quota'] + output['Q3_FB_Quota'] + output['Q4_FB_Quota']

Quota_assignment_col = ['Q1_M1_Quota','Q2_M1_Quota','Q3_M1_Quota', 'Q4_M1_Quota', '1H_M1_Quota','2H_M1_Quota','FY_M1_Quota',\
                        'Q1_FB_Quota','Q2_FB_Quota','Q3_FB_Quota', 'Q4_FB_Quota', '1H_FB_Quota','2H_FB_Quota','FY_FB_Quota']
               
Territory_Quota = pd.melt(output, id_vars = ['Hierarchy','Theater','Area','Region','District', 'Territory','Territory_ID','Short_Description','Level','Segment','Type','Year'],
               value_vars=Quota_assignment_col, var_name='Period',value_name='Quota')
Territory_Quota['Measure'] = Territory_Quota.Period.str[3:]
Territory_Quota['Period'] = Territory_Quota.Period.str[0:2]


### Write to database ###
from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work

to_sql_type = pd.read_excel(sup_folder + supplment, sheet_name = 'Output_DataTypes', header=0, usecols= "B:D")
Territory_Quota_type = to_sql_type[to_sql_type.DB_TableName == 'Territory_Quota']
data_type = {}
for i in range(0, len(Territory_Quota_type.Columns)):
    data_type[Territory_Quota_type.Columns.iloc[i]] = eval(Territory_Quota_type.DataType.iloc[i])
    
Territory_Quota.to_sql('Territory_Quota_FY19_21', con=conn_str_local, if_exists='replace', schema="dbo", index=False)


server = 'PS-SQL-Dev02'
database = 'SalesOps_DM'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
Territory_Quota.to_sql('Territory_Quota_FY19_21', con=conn_str, if_exists='replace', schema="dbo", index=False)

#, dtype = data_type)
