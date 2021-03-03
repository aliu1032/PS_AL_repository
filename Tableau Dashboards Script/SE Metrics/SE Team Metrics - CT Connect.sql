select *
from 
(
			select CS.ctcoach__Assessed_Date__c Assessed_Date
				   , Assessee.Name [Assessee], CS.ctcoach__Assessee_Email__c [Assessee_Email], Assessee.EmployeeNumber [Assessee_EmployeeID], CS.ctcoach__Assessee__c [Assessee SFDC_Id]
				   , Assessor.Name [Assessor], CS.ctcoach__Assessor_Email__c [Assessor_Email], Assessor.EmployeeNumber [Assessor_EmployeeID], CS.ctcoach__Assessor__c [Assessor SFDC_Id]
				   , ctcoach__Assessment_Map_Name__c [Assessment Map], ctcoach__Average_Score__c [Score]
				   , BS.Behavior, BS.[Behavior Score]
				   , CS.ctcoach__Opportunity__c Oppt_Id, Oppt.Name Oppt_Name, Oppt.StageName, cast(Oppt.CloseDate as Date) Oppt_CloseDate, Oppt.Converted_Amount_USD__c
			from PureDW_SFDC_Staging.dbo.ctcoach__CT_Coach_Assessment__c CS
			left join PureDW_SFDC_Staging.dbo.[User] Assessee on Assessee.Id = CS.ctcoach__Assessee__c
			left join PureDW_SFDC_Staging.dbo.[User] Assessor on Assessor.Id = CS.ctcoach__Assessor__c
			left join GPO_TSF_Dev.dbo.vSE_Org SE on cast(SE.EmployeeID as varchar) = Assessee.EmployeeNumber
			left join GPO_TSF_Dev.dbo.vSE_Org SEM on cast(SEM.EmployeeID as varchar) = Assessor.EmployeeNumber
			left join PureDW_SFDC_Staging.dbo.[Opportunity] Oppt on Oppt.Id = CS.ctcoach__Opportunity__c

			left join (
			select ctcoach__Assessed_Date__c, ctcoach__Assessor_Email__c, ctcoach__Assessee_Email__c
				   , ctcoach__Behavior_Name__c [Behavior], ctcoach__Score__c [Behavior Score]
			from PureDW_SFDC_Staging.dbo.ctcoach__CT_Coach_Score__c
			) BS on BS.ctcoach__Assessed_Date__c = CS.ctcoach__Assessed_Date__c and BS.ctcoach__Assessor_Email__c = CS.ctcoach__Assessor_Email__c 
			        and BS.ctcoach__Assessee_Email__c = CS.ctcoach__Assessee_Email__c
) a
where a.Assessed_Date >= getdate()-90
-- a.Assessed_Date >= dateadd(day,-90, getdate())
--and A.Assessee_Email in ('mwertz@purestorage.com','bshowers@purestorage.com','smiddleton@purestorage.com')
and A.assessor in ('Ade Alli', 'Grant Wilson','Jeff Sherrod','Ted Pound')
--and A.Assessee_Email ='dshaffer@purestorage.com'
--and a.Assessment like 'PVR%'
order by a.Assessed_Date, a.Assessment
--where SE.Level3_Name = 'Scott Jobe'
--order by Assessee.Name, ctcoach__Behavior_Name__c


/* Debug */

			select cast(CS.CreatedDate as Date) CreatedDate, cast(ctcoach__Assessed_Date__c as Date) Assessed_Date
--				   , Assessee.Name [Assessee], ctcoach__Assessee_Email__c [Assessee_Email], Assessee.EmployeeNumber [Assessee_EmployeeID]
--				   , SE.Manager [Assessee_Manager], SE.Level3_Name Assessee_Director
--				   , Assessor.Name [Assessor], Assessor.EmployeeNumber [Assessor_EmployeeID]
--				   , SEM.Manager [Assessor_Manager], SEM.Level3_Name [Assessor_Director]
				   , ctcoach__Assessment_Map_Name__c [Assessment], ctcoach__Average_Score__c [Score], 'Sales Activity' as Type
				   , ctcoach__Opportunity__c Oppt_Id
			from PureDW_SFDC_Staging.dbo.ctcoach__CT_Coach_Assessment__c CS
--			left join PureDW_SFDC_Staging.dbo.[User] Assessee on Assessee.Id = CS.ctcoach__Assessee__c
--			left join PureDW_SFDC_Staging.dbo.[User] Assessor on Assessor.Id = CS.ctcoach__Assessor__c
			where ctcoach__Assessor_Email__c in ('aalli@purestorage.com','grant.wilson@purestorage.com','jeff.sherrod@purestorage.com','tpound@purestorage.com')

select Id, Name, ctcoach__Assessment_Map_Name__c, ctcoach__Assessee_Email__c, ctcoach__Average_Score__c
from PureDW_SFDC_staging.dbo.ctcoach__CT_Coach_Assessment__c
where ctcoach__Assessor_Email__c in ('aalli@purestorage.com','grant.wilson@purestorage.com','jeff.sherrod@purestorage.com','tpound@purestorage.com')
order by Name

select Id, Name, ctcoach__Behavior_Name__c, ctcoach__Assessee_Email__c, ctcoach__Score__c
from PureDW_SFDC_staging.dbo.ctcoach__CT_Coach_Score__c
where ctcoach__Assessor_Email__c in ('aalli@purestorage.com','grant.wilson@purestorage.com','jeff.sherrod@purestorage.com','tpound@purestorage.com')
order by Name


