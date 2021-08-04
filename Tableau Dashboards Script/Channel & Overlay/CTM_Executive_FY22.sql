/********* **************************/
/* Opportunity                      */
/********* **************************/
WITH

#Quote_Count (Oppt_Id, Quote_Created_Count, Partner_Quote_Created_Count)
as (
	Select [Oppt Id], count([Quote Id]) [Count Quotes Created], sum([Partner_Created_Quote]) [Count Partner Created Quote]
	from (
		Select Q.Id [Quote Id], Q.Name [Quote Name], Q.SBQQ__Opportunity2__c [Oppt Id], Q.CPQ_Opportunity_Name__c, Q.SBQQ__Primary__c, Q.Theater__c,
		Q.CPQ_Community_Quote__c, Case when Q.CPQ_Community_Quote__c = 'True' then 1 else 0 end [Partner_Created_Quote],
		CB.Name [Quote CreatedBy], CB.Email [Quote Creator Email]
		from PureDW_SFDC_Staging.dbo.SBQQ__Quote__c Q
		left join PureDW_SFDC_Staging.dbo.[User] CB on CB.Id = Q.CreatedById
	) t
	group by [Oppt Id]
),

#Oppt_MDE_Solution_Translate as (
	/* group the rows by Id + MDE_Solution Use Case */
	select Id, MDE_Solution--, count(*) [count]-- ROW_NUMBER() over (partition by Id, MDE_Solution order by Id, MDE_Solution) [ROW]
	from (
		/* translate solution use case into MDE use case */
		select Oppt.Id, MDE.MDE_Solution, ROW_Number() over (PARTITION by Oppt.Id, MDE.MDE_Solution order by Oppt.Id, MDE.MDE_Solution) [Row]
			from (
				/* split up Solution Use Case into rows */
				select Id, Solution_Use_Case__c, value [Solution_Use_Case]
				from PureDW_SFDC_Staging.dbo.Opportunity
				CROSS APPLY STRING_SPLIT(cast(Solution_Use_Case__c as varchar(2000)), ';')
				where CreatedDate >= '2018-02-01'
			) Oppt
		left join SalesOps_DM.dbo.CTM_MDE_Solution_Map MDE on MDE.Solution_Use_Case = Oppt.Solution_Use_Case
	) a where [ROW] = 1
	group by Id, MDE_Solution
),

#Oppt_MDE_Solution as (
	select Id, 
		STUFF((select '; ' + MDE_Solution
			   from #Oppt_MDE_Solution_Translate
			   where Id = B.Id
			   order by Id, MDE_Solution
			   for XML PATH(''),Type).value('(./text())[1]','Varchar(Max)'), 1,2, '') as Solution
		from #Oppt_MDE_Solution_Translate B
	group by Id
),

#Multi_Oppt as (
	select Partner_Account__c, AccountId, Multi_Oppt_on_Date, Partner_ToDate_Oppt_Count,
	case when RN = 1 then 'F' else 'T' end [Multi-Oppt_TF],
	case when RN = 1 then 0 else 1 end [Multi-Oppt]
	from (
			select Id, Name, Partner_Account__c, AccountId, cast(CreatedDate as date) Multi_Oppt_on_Date,
				   row_number() over (partition by Partner_Account__c, AccountId order by CreatedDate) RN,
				   count(id) over (partition by Partner_Account__c, AccountId) Partner_ToDate_Oppt_Count
			from PureDW_SFDC_Staging.dbo.Opportunity
			where Partner_Account__c is not null
			and (Amount > 0)
	) a where (RN = 1 and Partner_ToDate_Oppt_Count = 1) or (RN=2)
),

#Multi_Won as (
	Select Partner_Account__c, AccountId, Multi_Won_On_Date, Partner_ToDate_Won_Count, RN,
		   case when RN = 1 then 'F' else 'T' end [Multi-Won_TF],
		   case when RN = 1 then 0 else 1 end [Multi-Won]
	from (
			select Id, Name, Partner_Account__c, AccountId, cast(CloseDate as date) Multi_Won_On_Date, StageName,
				   row_number() over (partition by Partner_Account__c, AccountId order by CloseDate) RN,
				   count(id) over (partition by Partner_Account__c, AccountId) Partner_ToDate_Won_Count
			from PureDW_SFDC_Staging.dbo.Opportunity
		  where Partner_Account__c is not null
			and StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit')
			and Amount > 0
	) a where (RN = 1 and Partner_ToDate_Won_Count = 1) or (RN = 2)
),


