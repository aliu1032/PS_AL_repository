'''
Created on Aug 9, 2019
@author: aliu
Process the workdoy report into a database table

'''
import pandas as pd
import project_config as cfg
import pyodbc
import datetime
from archieve.OrgChart_Hierarchy import new_names

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
#target = 'Shawn Rosemarin Employee Information Weekly Report 2020-04-12 09_30 PDT.xlsx'
target = 'Shawn Rosemarin Employee Information Weekly Report 2020-04-19 09_30 PDT.xlsx'


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
root_element = pd.DataFrame(
                [['104987', 'Shawn','Rosemarin','srosemarin@purestorage.com', '','','', 'VP Worldwide Systems Engineering - Shawn Rosemarin','','','',''],
                ['100001', 'John "Coz"', 'Colgrove','coz@purestorage.com','','','', 'Founder - John "Coz" Colgrove','','','',''],
                ['100905', 'Wendy','Stusrud','wstusrud@purestorage.com','','','', 'Area Vice President, Americas Channel Sales - Wendy Stusrud','','','',''],
                ['101922', 'Julio','Castrejon','jsarachaga@purestorage.com', '','','', 'Country Manager - Julio Castrejon','','','',''],
                ['100841', 'Douglas', 'De Campos', 'douglas@purestorage.com', '','','', 'Country Manager MCO - Douglas De Campos','','','',''],
                ['100486', 'Kevin','Delane', 'kd@purestorage.com', '','','', 'VP of Global Sales - Kevin Delane','','','',''],
                ['100801', 'Paulo','Godoy', 'paulo.godoy@purestorage.com','','','', 'Country Manager Brazil - Paulo Godoy','','','',''],
                ['106172', 'John', 'Senger', 'jsenger@purestorage.com','','','', 'Sr Director, Professional Services - John Senger','','','',''],
                ['101106', 'Michael','Sotnick','sot@purestorage.com','','','', 'VP Global Alliances - Michael Sotnick','','','','' ],
                ['100148', 'Matthew','Hamilton', 'mhamilton@purestorage.com','','','', 'VP Global Inside Sales and Renewals - Matthew Hamilton','','','','']],\
                columns=new_names)

output = output.append(root_element,ignore_index=True, sort=False)


output['EmployeeID'] = output['EmployeeID'].astype(str)
output['Snapshot_date'] = snapshot_date
output['Legal Name'] = output['FirstName'] + " " + output['LastName']

output['Manager'] = output['Manager'].replace(r'[^\x00-\x7F]+', '', regex=True) # remove non ansii characters
output['Manager'] = output['Manager'].apply(lambda x : x if x.rfind("-") < 0 else x[:x.rfind("-")].strip())

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
for x in list(ancestor.keys()):
    ancestory[x] = [x]
    i = x
    j = 1
    while ancestor[i] != '' :
        ancestory[x].insert(0, ancestor[i])
        i = ancestor[i]
        j = j + 1
        if j > tree_depth:
            tree_depth = j
            deep = x
    ancestory[x].insert(0, (x not in list(output['Manager'])))
    ancestory[x].insert(0, str(j))  #add the level to the dictionary
    
Org_Name = pd.DataFrame.from_dict(ancestory, orient='index', columns = Org_columns) 
Org_Name.reset_index(inplace=True)
Org_Name.rename(columns={'index':'Name'}, inplace=True)
temp = pd.melt(Org_Name, id_vars=['Name'], value_vars=Org_columns[2:], var_name='Level',value_name='Managers')
temp = temp[~temp.Managers.isna()]
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
Managers_EmployeeID = []
for i in range(0, tree_depth+1):
    Org_columns.append('Level' + str(i))
    Managers_EmployeeID.append('Level' + str(i) + '_EmployeeID')

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

SE_Subordinate_Permission = pd.melt(Org, id_vars=['Name','Email','EmployeeID', 'Level','Node'], value_vars=Managers_EmployeeID, var_name='Mgr_Level', value_name='Managers_EmployeeID')
SE_Subordinate_Permission = SE_Subordinate_Permission[SE_Subordinate_Permission.Managers_EmployeeID != '']
SE_Subordinate_Permission['Mgr_Level'] = SE_Subordinate_Permission['Mgr_Level'].apply(lambda x: x[5:x.find('_')])
SE_Subordinate_Permission.rename(columns = {'Name':'Subordinate', 'Email':'Subordinate_Email', 'EmployeeID':'Subordinate_EmployeeID'}, inplace=True, copy=False)
SE_Subordinate_Permission = pd.merge(SE_Subordinate_Permission, Org[['Name','Email','EmployeeID']], how='left', left_on='Managers_EmployeeID', right_on='EmployeeID')
SE_Subordinate_Permission.drop('Managers_EmployeeID', axis=1, inplace=True)


# Name, Email, EployeeID
extra_users = { 'April Liu' : ['aliu@purestorage.com','104663', ['Shawn Rosemarin','John "Coz" Colgrove','Wendy Stusrud', 'Julio Castrejon', 'Douglas De Campos','Kevin Delane','Paulo Godoy','John Senger','Michael Sotnick','Matthew Hamilton']],
                'Steve Gordon' :['sgordon@purestorage.com','105394', ['Shawn Rosemarin']],
                'Jim Adcox' :['jadcox@purestorage.com','103574', ['Shawn Rosemarin','John "Coz" Colgrove','Wendy Stusrud', 'Julio Castrejon', 'Douglas De Campos','Kevin Delane','Paulo Godoy','John Senger','Michael Sotnick','Matthew Hamilton']], 
                'George Lopez' :['glopez@purestorage.com','102307', ['Shawn Rosemarin','John "Coz" Colgrove','Wendy Stusrud', 'Julio Castrejon', 'Douglas De Campos','Kevin Delane','Paulo Godoy','John Senger','Michael Sotnick','Matthew Hamilton']]
                }

for i in list(extra_users.keys()):
    for j in range(0, len(extra_users[i][2])):
        temp = SE_Subordinate_Permission[(SE_Subordinate_Permission.Name == extra_users[i][2][j]) &\
                                          (SE_Subordinate_Permission.Subordinate != i)].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.EmployeeID = extra_users[i][1]
        temp.Mgr_level = 99
        temp.Level = 99
    
        SE_Subordinate_Permission = SE_Subordinate_Permission.append(temp)
                
                
#ord('a')

from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work
Org.to_sql('SE_Org_Members', con=conn_str, if_exists='replace', schema="dbo", index=False)


db_columns_types = pd.read_excel(cfg.sup_folder + supplement, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")
to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_Subordinate_Permission']
data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
SE_Subordinate_Permission.to_sql('SE_Subordinate_Permission_FY21', con=conn_str, if_exists='replace', schema="dbo", index=False, dtype = data_type)

print ('I am done updating SE Org')









  