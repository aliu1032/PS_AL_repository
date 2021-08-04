/***************************************************************************/
/***                                                                     ***/
/***    Based                                                            ***/
/***                                                                     ***/
/***    Contact who is Partner SE Role                                   ***/
/***    or                                                               ***/
/***    Appeal in Partner SE field on                                    ***/
/***    Sales Opportunity & ES2, closed since FY20                       ***/
/***                                                                     ***/
/***************************************************************************/

With
/***** Contact who we are interested ****/
#Report_Contact as (
		Select C.Id 
		from PureDW_SFDC_Staging.dbo.[Contact] C
		left join PuredW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
		where P.Type in ('Reseller','Distributor')
		and C.Role_Type__c in ('Partner SE') or C.Participate_in_Wavemaker_programme__c = 'Yes'
		
		Union
		
		Select distinct(O.Partner_SE__c) [Id]
		from PureDW_SFDC_staging.dbo.Opportunity O
		left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
		where O.Partner_SE__c is not null
		and  RecT.Name in ('Sales Opportunity','ES2 Opportunity')
		and  O.CloseDate >= '2019-02-01'
)

Select C.Id [Contact_Id], Owner.Name [Contact Owner], C.IsDeleted, C.Owner_Is_Active__c
  	 , C.Name [Contact], C.Role_Type__c [Assigned Role], C.Email [Contact Email]
  	 , case when C.Participate_in_Wavemaker_programme__c = 'Yes' then 'Yes' else null end [Wavemaker Participtant]
  	 , C.Wavemaker_level__c [Wavemaker level]
  	 , C_Acct.Id [PartnerId], C_Acct.Name [Partner Name], P_CTM.Name [Partner PTM], C_Acct.Partner_Tier__c [Partner Tier]
  	 , C_Acct.Type [Partner Type] 
  	 , C_CTM.Name [Contact PTM]
     , C.MailingCity [Contact City]
     , coalesce(C.MailingState, ' ') as [Contact State], C.MailingPostalCode [Contact PostalCode]
     , coalesce(C.MailingCountry, ' ') as [Contact Country]
     , left(C_User.Id,15) [Contact_UserId]
from PureDW_SFDC_staging.dbo.[Contact] C
left join PureDW_SFDC_Staging.dbo.[Account] C_Acct on C_Acct.Id = C.AccountId
left join PureDW_SFDC_Staging.dbo.[User] P_CTM on P_CTM.Id = C_Acct.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] C_CTM on C_CTM.Id = C.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] Owner on Owner.Id = C.OwnerId
left join PureDW_SFDC_Staging.dbo.[User] C_User on C_User.ContactId = C.Id
where C.Id in (Select * from #Report_Contact)
and C_Acct.Name != 'HIDDEN'
and C.Name = 'Jonathan Kowall'


/***************************************************************************/
/***                                                                     ***/
/***    Select Contacts associated with Reseller & Distributor accounts  ***/
/***                                                                     ***/
/***    Contact Training and Certification                               ***/
/***    1. CTM Led Training captured by Campaign                         ***/
/***    2. Self paced Training captured in Litmos                        ***/
/***    3. Certification from Pure_Certification                         ***/
/***                                                                     ***/
/***    Include Wavemaker Partcipant flag and level                      ***/
/***    Prepare dataset with a cross join to show accreditation of all   ***/
/***    interested training & certification                              ***/
/***                                                                     ***/
/***************************************************************************/

With

/***** Contact who we are interested ****/
#Report_Contact as (
		Select C.Id 
		from PureDW_SFDC_Staging.dbo.[Contact] C
		left join PuredW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
		where P.Type in ('Reseller','Distributor')
		and C.Role_Type__c in ('Parter SE')
		
		Union
		
		Select distinct(O.Partner_SE__c) [Id]
		from PureDW_SFDC_staging.dbo.Opportunity O
		left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
		where O.Partner_SE__c is not null
		and  RecT.Name in ('Sales Opportunity','ES2 Opportunity')
		and  O.CloseDate >= '2019-02-01'
),

#Report_Contact_Accreditation as (
	Select * from #Report_Contact
		cross JOIN		
		(
			SELECT Accreditation, [Type], [Display_Order], PurePractice_SE_Track, Wavemaker_Champion, Wavemaker_Legend, PostSales_Services_Certifications -- Program
			FROM SalesOps_DM.dbo.PartnerSE_RequiredCertification
			--WHERE Program != 'None'
		) A
),

