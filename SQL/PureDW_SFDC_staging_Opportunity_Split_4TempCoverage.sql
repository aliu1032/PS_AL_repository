SELECT OpptSplit.[Approval_Status__c]
      ,OpptSplit.[OpportunityId] Id
	  ,Ur.Name 'SE_Oppt_Owner'
	  ,Ur.Id 'SE_Oppt_Owner_ID'
	  ,SplitType.MasterLabel 'Opportunity Split Type'
      ,OpptSplit.[SplitPercentage]
      ,OpptSplit.[SplitAmount]
	  ,OpptSplit.[TC_Amount__c]
      ,OpptSplit.[Reason_Code__c]
      ,OpptSplit.[Split_Owner_Subdivision__c]
	  ,Ur.[Territory_ID__c] Split_Owner_Territory_ID
      ,OpptSplit.[Territory_ID__c] OpptSplit_Terr
  FROM [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit
  left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
  left join [PureDW_SFDC_staging].[dbo].[User] Ur on Ur.Id = OpptSplit.SplitOwnerId
  left join [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt on Oppt.Id = OpptSplit.OpportunityId
  where 
  Oppt.CloseDate >= '2019-02-01'
  and OpptSplit.IsDeleted = 'False'
  and Approval_Status__c = 'Yes'
  and SplitType.MasterLabel = 'Temp Coverage' 
  order by OpportunityId