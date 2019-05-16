--- Opportunity by AE; Pull AEs' role hierarchy, Pull SEs' user-manager hierarchy
Select
	Oppt.Id
	, Oppt.Name Opportunity
	, Oppt.Opportunity_Account_Name__c Acct_Name
	, RecType.Name RecordType
	, Oppt.Type
	, Oppt.Transaction_Type__c
	, Oppt.CurrencyIsoCode
	, Oppt.Amount
	, Oppt.Converted_Amount_USD__c

	, Oppt.StageName Stage
	, Oppt.ForecastCategoryName
	, Oppt.CloseDate
	, Oppt.Theater__c Theater
	, Oppt.Division__c Division
	, Oppt.Sub_Division__c Sub_Division

	/* Opportunity Owner & information */

--    , Oppt.OwnerId AE_Id
	, AE.Name Acct_Exec
	, AE.Territory_ID__c Territory_ID
--	, AE.ForecastEnabled AE_ForecastEnabled
	, AE.IsActive AE_IsActive

	/* Opportunity SE owner & information */

--	, Oppt.SE_Opportunity_Owner__c SE_Id
	, SE.Name SE_Oppt_Owner
	, SE.IsActive SE_IsActive

--	, Oppt.Channel_Led_Deal__c
--	, Oppt.Registration__c
--	, Oppt.Direct_No_Channel_Partner__c
--	, Partner_AE.Name Partner_AE
--	, Partner_SE.Name Partner_SE
--	, Oppt.TQL_Lead__c
--	, Oppt.CreatedDate

from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
left join [PureDW_SFDC_staging].[dbo].[RecordType] RecType on RecType.Id = Oppt.RecordTypeId
left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE on SE_Opportunity_Owner__c = SE.Id
where Oppt.CloseDate >= '2019-02-01'
--and Oppt.CloseDate <= '2019-02-28'
and Oppt.Theater__c = 'America''s'
and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
Order by Oppt.Theater__c, Oppt.Division__c, Oppt.Sub_Division__c

