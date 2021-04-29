# help: https://medium.com/@ammar.nomany.tanvir/read-write-update-drive-excel-file-with-pydrive-f63134120ff9


from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive
import pydrive.files
from pydrive import drive
from datetime import datetime

GoogleAuth.DEFAULT_SETTINGS['client_config_file'] = "C:\\Users\\aliu\\Documents\\client_secrets.JSON"
gauth = GoogleAuth()
gauth.LocalWebserverAuth() # Creates local webserver and auto handles authentication.

#Download the WaveMaker Report Excel file with password into Downloads folder
share_link = 'https://drive.google.com/file/d/1IW99prvXP6_8yjrvw7IMCYvTxa2m8Gky/view?usp=sharing'

file_id = share_link[share_link.find('/file/d')+8:share_link.find('/view')]
file_name = "C:\\Users\\aliu\\Downloads\\temp_WM_report.xlsx"

drive = GoogleDrive(gauth)
downloaded = drive.CreateFile({'id': file_id})
downloaded.GetContentFile(file_name) #download the google drive file into file_name
report_date = datetime.strptime(downloaded.get('title')[23:32], "%d %b %y").date()


#read from the Excel Report, save into a temp file without password
import win32com.client
import os
#from xlrd import *
xlApp = win32com.client.Dispatch("Excel.Application")
xlwb = xlApp.Workbooks.Open(file_name, False, True, None, 'W4veM4kers')
xlsheet = xlwb.Worksheets["Pure WM - partners"]
if os.path.exists('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv'):  #remove the file if exists
    os.remove('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
xlsheet.SaveAs('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv', FileFormat=62, Password = None) # answer overwrite
xlwb.Close(SaveChanges=False) #answer do not save change

import pandas as pd
df2 = pd.read_csv('C:\\Users\\aliu\\Downloads\\temp_WM_report.csv')
df2['Report_date'] = report_date

df2.rename(columns = {"User Group" : "WM_level",
                      "Username" : "User_Id",
                      "Dated of registration" : "Date_of_Registration",
                      "Date of last log in" : "Last_Login",
                      "Awarded for claims" : "Awarded_for_claims",
                      "Awarded for prizes" : "Awarded_for_prizes",
                      "Full name" : "Name",
                      "PTM" : "PTM_Id",
                      "PTM name" : "PTM_name",
                      "Log in count" : "Log_in_count"
                      }, inplace=True)

sel_col = ['Report_date', 'ID','Name','Email', 'Company', 'WM_level','User_Id', 'Balance', 'Date_of_Registration', 'Last_Login',
       'Awarded_for_claims', 'Awarded_for_prizes','IsDisti?', 'PTM_Id', 'PTM_name','Activated?', 'Log_in_count']

#write data into PS-SQL-Dev02.SalesOps_DM
#import pyodbc
from sqlalchemy import create_engine
#from sqlalchemy import types as sqlalchemy_types
server = 'PS-SQL-Dev02'
database = 'SalesOps_DM'
conn_str = create_engine('mssql+pyodbc://@' + server + '/' + database + '?driver=ODBC+Driver+13+for+SQL+Server') 
df2[sel_col].to_sql('WaveMake_Rpt_Insight', con=conn_str, if_exists='replace', schema="dbo", index=False)

print('WaveMaker Report is loaded')
