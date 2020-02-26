'''
Created on Aug 9, 2019
@author: aliu
Process the workdoy report into a database table

'''
import pandas as pd
import project_config as cfg
import pyodbc
import datetime

#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-07-28 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-08-11 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-08-25 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-09-01 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-09-29 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-10-13 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-10-20 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-10-27 09_30 PDT.xlsx'
#target = 'CR_Shawn Rosemarin Supervisory Organization Members and Information(New Hires) 2019-05-29 09_30 PDT.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-11-17 09_30 PST.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2019-12-01 09_30 PST.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-01-05 09_30 PST.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-01-12 09_30 PST.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-01-26 09_30 PST.xlsx'
target = 'Shawn Rosemarin Employee Information Weekly Report 2020-02-16 09_30 PST.xlsx'

snapshot_date = datetime.date(2020, 2, 16)

supplement = "Supplement.xlsx"
    
prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Workday', skiprows=3, header=0, usecols = "A:E")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Sheet1', skiprows=1
                       , usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

output['EmployeeID'] = output['EmployeeID'].astype(str)
output['Snapshot_date'] = snapshot_date
output['Name'] = output['FirstName'] + " " + output['LastName']

output['Manager'] = output['Manager'].replace(r'[^\x00-\x7F]+', '', regex=True) # remove non ansii characters
output['Manager'] = output['Manager'].apply(lambda x : x if x.rfind("-") < 0 else x[:x.rfind("-")].strip())

output['Position'] = output['Position'].apply(lambda x : x if x.rfind(chr(65288)) < 0 else x[:x.rfind(chr(65288))])  # remove the string after the right most (
output['Position'] = output['Position'].apply(lambda x : x if x.rfind("(") < 0 else x[:x.rfind("(")])  # remove the string after the right most (
output['Position'] = output['Position'].replace(r'[^\x00-\x7F]+', '', regex=True) # remove non ansii characters

#ord('a')

#output.loc[51]
#output.loc[307]
#output.loc[319]
#output.loc[324]
#output.loc[398]
#output.loc[528]

#Extract the preferred name from Position
output['Perferred_Name'] = output.Position.apply(lambda x : x[x.rfind(" - ")+3:].strip())
output['Title'] = output.Position.apply(lambda x : x[:x.rfind(" - ")].strip())

# Manager Name is the perferred name
temp_manager = output[['EmployeeID','Perferred_Name']].copy()
temp_manager.rename(columns= {'EmployeeID':'Manager_EmployeeID', 'Perferred_Name':'Manager'}, inplace=True)
output = pd.merge(output, temp_manager, how='left', on='Manager')

from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work
output.to_sql('SE_Org_Members', con=conn_str, if_exists='replace', schema="dbo", index=False)

print ('I am done updating SE Org')









  