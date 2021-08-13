'''
Created on Aug 9, 2019
@author: aliu
Process the workdoy report into a database table

'''
import pandas as pd
import project_config as cfg
import pyodbc
from datetime import date

print ("Run date ", date.today())

server = 'PS-SQL-Dev02'
database = 'GPO_TSF_Dev'
table = 'dbo.vemporgmapper'
        
cnxn = pyodbc.connect('DSN=PS-SQL-Dev02; Trust_Connection = yes',DRIVER='{ODBC Driver 13 for SQL Server}', SERVER=server, Database=database)
query = ('Select EmployeeID, [Name], [Email], [Manager], [Manager ID] Manager_EmployeeID, [Role], [Employee Level] [EmployeeLevel], [Workday_Report_date]'
         ' from GPO_TSF_Dev.dbo.vSE_Org'
         ' where [Role] not in (\'FF\',\'HQ\')'
 #        ' where not([Employee Level] = 1 and Directs = 0)'
         )
output = pd.read_sql(query, cnxn)
cnxn.close()

output['EmployeeID'] = output['EmployeeID'].astype(str)
output['Manager_EmployeeID'] = output['Manager_EmployeeID'].astype(str)
#output['Snapshot_date'] = date.today()

#output.loc[output.Name.isin(['Nathan Hall', 'Shawn Rosemarin','Carl McQuillan']),'Manager_EmployeeID'] = '999998'  #--'107863'

'''
ancestor = dict(zip(output['Name'], output['Manager']))
ancestory = {}   # dictionay with key = Employee, value is a list of the hierarchy path where the last element is the employee
Mgr_list = [ele for ele in list(ancestor.keys()) if ele not in list(output[output.EmployeeLevel==0]['Name'])]
tree_depth = 1
for x in Mgr_list:
    ancestory[x] = [x]
    i = x
    j = 1
    while ancestor[i] in list(ancestor.keys()):
        ancestory[x].insert(0, ancestor[i])
        i = ancestor[i]
        j = j + 1
        if j > tree_depth:
            tree_depth = j
            deep = x
    ancestory[x].insert(0, (x in list(output['Manager']))) #add isManger T/F
    ancestory[x].insert(0, j)  #add the level to the dictionary

'''
            
ancestorID = dict(zip(output['EmployeeID'], output['Manager_EmployeeID']))
Mgr_list = [ele for ele in list(ancestorID.keys()) if ele not in list(output[output.EmployeeLevel==0]['EmployeeID'])]
ancestoryID = {}   # dictionary with key = Employee, value is a list of the hierarchy path where the last element is the employee
tree_depth = 1
for x in Mgr_list:
    ancestoryID[x] = [x]
    i = x
    #print (i)
    j = 1
    while ancestorID[i] in list(ancestorID.keys()):
        ancestoryID[x].insert(0, str(ancestorID[i]))
        i = str(ancestorID[i])
        j = j + 1
        if j > tree_depth:
            tree_depth = j
            #deep = x
    ancestoryID[x].insert(0, (x in list(output['Manager_EmployeeID'])))
    ancestoryID[x].insert(0, j)  #add the level to the dictionary


Org_columns = ['Level','isManager']
Managers_EmployeeID = []
for i in range(1, tree_depth+1):
    Org_columns.append('Level' + str(i))
    Managers_EmployeeID.append('Level' + str(i) + '_EmployeeID')

Org = pd.DataFrame.from_dict(ancestoryID, orient='index', columns = Org_columns)
Org.reset_index(inplace=True)
Org.rename(columns={'index' : 'EmployeeID'}, inplace=True)

Org = pd.merge(Org, output, how='left', on='EmployeeID')

for i in range(1,tree_depth+1):
    join_on = 'Level'+ str(i)
    Org = pd.merge(Org, output[['Name','Email','EmployeeID']], how='left', left_on=join_on, right_on='EmployeeID')
    Org.rename(columns={'EmployeeID_x':'EmployeeID', 'Name_x':'Name', 'Email_x':'Email',
                        'EmployeeID_y': 'Level'+str(i) +'_EmployeeID',
                        'Name_y': 'Level'+str(i)+'_Name',
                        'Email_y': 'Level'+str(i)+'_Email'}, inplace=True)
    Org = Org.drop([join_on], axis = 1)

Org.fillna('', inplace = True)

#SE_Org = Org[Org.Level1_Name == 'Nathan Hall']
SE_Org = Org[Org.Level1_Name.isin(['Michael Richardson', 'Zack Murphy','Carl McQuillan'])]
SE_Subordinate_Permission = pd.melt(SE_Org, id_vars=['Name','Email','EmployeeID', 'Level','isManager', 'Workday_Report_date'], value_vars=Managers_EmployeeID, var_name='Mgr_Level', value_name='Managers_EmployeeID')
SE_Subordinate_Permission = SE_Subordinate_Permission[SE_Subordinate_Permission.Managers_EmployeeID != '']
SE_Subordinate_Permission['Mgr_Level'] = SE_Subordinate_Permission['Mgr_Level'].apply(lambda x: x[5:x.find('_')]).reindex()
SE_Subordinate_Permission.rename(columns = {'Name':'Subordinate', 'Email':'Subordinate_Email', 'EmployeeID':'Subordinate_EmployeeID'}, inplace=True, copy=False)
SE_Subordinate_Permission = pd.merge(SE_Subordinate_Permission, output[['Name','Email','EmployeeID']], how='left', left_on='Managers_EmployeeID', right_on='EmployeeID')
SE_Subordinate_Permission.drop('Managers_EmployeeID', axis=1, inplace=True)


