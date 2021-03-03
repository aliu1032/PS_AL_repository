/*Certification */
-- FA Architect Associcate (starts with PCARA_)
-- FA Architect Professional (starts with FAP)   -- There is Expert with is higher than Professional
-- FB Architect Professional (starts with FBAP_)
-- 
with
#Contact_Pure_Certification as (
		Select CreatedDate, LastModifiedDate, Contact__c [Contact_Id], Certification, Exam_Grade__c, Exam_Date__c [Date_completed], Cert_Expiration_Date__c [Certification Expiration Date]
		from (
				select *, Row_Number() over (partition by Contact__c, Certification order by Exam_Date__c desc, CreatedDate Desc) as RN
					   from
						( -- clean up certification name --
						 Select CreatedDate, LastModifiedDate, Contact__c
						 		, Exam_Grade__c, cast(Exam_Date__c as Date) Exam_Date__c, cast(Cert_Expiration_Date__c as Date) Cert_Expiration_Date__c
								, case when (Exam_Code__c like 'PCARA_%') then 'Architect Associate'
					   				   when (Exam_Code__c like 'FAP_%') then 'FA Architect Professional'
					   				   when (Exam_Code__c like 'FAAE_%') then 'FA Architect Expert'
					   				   when (Exam_Code__c like 'FBAP_%') then 'FB Architect Professional'
					   				   
					   				   when (Exam_Code__c like 'FAIP_%') then 'FA Implementaion Professional'
					   				   when (Exam_Code__c like 'PCA_%') then 'FA Foundation'
					   				   when (Exam_Code__c like 'PCADA_%') then 'Adminstration Associate'
					   				   when (Exam_Code__c like 'PCIA_%') then 'Implementation Associate'
					   				   when (Exam_Code__c like 'PCSA_%') then 'Support Associate'
					   			  end [Certification]
					   			  --, Exam_Code__c, Exam_Name__c
						  from PureDW_SFDC_staging.dbo.Pure_Certification__c
						  where Contact__c is not null
						  and Exam_Code__c not like 'FAIP_%' and Exam_Code__c not like 'PCA_%'
						  and Exam_Code__c not like 'PCADA_%' and Exam_Code__c not like 'PCIA_%'
						  and Exam_Code__c not like 'PCSA_%'
						) clean_cert_name
			) latest_cert where RN = 1
)

Select CC.Id, CC.Name, CC.Role_Type__c [Role Type], P.Name [Partner]
	  , Cert.[Certification]
	  , Cert.[Date_completed], Cert.[Certification Expiration Date]
	  , P_CTM.Name [Partner CTM], C_CTM.Name [Contact CTM]
from PureDW_SFDC_staging.dbo.[Contact] CC
left join PureDW_SFDC_staging.dbo.[Account] P on P.Id = CC.AccountId				
left join #Contact_Pure_Certification Cert on Cert.Contact_Id = CC.Id
left join PureDW_SFDC_staging.dbo.[User] P_CTM on P_CTM.Id = P.Channel_Technical_Manager__c
left join PureDW_SFDC_staging.dbo.[User] C_CTM on C_CTM.Id = CC.Channel_Technical_Manager__c
where P.Type in ('Reseller','Distributor')

/***** Training ****/
with
#Contact_Pure_Training_Log as (
	Select  
		   LPR.Litmos__ContactID__c [SFDC_Id]
		   , LP.Name [Track_name]
		   , cast(LPR.Litmos__FinishDate__c as Date) [Date_completed]
		   -- , cast(LPR.Litmos__PercentageComplete__c as varchar) [Training Percentage Complete]
		   --, cast(LPR.Litmos__StartDate__c as date) [Training Start Date], cast(LPR.Litmos__FinishDate__c as Date) [Training Finish Date]
		   --, LPR.Litmos__Completed__c [Training Completed]
	from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LPR
	left join PureDW_SFDC_staging.dbo.Litmos__LearningPath__c LP on LP.Id = LPR.Litmos__LearningPathID__c
	where 
		LPR.Litmos__LearningPathID__c in ('aEf0z0000008OK1CAM', -- Pure Storage Sales Accreditation : Intro to Pure
										  'aEf0z000000XZHXCA4',	-- FlashBlade Basic : Intro to Pure
										  'aEf0z000000XZDQCA4', -- Pure Partner Foundation Technical : FA
										  'aEf0z000000XZHcCAO', -- Pure Partner Advanced Technical : FA
										  'aEf0z000000XZCcCAO', -- ActiveCluster Foundations : FA
										  'aEf0z000000XZDaCAO', -- FlashBlade Architect : FB
										  'aEf0z000000XZHSCA4', -- FlashBlade Enablement : FB
										  'aEf4W0000008OyuSAE',	-- FlashBlade Advanced : FB
										  'aEf0z000000XZHmCAO', -- Solution (Partners)
										  'aEf0z000000XZH8CAO'  -- Tools (Partners)
	 	)
		and LPR.Litmos__ContactID__c is not null
		and LPR.Litmos__Completed__c  = 'True'
)
-- need a cross check to display all training columns



Select CC.Id, CC.Name, CC.Role_Type__c [Role Type], P.Name [Partner], Train.[Track_name], Train.[Date_completed],
	   P_CTM.Name [Partner CTM], C_CTM.Name [Contact CTM]
from PureDW_SFDC_staging.dbo.[Contact] CC
left join PureDW_SFDC_staging.dbo.[Account] P on P.Id = CC.AccountId				
left join #Contact_Pure_Training_Log Train on Train.SFDC_Id = CC.Id
left join PureDW_SFDC_staging.dbo.[User] P_CTM on P_CTM.Id = P.Channel_Technical_Manager__c
left join PureDW_SFDC_staging.dbo.[User] C_CTM on C_CTM.Id = CC.Channel_Technical_Manager__c
where P.Type in ('Reseller','Distributor')






/**** All contacts ******/
Select CC.Id, CC.Name, CC.Role_Type__c [Role Type], P.Name [Partner]
	  , P_CTM.Name [Partner CTM], C_CTM.Name [Contact CTM]
from PureDW_SFDC_staging.dbo.[Contact] CC
left join PureDW_SFDC_staging.dbo.[Account] P on P.Id = CC.AccountId				
left join PureDW_SFDC_staging.dbo.[User] P_CTM on P_CTM.Id = P.Channel_Technical_Manager__c
left join PureDW_SFDC_staging.dbo.[User] C_CTM on C_CTM.Id = CC.Channel_Technical_Manager__c
where P.Type in ('Reseller','Distributor')