#CSC_PoC as (
	select Opp_Id, [Number] [CSC PoC Number], State [CSC PoC State], created_at_date [CSC PoC CreatedDate], [SE First Name] + ' ' + [SE Last Name] [SE Requested CSC] from (
		select [SE First Name], [SE Last Name], [Email Address], Opp_ID, State, Number, created_at_Date,
			   ROW_NUMBER() over (partition by Opp_Id order by created_at_Date desc) rn
		from Datascience_Workbench_Views.dbo.v_csc_poc_clean
		where Opp_ID is not null
		) a where a.rn = 1
	)



select a.*,
	Case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff (year, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' year'
	end [Relative_CloseYear],
	 
	Case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' quarter'
	end [Relative_CloseQtr],

	Case when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(month, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(month, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' month'
	end [Relative_CloseMonth]

	
	, MO.Multi_Oppt_on_Date
	, Case when MO.Partner_ToDate_Oppt_Count is null then 0 else MO.Partner_ToDate_Oppt_Count end Partner_ToDate_Oppt_Count
	, Case when MO.[Multi-Oppt_TF] is null then 'F' else MO.[Multi-Oppt_TF] end [Multi-Oppt_TF]
	, Case when MO.[Multi-Oppt] is null then 0 else MO.[Multi-Oppt] end [Multi-Oppt]

	, MW.Multi_Won_On_Date
	, Case when MW.Partner_ToDate_Won_Count is null then 0 else MW.Partner_ToDate_Won_Count end Partner_ToDate_Won_Count
	, Case when MW.[Multi-Won_TF] is null then 'F' else MW.[Multi-Won_TF] end [Multi-Won_TF]
	, Case when MW.[Multi-Won] is null then 0 else MW.[Multi-Won] end [Multi-Won]
	
from (
		select C.Id [Partner_SE_Id], 
		Upper(left(C.FirstName,1)) + Lower(substring(C.FirstName, 2, len(C.FirstName)-1)) + ' ' +
		Upper(left(C.LastName,1)) + Lower(substring(C.LastName, 2, len(C.LastName)-1)) [Partner SE],  -- Contact First and Last Name are blank

		C.Email [Partner SE Email], C.Role_type__c [Assigned Role],

		/* take the Partner information from Oppt, as it is more obvious when a user cross check an oppt */
--		C.AccountId [Partner Id],  C_Acct.Name [Partner Name], 
--		case when C_Acct.Partner_Tier__c is null then 'None' else C_Acct.Partner_Tier__c end as [Partner Tier], 
--		C_Acct.Type [Partner Type],
--		C_Acct.Theater__c [Partner Theater], C_Acct.Sub_Division__c [Partner SubDivision],
		
		[Partner Id] = COALESCE(Oppt.[Partner Id], C.AccountId),
		[Partner Name] = coalesce(Oppt.[Partner Name], C_Acct.Name),
		[Partner Tier] = coalesce(Oppt.[Partner Tier], C_Acct.Partner_Tier__c, 'None'),
		[Partner Cloud Category] = coalesce(Oppt.[Cloud Category], C_Acct.[Cloud_Category__c], 'None'),
		[Partner Type] = coalesce(Oppt.[Partner Type], C_Acct.Type),
		[Partner Theater] = coalesce(Oppt.[Partner Theater], C_Acct.Theater__c),
		[Partner SubDivision] = COALESCE(Oppt.[Partner SubDivision], C_Acct.Sub_Division__c),
		[PTM] = COALESCE(Oppt.PTM, C_Acct_PTM.Name),
		
		Oppt.Distributor_Account__c, Oppt.Disti,

		case when (Oppt.Disti is not null and Oppt.[Parent Disti] is null) then 'Other'
			 when (Oppt.Disti is not null and Oppt.[Parent Disti] is not null) then Oppt.[Parent Disti]
	 		 else null
		end as [Parent Disti],
		
		case when (Oppt.Disti is not null and Oppt.[Parent Disti] is null) then 'Other'
			 when (Oppt.Disti is not null and Oppt.[Parent Disti] is not null) then Oppt.[Parent Disti Theater]
			 else null
		end as [Parent Disti Theater],

		Oppt.Id [Oppt Id], Oppt.[Oppt_Name], Oppt.Customer, Oppt.Oppt_AccountId,
		Oppt.RecType, Oppt.Product, Oppt.Mfg, Oppt.Type, Oppt.Solution, 
		Oppt.Theater, Oppt.Sub_Division, Oppt.[Partner AE],
		Oppt.CreatedDate, Oppt.CloseDate, Oppt.[Fiscal Created Month], Oppt.[Fiscal Close Month],
		Oppt.StageName, left(Oppt.StageName, 7) Stage,
		Oppt.Eval_Stage__c,
		
		case 
		when Oppt.Eval_Stage__c in ('POC Installed') then 'POC in progress'
		when Oppt.Eval_Stage__c in ('POC Uninstalled', 'POC Give-Away', 'POC Converted to Sale') then 'POC Completed'
		when Oppt.Eval_Stage__c is null or Oppt.Eval_Stage__c in ('No POC') then 'No POC' 
		when Oppt.Eval_Stage__c in ('POC Potential') then 'Potential'
		else 'Error' end as [POC],
		
		Oppt.[CSC PoC Number], Oppt.[CSC PoC State], Oppt.[CSC PoC CreatedDate],
		
		Oppt.CurrencyIsoCode, Oppt.Amount, Oppt.Amount_in_USD,

		case when Oppt.Amount_in_USD is null then 'Null'
			 when Oppt.Amount_in_USD  <= 100000 then '<=$100K'
			 when ((Oppt.Amount_in_USD  > 100000) and (Oppt.Amount_in_USD  <=500000)) then '$100K - $500K'
			 when Oppt.Amount_in_USD  > 500000 then '>$500K'
		end as Deal_Size_Bin,

		case when Oppt.Channel_Led_Deal__c = 'true' then 1 else 0 end [CLed Deal],
		case when Oppt.Partner_Sourced__c = 'true' then 1 else 0 end [Partner Sourced], --when CAM convert a Partner registrated oppt to a SFDC oppt, the checkbox is checked
		
		Oppt.Quote_Created_Count, 
		Oppt.Partner_Quote_Created_Count,
		Case when Oppt.Partner_Quote_Created_Count > 0 then 'T' else 'F' end [Partner created quote],

		case 
		 	 when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
		 	 when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss, Disqualified, Undecided'
			 else 'Open'
		end [StageGroup],
		
		
		case when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 else 0 end Won_Count,
		
		case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 1 else 0 end Loss_Count,
		case when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit','Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 0 else 1 end Open_Count,

		case when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then Oppt.Amount_in_USD else 0 end as Revenue,
		DateFromParts(Year(DateAdd(month, 11, GetDate())), Month(DateAdd(month, 11, GetDate())), 1) as [Current Fiscal Month]

		from PureDW_SFDC_Staging.dbo.Contact C
		left join PureDW_SFDC_Staging.dbo.Account C_Acct on C_Acct.Id = C.AccountId
		left join PureDW_SFDC_Staging.dbo.[User] C_Acct_PTM on C_Acct_PTM.Id = C_Acct.Channel_Technical_Manager__c
		
		full outer join (
					Select O.Id, O.Name [Oppt_Name], Rec.Name RecType, EU_Acct.Name [Customer], EU_Acct.Id [Oppt_AccountId]
					, O.Product_Type__c [Product], O.Manufacturer__c [Mfg], O.[Type]
					, case
					  when (O.Manufacturer__c = '' or O.Manufacturer__c is null) then 'Product not reported'
					  when (O.Manufacturer__c = 'Pure Storage') then 
							case when (O.Product_Type__c = 'FlashBlade') then 
									case when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
										 when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
										 when O.Environment_detail__c in ('Analytics & AI', 'HPC & Technical Computing', 'Media & Entertainment', 'DB', 'Health Care') then 'Activate Real-Time Analytics and AI'
										 else 'Use case not reported'
									 end
							when (O.Product_Type__c = 'FlashArray') then
									case when O.Environment_detail__c in ('DB', 'Healthcare') then 'Accelerate Core Applications'
										 when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
										 when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
										 when O.Environment_detail__c in ('Analytics & AI', 'HPC & Technical Computing', 'Media & Entertainment') then 'Activate Real-Time Analytics and AI'
										 else 'Use case not reported'
									end
							else 'Product Not reported'
							end
					  else O.Manufacturer__c
					  end [Solution]
					  
					, CSC_PoC.[CSC PoC Number], CSC_PoC.[CSC PoC State], CSC_PoC.[CSC PoC CreatedDate]

					, cast(O.CreatedDate as Date) CreatedDate, cast(O.CloseDate as Date) CloseDate
					, DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey,1,4) as int), cast(substring(CloseDate_445.FiscalMonthKey,5,2) as int), 1) [Fiscal Close Month]
					, DateFromParts(cast(substring(CreateDate_445.FiscalMonthKey,1,4) as int), cast(substring(CreateDate_445.FiscalMonthKey,5,2) as int),1) [Fiscal Created Month]				
										
					/* calculate Today's reference */
					, DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey,1,4) as int), cast(substring(TodayDate_445.FiscalMonthKey,5,2) as int), 1) [Current Fiscal Year-Month],
					O.StageName, O.Eval_Stage__c,
					O.CurrencyIsoCode, O.Amount, O.Converted_Amount_USD__c Amount_in_USD,
					O.Theater__c Theater, O.Sub_Division__c Sub_Division,
					O.Partner_Sourced__c, O.Channel_Led_Deal__c,

				    O.Partner_Account__c [Partner Id], P.Name [Partner Name],
					P.Partner_Tier__c [Partner Tier], P.Cloud_Category__c [Cloud Category],
				    P.Type [Partner Type],  /* User Oppt.Partner Account. Impact the Partner SE may be grouped into a different account, the Partner SE count could impacted */
				    P.Theater__c [Partner Theater], P.Sub_Division__c [Partner SubDivision], PTM.Name [PTM],
				    
					O.Partner_SE__c,
					Partner_AE.Name [Partner AE],
					Dist.Name [Disti],
					Dist_UL.Disti [Parent Disti], Dist_UL.Theater [Parent Disti Theater],
					O.Distributor_Account__c,
					Dist.Ultimate_Parent_Id__c [UL Id],
					
					QC.Quote_Created_Count, 
					QC.Partner_Quote_Created_Count
					
					from PureDW_SFDC_Staging.dbo.Opportunity O
					left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
					left join PureDW_SFDC_Staging.dbo.Account P on P.Id = O.Partner_Account__c
					left join PureDW_SFDC_Staging.dbo.[User] PTM on PTM.Id = P.Channel_Technical_Manager__c
					left join PureDW_SFDC_Staging.dbo.[Contact] Partner_AE on Partner_AE.Id = O.Partner_AE__c
					left join PureDW_SFDC_Staging.dbo.Account Dist on Dist.Id = O.Distributor_Account__c
					left join SalesOps_DM.dbo.CTM_Disti_Map Dist_UL on Dist_UL.Child_Account_Id = O.Distributor_Account__c
					
					left join PureDW_SFDC_Staging.dbo.Account EU_Acct on EU_Acct.Id = O.AccountId
					
					left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, O.CreatedDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)
					
					left join #Quote_Count QC on QC.Oppt_Id = O.Id
					left join #Oppt_MDE_Solution Sol on Sol.Id = O.Id
					left join #CSC_PoC CSC_PoC on CSC_PoC.Opp_Id = O.Id
					
					where 
					O.CloseDate >= '2018-02-01'
					and Rec.Name in ('Sales Opportunity','ES2 Opportunity')
					and O.Partner_Account__c is not null  --- Selecting Capax and PaaS Oppt where Partner Account is stamped
				   ) Oppt on C.Id = Oppt.Partner_SE__c --and C.AccountId = Oppt.Partner_Account__c
		) a
	left join #Multi_Oppt MO on MO.Partner_Account__c = a.[Partner Id] and MO.AccountId = a.[Oppt_AccountId]
	left join #Multi_Won MW on MW.Partner_Account__c = a.[Partner Id] and MW.AccountId = a.[Oppt_AccountId]

