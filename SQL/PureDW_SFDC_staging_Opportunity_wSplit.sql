Select    Oppt.Id
	, Oppt.Name Opportunity
	, Oppt.Opportunity_Account_Name__c Acct_Name
	, RecType.Name RecordType
	, Oppt.Transaction_Type__c
	, Oppt.Type
	, Oppt.CurrencyIsoCode Oppt_Currency
	, Oppt.Amount
	, Oppt.Converted_Amount_USD__c
	, OpptUr.Name Oppt_Split_User
	, OpptUr.Territory_ID__c Oppt_Split_User_Territory_ID
	, OpptSplit.SplitPercentage
	, OpptSplit.CurrencyIsoCode Split_Currency
	, OpptSplit.SplitAmount
--	, Opptsplit.TC_Percent__c
--	, Opptsplit.TC_Amount__c
	, Oppt.StageName Stage
	, Oppt.ForecastCategoryName
	, Oppt.CloseDate
	, Oppt.Theater__c
	, Oppt.Division__c
	, Oppt.Sub_Division__c
	, AE.Name Acct_Exec
	, AE.Id Acct_Exec_SFDC_UserID
	, AE.Territory_ID__c AE_Territory_ID
	, AE.IsActive AE_IsActive
	, SE.Name SE_Oppt_Owner
	, SE.Id SE_Oppt_Owner_ID
--	, SE.Title SE_Title
	, SE.IsActive SE_IsActive
--	, Oppt.CreatedDate
	, Oppt.Risk_Lose_Risk__c
    , Oppt.Push_Risk__c
	, Oppt.Risk_Detail__c

from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE on SE_Opportunity_Owner__c = SE.Id
--left join [PureDW_SFDC_staging].[dbo].[UserRole] SE_Role on SE.UserRoleId = SE_Role.Id
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
left join [PureDW_SFDC_staging].[dbo].[User] OpptUr on OpptUr.Id = OpptSplit.SplitOwnerId
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
where Oppt.CloseDate >= '2019-02-01' 
--and Oppt.CloseDate < '03-01-2019'
--and Oppt.Theater__c = 'America''s'
and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
and OpptSplit.IsDeleted = 'False'
Order by Oppt.Theater__c, Oppt.Division__c, Oppt.Sub_Division__c