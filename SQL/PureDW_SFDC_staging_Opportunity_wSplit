Select    Oppt.Id
	, Oppt.Name Opportunity
	, Oppt.Opportunity_Account_Name__c Acct_Name
	, RecType.Name RecordType
	, Oppt.Transaction_Type__c
	, Oppt.Type
	, Oppt.CurrencyIsoCode Oppt_Currency
	, Oppt.Amount
	, OpptUr.Name Oppt_Split_User
	, OpptUr.Territory_ID__c Oppt_Split_User_Territory_Id
	, OpptSplit.CurrencyIsoCode Split_Currency
	, OpptSplit.SplitPercentage
	, OpptSplit.SplitAmount
	, Oppt.StageName Stage
	, Oppt.ForecastCategoryName
	, Oppt.CloseDate
	, Oppt.Theater__c
	, Oppt.Division__c
	, Oppt.Sub_Division__c
--    , Oppt.OwnerId AE_Id
--	, AE.UserRoleId
--	, AE_Level3.Name 'AE_Lvl3_Role'
--	, AE_Level2.Name 'AE_Lvl2_Role'
--	, AE_Level1.Name 'AE_Lvl1_Role'
	, AE_Role.Name 'AE_Role'
--	, AE_Lvl3.Name 'AE_Level3'
--	, AE_Lvl2.Name 'AE_Level2'	
--	, AE_Lvl1.Name 'AE_Level1'
	, AE.Name Acct_Exec
	, AE.Territory_ID__c Territory_ID
--	, AE.ForecastEnabled AE_ForecastEnabled
	, AE.IsActive AE_IsActive
--	, Oppt.SE_Opportunity_Owner__c SE_Id
--	, SE_Level3.Name 'SE_Level3'
--	, SE_Level2.Name 'SE_Level2'
--	, SE_Level1.Name 'SE_Level1'
	, SE.Name SE
--	, SE.Title SE_Title
	, SE.Theater__c SE_Theater
	, SE.Division SE_Division
	, SE.Sub_Division__c SE_Sub_Division
	, SE.Email
	, SE.IsActive SE_IsActive
	, SE_Role.Name 'SE_Role'
--	, Oppt.Channel_Led_Deal__c
--	, Oppt.Registration__c
--	, Oppt.Direct_No_Channel_Partner__c
--	, Partner_AE.Name Partner_AE
--	, Partner_SE.Name Partner_SE
--	, Oppt.TQL_Lead__c
--	, Oppt.CreatedDate
from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
left join [PureDW_SFDC_staging].[dbo].[UserRole] AE_Role on AE.UserRoleId = AE_Role.Id
left join [PureDW_SFDC_staging].[dbo].[UserRole] AE_Level1 on AE_Role.ParentRoleId = AE_Level1.Id
left join [PureDW_SFDC_staging].[dbo].[User] AE_Lvl1 on AE_Level1.ForecastUserId = AE_Lvl1.Id
left join [PureDW_SFDC_staging].[dbo].[UserRole] AE_Level2 on AE_Level1.ParentRoleId = AE_Level2.Id
left join [PureDW_SFDC_staging].[dbo].[User] AE_Lvl2 on AE_Level2.ForecastUserId = AE_Lvl2.Id
left join [PureDW_SFDC_staging].[dbo].[UserRole] AE_Level3 on AE_Level2.ParentRoleId = AE_Level3.Id
left join [PureDW_SFDC_staging].[dbo].[User] AE_Lvl3 on AE_Level3.ForecastUserId = AE_Lvl3.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE on SE_Opportunity_Owner__c = SE.Id
left join [PureDW_SFDC_staging].[dbo].[UserRole] SE_Role on SE.UserRoleId = SE_Role.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE_Level1 on SE.ManagerId = SE_Level1.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE_Level2 on SE_Level1.ManagerId = SE_Level2.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE_Level3 on SE_Level2.ManagerId = SE_Level3.Id
left join [PureDW_SFDC_staging].[dbo].[Contact] Partner_AE on Oppt.Partner_AE__c = Partner_AE.Id
left join [PureDW_SFDC_staging].[dbo].[Contact] Partner_SE on Oppt.Partner_SE__c = Partner_SE.Id
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
left join [PureDW_SFDC_staging].[dbo].[User] OpptUr on OpptUr.Id = OpptSplit.SplitOwnerId
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
where Oppt.CloseDate >= '2019-01-01'
--and Oppt.Theater__c = 'America''s'
and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
and SplitType.MasterLabel = 'Revenue'
and OpptSplit.IsDeleted = 'False'
Order by Oppt.Theater__c, Oppt.Division__c, Oppt.Sub_Division__c