where
a.[Partner Type] in ('Reseller','Distributor')
				  





select min(Date_ID) [FirstDay], Max(Date_ID) [LastDay]
				  from NetSuite.dbo.DM_Date_445_With_Past
				  where FiscalYear = '2021' and FiscalMonth = '10' --the N_th month


/**************************************/
/*                                    */
/* CTM/NPTM favorite > PTM_Assignment */
/*                                    */
/**************************************/
/*  select Name , Partner_Id
  from SalesOps_DM.dbo.CTM_Favorite
*/
  select CTM.Name [PTM], A.Id [Partner_Id]
  from PureDW_SFDC_staging.dbo.Account A
  left join PureDW_SFDC_Staging.dbo.[User] CTM on CTM.Id = A.Channel_Technical_Manager__c
  where A.Channel_Technical_Manager__c is not null


/**********************************************/
/* FA Foundation & Professional Certification */
/**********************************************/  
select P.Id [Partner Id], P.Name [Partner Name], P.Type, P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater]
	,  C.Name [Contact],Cert.Email_Corporate__c,  Cert.Exam_Code__c, Cert.Exam_Group__c, Cert.Exam_Name__c, Cert.Exam_Grade__c, cast(Cert.Exam_Date__c as Date) [Exam Date]
	, case when Cert.Exam_Code__c in ('FAP_001', 'FAP_002') then 'FA Professional'
		   when Cert.Exam_Code__c in ('PCA_001', 'PCA_Acc001', 'PCADA_001', 'PCARA_001') then 'FA Associate'
		   when Cert.Exam_Code__c in ('FAAE_001') then 'FA Expert'
		   when Cert.Exam_Code__c in ('FAIP_001', 'FAIP_002', 'PCIA_001') then 'FA Implementation'
		   when Cert.Exam_Code__c in ('FBAP_001') then 'FB Professional'
		   when Cert.Exam_Code__c in ('PCSA_001') then 'Support Assoicate' -- exclude in the report
		   else 'Other' end [Pure Certification]