/***** Training ****/
#Contact_Pure_Training as (

	/*** CTM Led Training ***/
			select Mem.ContactId, 'Pure Storage Sales Accreditation' [Track_name]
				   , cast(Mem.FirstRespondedDate as Date) [Date_completed]
				   , C_User.Id [CUser_Id]
			--     , Cam.Name [Campaign], Cam.Description, Mem.CompanyOrAccount, Mem.Name, Mem.Email, Mem.Status, 
			from PureDW_SFDC_staging.dbo.CampaignMember Mem
			left join PureDW_SFDC_staging.dbo.Campaign Cam on Cam.Id = Mem.CampaignId
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = Mem.ContactId
			where Cam.Name like '%Pure Partner Foundations Sales%'
			and Mem.ContactId is not null
			and Mem.status not in ('Cancelled','Didn''t Attend', 'No Show')

			Union

			select Mem.ContactId, 'Pure Partner Foundations Technical' [Track_name]
				  , cast(Mem.FirstRespondedDate as Date) [Date_completed]
				  , C_User.Id [CUser_Id]
			--       Cam.Name [Campaign], Cam.Description, Mem.CompanyOrAccount, Mem.Name, Mem.Email, Mem.Status,
			from PureDW_SFDC_staging.dbo.CampaignMember Mem
			left join PureDW_SFDC_staging.dbo.Campaign Cam on Cam.Id = Mem.CampaignId
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = Mem.ContactId
			where Cam.Name like '%Pure Partner Foundations Tech%'
			and Mem.ContactId is not null
			and Mem.status not in ('Cancelled','Didn''t Attend', 'No Show')

			Union

			select Mem.ContactId, 'Pure Partner Advanced Technical' [Track_name],
				   cast(Mem.FirstRespondedDate as Date) [Date_completed], C_User.Id [CUser_Id]
			--       Cam.Name [Campaign], Cam.Description, Mem.CompanyOrAccount, Mem.Name, Mem.Email, Mem.Status, 
			from PureDW_SFDC_staging.dbo.CampaignMember Mem
			left join PureDW_SFDC_staging.dbo.Campaign Cam on Cam.Id = Mem.CampaignId
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = Mem.ContactId
			where  Cam.Id = '7014W0000014nyrQAA' -- Foundation Advanced Tech
			and Mem.ContactId is not null
			and Mem.status not in ('Cancelled','Didn''t Attend', 'No Show')

			Union

			select Mem.ContactId, 'FlashBlade Architect' [Track_name]
				   , cast(Mem.FirstRespondedDate as Date) [Date_completed]
				   , C_User.Id [CUser_Id]
				   --Cam.Name [Campaign], Cam.Description, Mem.CompanyOrAccount, Mem.Name, Mem.Email, Mem.Status,
			from PureDW_SFDC_staging.dbo.CampaignMember Mem
			left join PureDW_SFDC_staging.dbo.Campaign Cam on Cam.Id = Mem.CampaignId
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = Mem.ContactId
			where Cam.Name like '%FlashBlade Architect%'
			and Mem.ContactId is not null
			and Mem.status not in ('Cancelled','Didn''t Attend', 'No Show')

			Union

			select Mem.ContactId, 'Tools (Partners)' [Track_name]
				   , cast(Mem.FirstRespondedDate as Date) [Date_completed]
				   , C_User.Id [CUser_Id]
				   --Cam.Name [Campaign], Cam.Description, Mem.CompanyOrAccount, Mem.Name, Mem.Email, Mem.Status,
			from PureDW_SFDC_staging.dbo.CampaignMember Mem
			left join PureDW_SFDC_staging.dbo.Campaign Cam on Cam.Id = Mem.CampaignId
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = Mem.ContactId
			where Cam.Id = '7014W0000014o34QAA' -- Tools Workshop
			and Mem.status not in ('Cancelled','Didn''t Attend', 'No Show')

			Union

	/***Self paced Training learning path***/

			Select  
				   LPR.Litmos__ContactID__c [ContactId]
				   , LP.Name [Track_name]
				   , cast(LPR.Litmos__FinishDate__c as Date) [Date_completed]
				   -- , cast(LPR.Litmos__PercentageComplete__c as varchar) [Training Percentage Complete]
				   --, cast(LPR.Litmos__StartDate__c as date) [Training Start Date], cast(LPR.Litmos__FinishDate__c as Date) [Training Finish Date]
				   --, LPR.Litmos__Completed__c [Training Completed]
				   , C_User.Id [CUser_Id]
			from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LPR
			left join PureDW_SFDC_staging.dbo.Litmos__LearningPath__c LP on LP.Id = LPR.Litmos__LearningPathID__c
			left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = LPR.Litmos__ContactID__c
			where 
				LPR.Litmos__LearningPathID__c in ('aEf0z0000008OK1CAM', -- Pure Storage Sales Accreditation : Intro to Pure (74608)
												  'aEf0z000000XZHXCA4',	-- FlashBlade Basics : Intro to Pure (91659)
												  'aEf0z000000XZDQCA4', -- Pure Partner Foundations Technical : FA (89058)
												  'aEf0z000000XZCcCAO', -- ActiveCluster Foundations : FA (88155)
												  'aEf0z000000XZHcCAO', -- Pure Partner Advanced Technical : FA (91671)
												  'aEf0z000000XZDaCAO', -- FlashBlade Architect : FB (89060)
												  'aEf0z000000XZHSCA4', -- FlashBlade Enablement : FB (91658)
												  'aEf4W0000008OyuSAE',	-- FlashBlade Advanced : FB (92765)
												  'aEf0z000000XZHmCAO', -- Solution (Partners) (91941)
												  'aEf0z000000XZH8CAO' -- Tools (Partners) (90868)
			 	)
				and LPR.Litmos__ContactID__c is not null
				and LPR.Litmos__Completed__c  = 'True'
		 UNION
		 
	/*** Self paced training course */
				
		 select Litmos__ContactID__c [ContactId]
		 	   , cast(Course_Name__c as varchar(100)) [Track_name]
		 	   , cast(Litmos__FinishDate__c as date) [Date_completed]
		 	   , C_User.Id [CUser_Id]
		 	  -- , LRM.Litmos__ProgramID__c,   Litmos__status__c, Litmos__User_Name__c
			  --, Litmos__CompliantTillDate__c
		from PureDW_SFDC_staging.dbo.Litmos__UserProgramResult__c LRC
		left join PureDW_SFDC_staging.dbo.[User] C_User on C_User.ContactId = LRC.Litmos__ContactID__c
		where 
			Litmos__ProgramID__c in ('aEn4W000000CfuUSAS', 'aEn4W000000Cg5qSAC') -- Pure As-A-Service (Basic), FlashBlade Implementation Training Assessment
			and Litmos__Completed__c = 'true'
			and Litmos__ContactID__c is not null -- Contact's record
),

