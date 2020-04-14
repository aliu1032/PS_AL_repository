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
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-02-16 09_30 PST.xlsx'
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-04-05 09_30 PDT.xlsx'
target = 'Shawn Rosemarin Employee Information Weekly Report 2020-04-12 09_30 PDT.xlsx'


snapshot_date = datetime.date(2020, 4, 12)

supplement = "Supplement.xlsx"
    
prep_file = pd.read_excel(cfg.sup_folder + supplement, sheet_name='Workday', skiprows=3, header=0, usecols = "A:E")
prep_file = prep_file[prep_file.Include == 1.0]
read_cols = ",".join(list(prep_file.Column))
new_names = list(prep_file.NewName)
data_type = dict(zip(prep_file.NewName, prep_file.DataType))

output = pd.read_excel(cfg.source_data_folder + target, sheet_name='Sheet1', skiprows=1
                       , usecols=read_cols, names=new_names,
                       dtypes=data_type, keep_default_na=True)

#add the root information
output = output.append({ 'FirstName':'Shawn','LastName':'Rosemarin', 'EmployeeID':"104987",'Email':'srosemarin@purestorage.com',\
                         'Position':' VP Worldwide Systems Engineering - Shawn Rosemarin', 'Manager':'', 'Manager_EmployeeID':''}
                        , ignore_index=True)

output['EmployeeID'] = output['EmployeeID'].astype(str)
output['Snapshot_date'] = snapshot_date
output['Legal Name'] = output['FirstName'] + " " + output['LastName']

#output['Manager'] = output['Manager'].replace(r'[^\x00-\x7F]+', '', regex=True) # remove non ansii characters
#output['Manager'] = output['Manager'].apply(lambda x : x if x.rfind("-") < 0 else x[:x.rfind("-")].strip())

output['Position'] = output['Position'].apply(lambda x : x if x.rfind(chr(65288)) < 0 else x[:x.rfind(chr(65288))])  # remove the string after the right most (, those with non ascii names
output['Position'] = output['Position'].apply(lambda x : x if x.rfind(chr(40)) < 0 else x[:x.rfind(chr(40))])  # remove the string after the right most (, those with non ascii names
output['Position'] = output['Position'].replace(r'[^\x00-\x7F]+', '', regex=True) # remove non ansii characters
output['Position'] = output['Position'].apply(lambda x : x if x.rfind(chr(91)) < 0 else x[:x.rfind(chr(91))])  # remove the string after the right most [,

output['Name'] = output['Position'].apply(lambda x : x if x.rfind(" - ") < 0 else x[x.rfind(" - ")+2:].strip()) # Extract the preferred name from position
output['Title'] = output.Position.apply(lambda x : x[:x.rfind(" - ")].strip())


'''
ancestor = dict(zip(output['Name'], output['Manager']))
ancestory = {}   # dictionay with key = Employee, value is a list of the hierarchy path where the last element is the employee
tree_depth = 1
for x in list(ancestor.keys())[:3]:
    ancestory[x] = [x]
    i = x
    j = 1
#    while i in ancestor.keys():
    while ancestor[i] != '' :
        ancestory[x].insert(0, ancestor[i])
        i = ancestor[i]
        j = j + 1
        if j > tree_depth:
            tree_depth = j
            deep = x
    ancestory[x].insert(0, (x not in list(output['Manager'])))
    ancestory[x].insert(0, str(j))  #add the level to the dictionary
'''
            
ancestorID = dict(zip(output['EmployeeID'], output['Manager_EmployeeID']))
ancestoryID = {}   # dictionary with key = Employee, value is a list of the hierarchy path where the last element is the employee
tree_depth = 0
for x in list(ancestorID.keys()):
    ancestoryID[x] = [x]
    i = x
    j = 0
    while ancestorID[i] != '':
        ancestoryID[x].insert(0, str(ancestorID[i]))
        i = str(ancestorID[i])
        j = j + 1
        if j > tree_depth:
            tree_depth = j
            #deep = x
    ancestoryID[x].insert(0, (x not in list(output['Manager'])))
    ancestoryID[x].insert(0, str(j))  #add the level to the dictionary


Org_columns = ['Level','Node']
for i in range(0, tree_depth+1):
    Org_columns.append('Level' + str(i))

Org = pd.DataFrame.from_dict(ancestoryID, orient='index', columns = Org_columns)
Org.reset_index(inplace=True)
Org.rename(columns={'index' : 'EmployeeID'}, inplace=True)

Org = pd.merge(Org, output, how='left', on='EmployeeID')

for i in range(0,tree_depth+1):
    join_on = 'Level'+ str(i)
    Org = pd.merge(Org, output[['Name','Email','EmployeeID']], how='left', left_on=join_on, right_on='EmployeeID')
    Org.rename(columns={'EmployeeID_x':'EmployeeID', 'Name_x':'Name', 'Email_x':'Email',
                        'EmployeeID_y': 'Level'+str(i) +'_EmployeeID',
                        'Name_y': 'Level'+str(i)+'_Name',
                        'Email_y': 'Level'+str(i)+'_Email'}, inplace=True)
    Org = Org.drop([join_on], axis = 1)

Org.fillna('', inplace = True)
#ord('a')

from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work
Org.to_sql('SE_Org_Members', con=conn_str, if_exists='replace', schema="dbo", index=False)

print ('I am done updating SE Org')









  