from PureDW_SFDC_Staging.dbo.Pure_Certification__c Cert
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Cert.Contact__c
left join PureDW_SFDC_Staging.dbo.Account P on P.Id = C.AccountId
where Contact__c is not NULL
and P.[Type] in ('Reseller', 'Disti')
--, 'PCA_001', 'FAP_001', )

/* rolling 12 months, # of Partner SE completing the certifications */
-- FAP_001, FAP_002, PCARA_001
;

select C.Name, A.Name [Account], L.Litmos__Finished__c, LM.Litmos__Description__c, L.Litmos__LitmosID__c, LM.Litmos__ModuleTypeDesc__c
from PureDW_SFDC_Staging.dbo.Litmos__UserModuleResult__c L
left join PureDW_SFDC_Staging.dbo.Litmos__ModuleNew__c LM on LM.Id = L.Litmos__ModuleNewID__c
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = L.Litmos__ContactID__c
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
where A.[Type] in ('Reseller', 'Disti')
and LM.Litmos__Active__c = 'True'
and L.Litmos__Finished__c >= '2019-01-01'
order by L.Litmos__Finished__c desc


/* Users Learning Path Result */ 
Select C.Name [Contact], C.Id [Contact Id], A.Name [Partner], LP.Name [Path Name], LPR.Litmos__PercentageComplete__c, LPR.Litmos__StartDate__c, LPR.Litmos__FinishDate__c
from PureDW_SFDC_Staging.dbo.Litmos__UserLearningPathResult__c LPR
left join PureDW_SFDC_Staging.dbo.[Contact] C on C.Id = LPR.Litmos__ContactID__c
left join PureDW_SFDC_Staging.dbo.[Account] A on A.Id = C.AccountId
left join PureDW_SFDC_Staging.dbo.Litmos__LearningPath__c LP on LP.Id = LPR.Litmos__LearningPathID__c
where LPR.Litmos__ContactID__c is not null
and A.[Type] in ('Reseller', 'Disti')
and LP.Litmos__LitmosID__c in ('88650', '86123', '78513', '70972', '70973')
--and C.Id = '0030z00002XLzRbAAL'