#Contact_Pure_Certification as (
		Select CreatedDate, LastModifiedDate, Contact__c [ContactId], Certification, Exam_Grade__c, Exam_Date__c [Date_completed], Cert_Expiration_Date__c [Certification Expiration Date]
		from (
				select *, Row_Number() over (partition by Contact__c, Certification order by Exam_Date__c desc, CreatedDate Desc) as RN
					   from
						( -- clean up certification name --
						 Select CreatedDate, LastModifiedDate, Contact__c
						 		, Exam_Grade__c, cast(Exam_Date__c as Date) Exam_Date__c, cast(Cert_Expiration_Date__c as Date) Cert_Expiration_Date__c
								, case when (Exam_Code__c like 'PCARA_%') then 'Architect Associate Certificate' --
					   				   when (Exam_Code__c like 'FAP_%') then 'FA Architect Professional Certificate' --
					   				   when (Exam_Code__c like 'FAAE_%') then 'FA Architect Expert Certificate'
					   				   when (Exam_Code__c like 'FBAP_%') then 'FB Architect Professional Certificate' --
					   				   when (Exam_Code__c like 'FAIP_%') then 'FA Implementation Professional Certificate'
									   when (Exam_Code__c like 'PCIA_%') then 'Implementation Associate Certificate'
					   				   
					   				   when (Exam_Code__c like 'PCA_%') then 'Pure Storage Foundation Certificate' --
					   				   when (Exam_Code__c like 'PCADA_%') then 'Adminstration Associate Certificate'
					   				   when (Exam_Code__c like 'PCSA_%') then 'Support Associate Certificate'
					   			  end [Certification]
					   			  --, Exam_Code__c, Exam_Name__c
						  from PureDW_SFDC_staging.dbo.Pure_Certification__c
						  where Contact__c is not null
						  --and (Exam_Code__c like 'PCARA_%' or Exam_Code__c like 'FAP_%' or Exam_Code__c like 'FAAE_%' or Exam_Code__c like 'FBAP_%')
						) clean_cert_name
			) latest_cert where RN = 1 
)


