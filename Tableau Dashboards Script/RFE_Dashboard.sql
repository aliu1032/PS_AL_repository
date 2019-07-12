/****** Script for SelectTopNRows command from SSMS  ******/

SELECT 
      [Feature__c] [Feature_SFDCId]
	  , F.Name [Feature Number]
	  , cast (F.CreatedDate as Date) [Feature_CreatedDate] 
	  , PM.Name [PM] --, F.PM__c
	  , PSE.Name [PSE] --, F.PSE__c
	  , F.PSE_Territory__c [PSE Territory]
	  , F.Category__c [Category]
	  , F.Feature_Status__c [Feature Status]
	  , F.Title__c [Title]
	  , AFR.[Account__c] AccountId
	  , Acc.Name [Account]
	  , null as OpportunityID
	  , null as Opportunity
	  , null as [Oppt Stage]
	  , 0 as Amount_USD
      , AFR.[Deployment_Scenario__c] [General Use Case]
      , cast (AFR.[Other_Deployment_Scenario__c] as nvarchar(255)) [General Use Case Other]
      , AFR.[Solution_Use_Case__c] [Detail Use Case]
      , cast(AFR.[Solution_Application__c] as nvarchar(255)) [Solution Use Case]
      , AFR.[Other_Solution_Application__c] [Solution Use Case other]
--      , AFR.[Reviewed_By__c]
--      , AFR.[Status__c]
	  , AFR.[Id] [Request_SFDCId]
      , AFR.[Name] [Request_Name]
  	  , cast( AFR.CreatedDate as Date) [Request_Date]
  FROM [PureDW_SFDC_staging].[dbo].[Product_Account_Feature_Request__c] AFR
  left join [PureDW_SFDC_staging].[dbo].[Account] Acc on Acc.Id = AFR.Account__c
  left join [PureDW_SFDC_staging].[dbo].[Feature__c] F on F.Id = AFR.Feature__c
  left join [PureDW_SFDC_staging].[dbo].[User] PSE on PSE.Id = F.PSE__c
  left join [PureDW_SFDC_staging].[dbo].[User] PM on PM.Id = F.PM__c
union 
SELECT 
      OFR.[Feature__c] [Feature_SFDCId]
	  , F.Name [Feature Number]
	  , cast (F.CreatedDate as Date) [Feature_CreatedDate] 
	  , PM.Name [PM] --, F.PM__c
	  , PSE.Name [PSE] --, F.PSE__c
	  , F.PSE_Territory__c [PSE Territory]
	  , F.Category__c [Category]
	  , F.Feature_Status__c [Feature Status]
	  , F.Title__c [Title]
	  , O.AccountId
	  , Acc.Name [Account]
      , OFR.[Opportunity__c] OpportunityID
	  , O.Name [Opportunity]
	  , O.StageName [Oppt Stage]
	  , O.Converted_Amount_USD__c Amount_USD
	  , O.Environment__c [General Use Case]
	  , O.General_Use_Case_Other__c [General Use Case Other]
	  , O.Environment_detail__c [Detail Use Case]
	  , cast (O.Solution_Use_Case__c as nvarchar(255)) [Solution Use Case]
	  , null as [Solution Use Case other]
--	  , OFR.Reviewed_By__c
--	  , OFR.Status__c
	  ,	OFR.[Id] [Request_SFDCId]
      , OFR.[Name] [Request_Name]
      , cast( OFR.[CreatedDate] as Date) [Request_Date]
  FROM [PureDW_SFDC_staging].[dbo].[Request__c] OFR
  left join [PureDW_SFDC_staging].[dbo].[Feature__c] F on F.Id = OFR.Feature__c
  left join [PureDW_SFDC_staging].[dbo].[Opportunity] O on O.Id = OFR.Opportunity__c
  left join [PureDW_SFDC_staging].[dbo].[Account] Acc on Acc.Id = O.AccountId
  left join [PureDW_SFDC_staging].[dbo].[User] PSE on PSE.Id = F.PSE__c
  left join [PureDW_SFDC_staging].[dbo].[User] PM on PM.Id = F.PM__c

--where OFR.CreatedDate > '2019-06-01'