/**********************************************/
/* Pure Test Drive Partner Usage              */
/*                 Partner Adoption           */
/**********************************************/  
with
#SFDC_Contact as (
	select * from (
		select Id, Name, Email, AccountId,
			   ROW_NUMBER() over (partition by Email order by CreatedDate desc) RN
		  from PureDW_SFDC_staging.dbo.Contact
		  where Email is not null and IsDeleted = 'False'
	) a where RN = 1
),

#Partner_first_use as (
	select [Created by user name], cast([Created at] as Date) [First Use], [Created by company type],
		   [FiscalYear] [First Use FiscalYear], [FiscalQuarterName] [First Use FiscalQuarter], [FiscalMonth] [First Use Month],
		   rn, [Use Cnt]
	from (
		select [Created by], [Created by user name], [Created by company type], convert(date, [Created at], 20) [Created at],
--			   cast(convert(date, [Created at], 20) as datetime) + cast(convert(time, [Created at], 20) as datetime) [Created at],	
			   [FiscalYear], [FiscalQuarterName], [FiscalMonth],
			   ROW_NUMBER() over (PARTITION by [Created by user name] order by [Created at]) rn,
			   COUNT(*) over (PARTITION by [Created by user name]) [Use Cnt]
		from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
	) a where a.rn = 1  
),