/** Accreditation **/
-- need a column for all 'interested' training and certification
-- need to remove duplicate and take the latest completion

Select #Report_Contact_Accreditation.Id [Contact_Id], #Report_Contact_Accreditation.Display_Order
	   , #Report_Contact_Accreditation.Accreditation, #Report_Contact_Accreditation.[Type], #Report_Contact_Accreditation.[PurePractice_SE_Track]
	   , #Report_Contact_Accreditation.[Wavemaker_Champion],#Report_Contact_Accreditation.[Wavemaker_Legend]
	   , #Report_Contact_Accreditation.[PostSales_Services_Certifications]
	   , a.Date_Completed, a.[Date_Expired],
       case when datediff(day,a.[Date_Expired], getdate()) <= 90 then 'Certificate expire soon' else null end [Cert_Reminder] 
from (
	Select *,
		   ROW_NUMBER() over (PARTITION by Contact_Id, Accreditation order by Date_Completed desc) RN
	from (
			Select ContactId [Contact_Id], Date_Completed, Track_Name [Accreditation], null as Date_Expired from #Contact_Pure_Training
			Union 
			Select ContactId [Contact_Id], Date_Completed, Certification [Accreditation], [Certification Expiration Date] Date_Expired from #Contact_Pure_Certification
	) dup 
) a
right join #Report_Contact_Accreditation on #Report_Contact_Accreditation.Accreditation = a.Accreditation and #Report_Contact_Accreditation.Id = a.Contact_Id
where (a.RN = 1 or a.RN is null)
and #Report_Contact_Accreditation.Accreditation like '%Imple%'


