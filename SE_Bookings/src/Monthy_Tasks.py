'''
Created on Apr 28, 2021

@author: aliu
'''

credential = "C:\\Users\\aliu\\Documents\\client_secrets.JSON"

### Update the link to the report file to be loaded into database
## CY2021 folder
#WaveMaker_Report_Link = 'https://drive.google.com/file/d/1XQCG2bvPVBW7juXMjD4VTK7TmX61hAW5/view?usp=sharing' #05.28
#WaveMaker_Report_Link = 'https://drive.google.com/file/d/1KVq9P9MprwAzWqmTrhRnDk5q51mJq2ql/view?usp=sharing' #6.06
#WaveMaker_Report_Link = 'https://drive.google.com/file/d/1aRfI-e--XEXAJWvzYJBZPRhvnsjiR-Oq/view?usp=sharing'  #07.05
WaveMaker_Report_Link = 'https://drive.google.com/file/d/15qUJ8XzLLdj66UNEv7myu34jFg7d7qKQ/view?usp=sharing' #07.29
## My Drive / SE Analytics / Analytics / Territory_Target : https://drive.google.com/drive/u/0/folders/1vT46et8e2sZQIehE2rMNsIt8SoqwUD51
#Anaplan_Territory_Target_Link = 'https://drive.google.com/file/d/1ObwGSdApZqiu0wn95GVPHV36mnCRP65b/view?usp=sharing' #06.01


'''
try bring the authenticaion here
'''
from pydrive.auth import GoogleAuth
from pydrive.drive import GoogleDrive

GoogleAuth.DEFAULT_SETTINGS['client_config_file'] = credential
gauth = GoogleAuth()
gauth.LocalWebserverAuth()
gauth.SaveCredentialsFile("mycreds.txt")

'''
gauth.LoadCredentialsFile("mycreds.txt")
if gauth.credentials is None:
    # Authenticate if they're not there
    gauth.LocalWebserverAuth()
elif gauth.access_token_expired:
    # Refresh them if expired
    gauth.Refresh()
else:
    # Initialize the saved creds
    gauth.Authorize()
    # Save the current credentials to a file
gauth.SaveCredentialsFile("mycreds.txt")
'''

#Refresh Wavemaker report by 360Insight
from getDataFY22 import refresh_Wavemaker_Report
refresh_Wavemaker_Report(WaveMaker_Report_Link, credential)


# Refresh Territory Quota
# update TerritoryID_Master
# update Territory_Quota_FY22 used in SEM-Metrics
from getDataFY22_Jul302021 import refresh_Anaplan_TerritoryID_Master
refresh_Anaplan_TerritoryID_Master()

# from getDataFY22 import refresh_Anaplan_TerritoryID_Master
# refresh_Anaplan_TerritoryID_Master(Anaplan_Territory_Target_Link, credential)

print('Start SE_Quota_ETL')
import SE_Quota_ETL_FY22_Jul302021
# Using on Anaplan Coverage assignment information: create output
# Territory_assignment_byName : break out the comma-delimited coverage ID into rows. (Territory_assignment_L)
# Coverage_assignment_byName : for lookup the Coverage GTM resource by Territory Id. A Territory ID have multiple resources > multiple rows. Resolve Theater/Area/Region/District coverage into Territories.
# SE_Org_Quota_FY22 : this is not needed after checking all dashboard is using Anaplan_DM
# SE_District_Permission, use in SEM_Metrics (using the Coverage assignment, derive the district permission for SEs)
#
# Jul 30, 2021
# update ETL to pull CFY Territory_ID_master from Anaplan_DM

print('Start Subordinate Permission update')
import SE_Org_Subordinate_Permission_FY22 
# setup the permission for Managers to view subordinate records
# use in SE Team Metrics, SE_Attainment

print('Done monthly tasks')
import datetime
print ('Process Start ', datetime.datetime.now())
for i in range(0,20) :
    print ('Test schedule python function', i)

print ('Process End ', datetime.datetime.now())
    
'''
import sys
import datetime

oringal_stdout = sys.stdout

with open('C:\\Users\\aliu\\Test_output.txt', 'a') as f:
    sys.stdout = f
    print ('Output to a file', datetime.datetime.now())
    sys.stdout = oringal_stdout
'''
    