#TD_Report_Period as (
	select Date_ID, FiscalYear + ' Q' + FiscalQuarter [TestDrive_FiscalCreatedQuarter], cast([FiscalMonthKey] + '01' as date) [TestDrive_FiscalCreatedMonth] from (
		select Date_ID, FiscalYear, FiscalQuarter, [FiscalMonth], [FiscalMonthKey],
		ROW_NUMBER() over (partition by FiscalYear, FiscalQuarter, [FiscalMonthKey] order by Date_ID) rn
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= convert(varchar, dateadd(month, -23, getdate()), 112) and Date_ID <= convert(varchar, getdate(), 112)
	) a where rn = 1
)


select #TD_Report_Period.[TestDrive_FiscalCreatedQuarter], #TD_Report_Period.[TestDrive_FiscalCreatedMonth],
	   a.[Contact Id], a.[Created by user Name], a.[Created by company type], a.[Created at], a.[Lab name], a.[Product],
	   a.[Created By], a.[Contact Name], a.[Contact Email], a.[Partner Name], a.[Type],
/*	   case when a.[Partner Name] is null then null
	        else case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
	   end [Partner Tier],
*/
	   case when A.Type in ('Reseller','Distributor')
		 then
			case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
			else 'Is not a Channel Partner'
		end [Partner Tier],
	   a.[Partner Theater], a.[Partner Id],
	   a.[Use Cnt]
from #TD_Report_Period
left join (
	select test_drive.*,
		   C.Id [Contact Id], 
		   COALESCE(C.Name, test_drive.[Created By]) [Contact Name], C.Email [Contact Email],
		   P.Name [Partner Name], P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater], P.Id [Partner Id], P.Type
			from (
					/* select the Test Drive run by Partner Users */
					select U.[Created by], U.[Created by user name],
						   case when U.[Created by user name] like '%.p3' then substring(U.[Created by user name], 1, len(U.[Created by user name])-3)
						   	    else U.[Created by user name]
						   end Created_By_User_Name,
						   U.[Created by company type], U.[Created at],
						   (cast([FiscalYear] as varchar(4)) + ' ' + [FiscalQuarterName]) [TestDrive_FiscalCreatedQuarter],
						   cast((cast([FiscalYear] as varchar(4)) + 
						   		 right('0000' + cast([FiscalMonth] as varchar(2)), 2)
						   		 + '01') as date) [TestDrive_FiscalCreatedMonth],
						   [Lab name], [Product], FU.[Use Cnt]
					from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values U
					left join #Partner_first_use FU on FU.[Created by user name] = U.[Created by user name]
					where U.[Created by company type] = 'Channel partner'
					and U.[Created by] not like 'Pure Storage%'
			) test_drive
	left join #SFDC_Contact C on C.Email = test_drive.Created_By_User_Name
	left join PureDW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
) a on a.TestDrive_FiscalCreatedQuarter = #TD_Report_Period.[TestDrive_FiscalCreatedQuarter] and a.[TestDrive_FiscalCreatedMonth] = #TD_Report_Period.[TestDrive_FiscalCreatedMonth]
where #TD_Report_Period.[TestDrive_FiscalCreatedQuarter] like '2020%'
order by #TD_Report_Period.[TestDrive_FiscalCreatedQuarter]