/* flatten the training & certification record */
		Select C.Id [Contact_Id]
			   , T1.[Sales Accreditation], T2.[FlashBlade Basics]
			   , FA1.[Foundations Technical], FA2.[Advanced Technical], FA3.[ActiveCluster Foundations]
			   , FB1.[FlashBlade Architect], FB2.[FlashBlade Enablement], FB3.[FlashBlade Advanced]
			   , B4.[Solution Training], B5.[Tools Training]
			   
			   , C1.[FA Architect Associate], C2.[FA Architect Professional], C3.[FA Architect Expert], C4.[FB Architect Professional], C5.[Pure Storage Foundation]
		
		from #Report_Contact C
		left join (Select ContactId, Date_Completed [Sales Accreditation] from #Contact_Pure_Training where Track_Name = 'Pure Storage Sales Accreditation') T1 on T1.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FlashBlade Basic] from #Contact_Pure_Training where Track_Name = 'FlashBlade Basics') T2 on T2.ContactId = C.Id
		
		left join (Select ContactId, Date_Completed [Foundation Technical] from #Contact_Pure_Training where Track_Name = 'Pure Partner Foundations Technical') FA1 on FA1.ContactId = C.Id
		left join (Select ContactId, Date_Completed [Advanced Technical] from #Contact_Pure_Training where Track_Name = 'Pure Partner Advanced Technical') FA2 on FA2.ContactId = C.Id
		left join (Select ContactId, Date_Completed [ActiveCluster Foundations] from #Contact_Pure_Training where Track_Name = 'ActiveCluster Foundations') FA3 on FA3.ContactId = C.Id
		
		left join (Select ContactId, Date_Completed [FlashBlade Architect] from #Contact_Pure_Training where Track_Name = 'FlashBlade Architect') FB1 on FB1.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FlashBlade Enablement] from #Contact_Pure_Training where Track_Name = 'FlashBlade Enablement') FB2 on FB2.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FlashBlade Advanced] from #Contact_Pure_Training where Track_Name = 'FlashBlade Advanced') FB3 on FB3.ContactId = C.Id

		left join (Select ContactId, Date_Completed [Solution Training] from #Contact_Pure_Training where Track_Name = 'Solution (Partners)') B4 on B4.ContactId = C.Id
		left join (Select ContactId, Date_Completed [Tools Training] from #Contact_Pure_Training where Track_Name = 'Tools (Partners)') B5 on B5.ContactId = C.Id
		
		left join (Select ContactId, Date_Completed [Architect Associate] from #Contact_Pure_Certification where Certification = 'Architect Associate Certificate') C1 on C1.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FA Architect Professional] from #Contact_Pure_Certification where Certification = 'FA Architect Professional Certificate') C2 on C2.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FA Architect Expert] from #Contact_Pure_Certification where Certification = 'FA Architect Expert Certificate') C3 on C3.ContactId = C.Id
		left join (Select ContactId, Date_Completed [FB Architect Professional] from #Contact_Pure_Certification where Certification = 'FB Architect Professional Certificate') C4 on C4.ContactId = C.Id
		left join (Select ContactId, Date_Completed [Foundation Certification] from #Contact_Pure_Certification where Certification = 'Pure Storage Foundation Certificate') C5 on C5.ContactId = C.Id

		
/***************************************************************************/
/***                                                                     ***/
/***    Opportunity                                                      ***/
/***                                                                     ***/
/***************************************************************************/

With
#Quote_Count (Oppt_Id, Quote_Created_Count, Partner_Quote_Created_Count)
as (
	Select [Oppt Id], count([Quote Id]) [Count Quotes Created], sum([Partner_Created_Quote]) [Count Partner Created Quote]
	from (
		Select Q.Id [Quote Id], Q.Name [Quote Name], Q.SBQQ__Opportunity2__c [Oppt Id], Q.CPQ_Opportunity_Name__c, Q.SBQQ__Primary__c, Q.Theater__c,
		Q.CPQ_Community_Quote__c, Case when Q.CPQ_Community_Quote__c = 'True' then 1 else 0 end [Partner_Created_Quote],
		CB.Name [Quote CreatedBy], CB.Email [Quote Creator Email]
		from PureDW_SFDC_Staging.dbo.SBQQ__Quote__c Q
		left join PureDW_SFDC_Staging.dbo.[User] CB on CB.Id = Q.CreatedById
		/* where 
		Created_Date__c >= '2020-04-01'
		cast(Q.Theater__c as varchar(50)) = 'America''s'
		and SBQQ__Opportunity2__c = '0060z000022vrhpAAA'
		*/
	) t
	group by [Oppt Id]
),


#CSC_PoC as (
	select Opp_Id, [Number] [CSC PoC Number], State [CSC PoC State], created_at_date [CSC PoC CreatedDate], [SE First Name] + ' ' + [SE Last Name] [SE Requested CSC]
	from (
			select [SE First Name], [SE Last Name], [Email Address], Opp_ID, State, Number, created_at_Date,
				   ROW_NUMBER() over (partition by Opp_Id order by created_at_Date desc) rn
			from Datascience_Workbench_Views.dbo.v_csc_poc_clean
			where Opp_ID is not null
		  ) a where a.rn = 1
)	



Select a.*,

	Case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' quarter'
	end [Relative_CloseQtr],

	Case when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(month, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(month, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' month'
	end [Relative_CloseMonth]

from ( 
	Select
		O.Id [Oppt Id], O.Name [Oppt_Name],
		RecT.Name RecType, O.[Type] , SE.Name [Pure SE Oppt Owner], SE.Manager__c [Pure SEM],
		EU_Acct.Name [Customer], EU_Acct.MDM_Segment__c, EU_Acct.Segment__c, EU_Acct.EMEA_Segment__c,
		EU_Acct.MDM_Vertical__c, EU_Acct.MDM_Sub_Vertical__c, EU_Acct.Vertical__c, EU_Acct.Sub_vertical__c, EU_Acct.Id [Account Id], 		

		O.Manufacturer__c [Mfg],
	    case when O.CBS_Category__c is not null and O.CBS_Category__c != 'NO CBS' then 'Cloud Block Store'
			 when RecT.Name = 'ES2 Opportunity' then 'Pure-as-a-Service'
			 else O.Product_Type__c
		end [Product],

		case when O.Manufacturer__c != 'Pure Storage' then null
		     else
		     	case when O.CBS_Category__c is not null and O.CBS_Category__c != 'NO CBS' then 'Cloud Block Store'
			 	when RecT.Name = 'ES2 Opportunity' then 'Pure-as-a-Service'
			 	else O.Product_Type__c
			 	end
		end [Pure Product],
		
		case
			when (O.Manufacturer__c = '' or O.Manufacturer__c is null) then 'Product not reported'
			when (O.Manufacturer__c = 'Pure Storage') then
				case
					when (O.Product_Type__c = 'FlashBlade') then
						case
							when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
							when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
							when O.Environment_detail__c in ('Analytics & AI',
							'HPC & Technical Computing',
							'Media & Entertainment',
							'DB',
							'Health Care') then 'Activate Real-Time Analytics and AI'
							else 'Use case not reported'
						end
					when (O.Product_Type__c = 'FlashArray') then
						case
							when O.Environment_detail__c in ('DB',
							'Healthcare') then 'Accelerate Core Applications'
							when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
							when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
							when O.Environment_detail__c in ('Analytics & AI',
							'HPC & Technical Computing',
							'Media & Entertainment') then 'Activate Real-Time Analytics and AI'
							else 'Use case not reported'
						end
					else 'Product Not reported'
				end
			else O.Manufacturer__c
		end [Solution],
		
		cast(O.CreatedDate as Date) CreatedDate,
		cast(O.CloseDate as Date) CloseDate, 'FY' + substring(O.Close_Fiscal_Quarter__c,6,2) + ' ' + left(O.Close_Fiscal_Quarter__c,2) [Fiscal Close Quarter],
		'FY' + substring(O.Close_Fiscal_Quarter__c,6,2) [Fiscal Close Year],
		DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey, 1, 4) as int),
					  cast(substring(CloseDate_445.FiscalMonthKey, 5, 2) as int), 1) [Fiscal Close Month] ,
		DateFromParts(cast(substring(CreateDate_445.FiscalMonthKey, 1, 4) as int),
					  cast(substring(CreateDate_445.FiscalMonthKey, 5, 2) as int), 1) [Fiscal Created Month], /* calculate Today's reference */
		DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey, 1, 4) as int),
					  cast(substring(TodayDate_445.FiscalMonthKey, 5, 2) as int), 1) [Current Fiscal Month],
		O.StageName, O.Eval_Stage__c,
		--O.CurrencyIsoCode, O.Amount,
		O.Converted_Amount_USD__c Amount_in_USD,

		--case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Partner_Sourced__c = 'true' then 1 else 0 end [Won Partner Sourced],
		case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Partner_Sourced__c = 'true' then O.Id else Null end [Won Partner Sourced],
		case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Partner_Sourced__c = 'true' then O.Converted_Amount_USD__c else Null end [Partner Sourced Booking$],
		case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Manufacturer__c = 'Pure Storage' then O.Product_Type__c else null end [Won Product],
		case when cast(substring(O.StageName,7,1) as Int) <= 7 and O.Partner_Sourced__c = 'true' then 1 else 0 end [Open Partner Sourced],
		case when cast(substring(O.StageName,7,1) as Int) <= 7 then O.Product_Type__c else null end [Open Product],
		
		case 
			 when O.StageName is null then null
		 	 when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
		 	 when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss, Disqualified, Undecided'
			 else 'Open'
		end [StageGroup],
		
		case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 else 0 end [Won Count],
		case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 1 else 0 end [Loss Count],
		case when O.StageName is null then 0
		     when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit','Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 0 
		     else 1 end [Open Count],

		case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then O.Converted_Amount_USD__c else 0 end as Booking$,
		case when O.StageName is null then 0
		     when cast(substring(O.StageName, 7,1) as int) < 8 then O.Converted_Amount_USD__c end as Open$,
		     
	
		O.Theater__c Theater, O.Division__c Division, O.Sub_Division__c Sub_Division,
		
		O.Partner_Sourced__c [Partner Sourced], O.Channel_Led_Deal__c [Channel Led], O.Partner_Account__c [Partner Id],
		P.Name [Partner Name], P.Partner_Tier__c [Partner Tier], P.Type [Partner Type],

		A_CTM.Name [Partner PTM],
		/* User O.Partner Account. Impact the Partner SE may be grouped into a different account, the Partner SE count could impactedn */
		P.Theater__c [Partner Theater], P.Sub_Division__c [Partner SubDivision],
		O.Partner_SE__c, O.Partner_SE_Engagement_Level__c [Partner Engagement Level],
		
		O.Competition__c [Competition], O.Reason_s_for_Win_Loss__c [Reason for Win/Loss],
		
	 	QC.Quote_Created_Count, QC.Partner_Quote_Created_Count,
		CSC_PoC.[CSC PoC Number], CSC_PoC.[CSC PoC State], CSC_PoC.[CSC PoC CreatedDate]

	from PureDW_SFDC_Staging.dbo.Opportunity O
	left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
	left join PureDW_SFDC_Staging.dbo.Account P on P.Id = O.Partner_Account__c
	left join PureDW_SFDC_Staging.dbo.[User] A_CTM on A_CTM.Id = P.Channel_Technical_Manager__c
	left join PureDW_SFDC_Staging.dbo.Account EU_Acct on EU_Acct.Id = O.AccountId
	left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
	left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, O.CreatedDate, 112)
	left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)
	left join #Quote_Count QC on QC.Oppt_Id = O.Id
	left join #CSC_PoC CSC_PoC on CSC_PoC.Opp_Id = O.Id
	where O.CloseDate >= '2019-02-01'
	  and RecT.Name in ('Sales Opportunity', 'ES2 Opportunity')
	  and O.Partner_Account__c is not null
		--- Selecting Capax and PaaS Oppt where Partner Account is stamped
) a
	


/***************************************************************************/
/***                                                                     ***/
/***    Test Drive Usage                                                 ***/
/***                                                                     ***/
/***************************************************************************/
select Status, [Instance], [Lab name], [Product]
--, [Created at]
, case when [Created at] is null then null
	   when [Created at] like '2%' then convert(datetime, left([Created at],19))
	   else convert(datetime, [Created at]) --'text' 
  end [Created at]
--, [Deleted at]
, case when [Deleted at] is null then null
	   when [Deleted at] like '2%' then convert(datetime, left([Deleted at],19))
	   else convert(datetime, [Deleted at]) --'text' 
  end [Deleted at]
, datediff(minute,[Created at], [Deleted at]) [Duration]
, [Created by], [Created by user name]
, case when [Created by user name] like '%.p3' then left([Created by user name], len([Created by user name])-3) else [Created by user name] end [Created by Email]
, [created by company type]
, FiscalMonth, FiscalYear
, [Presented to company], [Presented to user], [Opportunity ID]
from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
where [Created by company type] in ('Customer', 'Channel partner')
  and [Created by] like 'Charles%'
  
  = 'chasali@cdw.com'

  
/***************************************************************************/
/***                                                                     ***/
/***    FA Sizer                                                         ***/
/***                                                                     ***/
/***************************************************************************/
  
select cast(max(datemin) as date) [Last connect], email [Created by Email], sizeraction, count(*) [Count]
  from [GPO_TSF_Dev ].dbo.v_fa_sizer_rs_action
where email not like '%@purestorage.com'
  and sizeraction in ('Create Scenarios', 'Create Sizing')
	and email = 'mrhirst17@gmail.com'
  group by email, sizeraction


/***************************************************************************/
/***                                                                     ***/
/***    36 Insight Report                                                ***/
/***                                                                     ***/
/***************************************************************************/
Select Report_date, ID, Name, Email, Company, WM_Level, User_Id, 
       Balance [Annual Points Earned],
       Date_of_Registration [Date of Registration],
       Last_Login [Last Login],
       Awarded_for_claims [Content/Activity points],
       Awarded_for_prizes [Points from games],
       [IsDisti?],
       PTM_Id,
       PTM_name,
       [Activated?],
       Log_in_count [Login count]
FROM [SalesOps_DM].[dbo].[WaveMake_Rpt_Insight]

/***************************************************************************/
/***                                                                     ***/
/***    360 Activity Report                                              ***/
/***                                                                     ***/
/***************************************************************************/
Select Report_date, User_Id, Activity, state, [Type], [Category], points_approved
from [SalesOps_DM].[dbo].[Wavemaker_Activity_Report]
where state in ('approved_l1','approved_l2', 'pending_l2')

  