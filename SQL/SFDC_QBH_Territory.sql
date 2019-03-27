select Id, User_Type__c, Name, Title, Email, Theater__c, Division, Sub_Division__c, Territory_ID__c, Manager__c, ManagerId
from [PureDW_SFDC_staging].[dbo].[User]
where QBH_Employee__c = 'True'
and IsActive = 'True'