/**************************************************/
/* FA Sizer Log in GPO                            */
/* report # of FA Sizer created by Partner Users  */ 
/**************************************************/  
with
#SFDC_Contact as (
	select * from (
		select Id, Name, Email, AccountId,
			   ROW_NUMBER() over (partition by Email order by CreatedDate desc) RN
		  from PureDW_SFDC_staging.dbo.Contact
		  where Email is not null and Email not like '%delete%' and IsDeleted = 'False'
	) a where RN = 1
),

#Report_Period as (
	select Date_ID, FiscalYear + ' Q' + FiscalQuarter [FASizer_FiscalCreatedQuarter], cast([FiscalMonthKey] + '01' as date) [FASizer_FiscalCreatedMonth] from (
		select Date_ID, FiscalYear, FiscalQuarter, [FiscalMonth], [FiscalMonthKey],
		ROW_NUMBER() over (partition by FiscalYear, FiscalQuarter, [FiscalMonthKey] order by Date_ID) rn
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >=  convert(varchar, dateadd(month, -23, getdate()), 112) and Date_ID <= convert(varchar, getdate(), 112)
	) a where rn = 1
)

select #Report_Period.[FASizer_FiscalCreatedQuarter], #Report_Period.[FASizer_FiscalCreatedMonth], a.[Sizer_Session_Id], a.datemin, a.sizeraction
	   , a.[Contact Id], a.[Contact Name], a.[Contact Email]
	   , a.[Partner Id], a.[Partner Name]
	   , case when A.Type in ('Reseller','Distributor')
		 then
			case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
			else 'Is not a Channel Partner'
		end [Partner Tier]
	   , a.[Partner Theater]
	   , a.[Type]
from #Report_Period
left join (
			select convert(char(8), datemin, 112) [SizerCreate_Date_ID]
				   , (FiscalYear + ' Q' + FiscalQuarter) [Sizer_FiscalCreatedQuarter]
				   , cast((cast([FiscalYear] as varchar(4)) + right('0000' + cast([FiscalMonth] as varchar(2)), 2) + '01') as date) [Sizer_FiscalCreated_Month]
				   , Sizer.Id [Sizer_Session_Id], Sizer.datemin, Sizer.sizeraction
				   , C.Id [Contact Id], C.Name [Contact Name], Sizer.email [Contact Email]
				   , P.Id [Partner Id], P.Name [Partner Name], P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater], P.Type
				from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action Sizer
				left join #SFDC_Contact C on C.Email = Sizer.email
				left join PureDW_SFDC_Staging.dbo.[Account] P on P.Id = C.AccountId
				left join NetSuite.dbo.DM_Date_445_With_Past FiscalDate on FiscalDate.Date_ID = convert(char(8), datemin, 112)
				where Sizer.email not like '%purestorage.com' and Sizer.email != ''
				  and Sizer.sizeraction= 'Create Sizing'
--				  and Sizer.datemin >= '2020-11-30' and Sizer.datemin < '2020-12-27'
) a on a.[Sizer_FiscalCreatedQuarter] = #Report_Period.[FASizer_FiscalCreatedQuarter] and a.[Sizer_FiscalCreated_Month] = #Report_Period.[FASizer_FiscalCreatedMonth]