# Special assignment 
Special_Need = output[output.Name=='Yi Shuen Chin'][['Name', 'EmployeeID', 'Email', 'Role', 'Manager']].sort_values(['Role'])
SE_Subordinate_Permission = SE_Subordinate_Permission[~SE_Subordinate_Permission.Name.isin(Special_Need['Name'])]

# Name, Email, EmployeeID, List of user to copy from
extra_users = { 'April Liu' : ['aliu@purestorage.com','104663', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Steve Gordon' :['sgordon@purestorage.com','105394', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'George Lopez' :['glopez@purestorage.com','102307', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Rick Lindgren' :['rlindgren@purestorage.com','104088', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Elise Linker' :['elinker@purestorage.com','107315', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Thomas Waung' :['twaung@purestorage.com','103800', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Andrew May' :['amay@purestorage.com','103800', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Veronika Dunkley' :['vdunkley@purestorage.com','103357', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Deny Patel' : ['depatel@purestorage.com','105693', ['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Julie Rosenberg' : ['julie@purestorage.com','101247',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Chadwick Short' : ['chad.short@purestorage.com','101059', ['Michael Richardson']],
                'Steven Heusser' : ['sheusser@purestorage.com','102024', ['Michael Richardson']],
                'Chris Otis' : ['chotis@purestorage.com', '104457',['Adrian Simays', 'Michael Richardson']],
                'Chad Gebhardt' : ['cgebhardt@purestorage.com', '104535',['Adrian Simays', 'Michael Richardson']],
                'Scott Warrington' : ['swarrington@purestorage.com', '104970',['Adrian Simays', 'Michael Richardson']],
                'Marsha Pierce' : ['mpierce@purestorage.com', '102033',['Michael Richardson']],
                'Jon Owings' : ['owings@purestorage.com', '100314',['Michael Richardson']],
                'Angela Teodoro' : ['ateodoro@purestorage.com', '106979',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Reed Scherer' : ['reed@purestorage.com', '100218',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Willy Vega' : ['wvega@purestorage.com', '103426',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Naomi Newport' : ['nnewport@purestorage.com', '101468',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Sabine Cronin' : ['scronin@purestorage.com', '107153',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Lauren Futris' : ['lfutris@purestorage.com', '108451',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Nathan Hall' : ['nhall@purestorage.com' , '103703',['Michael Richardson', 'Zack Murphy','Carl McQuillan']],
                'Carmen Summers' : ['csummers@purestorage.com', '106941', ['Michael Richardson']],
                'Chris Hansen' : ['chhansen@purestorage.com','107696',['Michael Richardson']],
                'Yi Shuen Chin' : ['ychin@purestorage.com','102448',['Pratyush Khare']]
               }

for i in list(extra_users.keys()):
    for j in range(0, len(extra_users[i][2])):
        subordinate = list(SE_Subordinate_Permission[SE_Subordinate_Permission.Name== i ]['Subordinate'])
        temp = SE_Subordinate_Permission[(SE_Subordinate_Permission.Name == extra_users[i][2][j]) &\
                                          ~(SE_Subordinate_Permission.Subordinate.isin(subordinate))].copy()
        temp.Name = i
        temp.Email = extra_users[i][0]
        temp.EmployeeID = extra_users[i][1]
        temp.Mgr_level = 99
        temp.Level = 99
    
        SE_Subordinate_Permission = SE_Subordinate_Permission.append(temp, ignore_index=True)


from sqlalchemy import create_engine
from sqlalchemy import types as sqlalchemy_types

#supplement = "Supplement.xlsx"
#db_columns_types = pd.read_excel(cfg.sup_folder + supplement, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")
#to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_Org_Members']

server = 'ALIU-X1'
database = 'ALIU_DB1'
conn_str_local = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work

supplement = "Supplement.xlsx"
db_columns_types = pd.read_excel(cfg.sup_folder + supplement, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")
to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_Subordinate_Permission']
data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
SE_Subordinate_Permission.to_sql('SE_Subordinate_Permission_FY22', con=conn_str_local, if_exists='replace', schema="dbo", index=False)



server = 'PS-SQL-Dev02'
database = 'SalesOps_DM'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') #work

supplement = "Supplement.xlsx"
db_columns_types = pd.read_excel(cfg.sup_folder + supplement, sheet_name = 'Output_DataTypes',  header=0, usecols= "B:D")
to_sql_type = db_columns_types[db_columns_types.DB_TableName=='SE_Subordinate_Permission']
data_type={}
for i in range(0,len(to_sql_type.Columns)):
    data_type[to_sql_type.Columns.iloc[i]] = eval(to_sql_type.DataType.iloc[i])
SE_Subordinate_Permission.to_sql('SE_Subordinate_Permission_FY22', con=conn_str, if_exists='replace', schema="dbo", index=False)

              
print ('I am done updating SE Org Subordinate Permission')









  