
/***************************************************************************/
/***    Partner Contacts & Opportunities                                 ***/
/***    Partner's contact of Account where Type = Reseller, Distributor  ***/
/***    and their Opportunity created since FY2019 and                   ***/
/***    Opportunity closed date >= FY2019 & FY2020                       ***/
/***    Contact outer join with opportunity on Partner_SE                ***/
/***************************************************************************/

with
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
			where
			Partner_Account__c is not null
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
		  where
			Partner_Account__c is not null
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

/*************************/
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
		
		Oppt.Distributor_Account__c, Oppt.Disti,

		case when (Oppt.Disti is not null and Oppt.[Parent Disti] is null) then 'Other'
			 when (Oppt.Disti is not null and Oppt.[Parent Disti] is not null) then Oppt.[Parent Disti]
	 		 else null
		end as [Parent Disti],
		
		case when (Oppt.Disti is not null and Oppt.[Parent Disti] is null) then 'Other'
			 when (Oppt.Disti is not null and Oppt.[Parent Disti] is not null) then Oppt.[Parent Disti Theater]
			 else null
		end as [Parent Disti Theater],
		
		case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 'Trained' else '' end [FlashArray Architect Professional], -- SE, Nedit
		case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 1 else 0 end [FlashArray Architect Professional Count], -- SE, Nedit

		case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 'Trained' else '' end [FlashArray Implementation Professional], -- SE, Nedit
		case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 1 else 0 end [FlashArray Implementation Professional Count], -- SE, Nedit

		case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 'Trained' else '' end [Pure Foundation Certification Exam], -- SE, Nedit
		case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 1 else 0 end [Pure Foundation Certification Exam Count], -- SE, Nedit

		case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 'Trained' else '' end [Capacity sizing proficiency], -- SE, Edit
		case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 1 else 0 end [Capacity sizing proficiency Count], -- SE, Edit

		case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 'Trained' else '' end[TCO/Evergreen Proficiency] , -- SE, Edit
		case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 1 else 0 end[TCO/Evergreen Proficiency Count], -- SE, Edit

		case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 'Trained' else '' end [Perform PureTEC GUI demo], -- SE, Edit
		case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 1 else 0 end [Perform PureTEC GUI demo Count], -- SE, Edit

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
		Oppt.[Pipeline to Close Age],

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
		
		full outer join (
					Select O.Id, O.Name [Oppt_Name], Rec.Name RecType, EU_Acct.Name [Customer], EU_Acct.Id [Oppt_AccountId]
					, O.Product_Type__c [Product], O.Manufacturer__c [Mfg], O.[Type]
/*					, case
					  when (O.Manufacturer__c = '' or O.Manufacturer__c is null) then 'Not reported'
					  when (O.Manufacturer__c = 'Pure Storage') then 
							case when (O.Product_Type__c = 'FlashBlade') then 
									case when O.Environment_detail__c in ('Backup Target / Fast Restore') then 'Modernization Data Protection' else 'Activate Real-Time Analytics and AI' end
							when (O.Product_Type__c = 'FlashArray') then
									case when O.Environment_detail__c in ('DB', 'Healthcare', 'VDI') then 'Accelerate Core Applications'
									when O.Environment_detail__c in ('Backup Target / Fast Restore') then 'Modernization Data Protection'
									else 'Activate Real-Time Analytics and AI'
									end
							else 'Not reported'
							end
					  else O.Manufacturer__c
					  end [Solution]
*/							
					, case
					  when (O.Manufacturer__c = '' or O.Manufacturer__c is null) then 'Not reported'
					  when (O.Manufacturer__c = 'Pure Storage') then 
							case when (O.Product_Type__c = 'FlashBlade') then 
									case when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
										 when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
										 else 'Activate Real-Time Analytics and AI'
									 end
							when (O.Product_Type__c = 'FlashArray') then
									case when O.Environment_detail__c in ('DB', 'Healthcare') then 'Accelerate Core Applications'
										 when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
										 when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
										 else 'Activate Real-Time Analytics and AI'
									end
							else 'Not reported'
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
					O.Partner_Sourced__c, O.Channel_Led_Deal__c, O.Age_Pipeline_to_Close__c [Pipeline to Close Age],

				    O.Partner_Account__c [Partner Id], P.Name [Partner Name],
					P.Partner_Tier__c [Partner Tier], P.Cloud_Category__c [Cloud Category],
				    P.Type [Partner Type],  /* User Oppt.Partner Account. Impact the Partner SE may be grouped into a different account, the Partner SE count could impacted */
				    P.Theater__c [Partner Theater], P.Sub_Division__c [Partner SubDivision],
				    
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
a.[Partner Cloud Category] in ('3-Public Cloud (IaaS)', '4-Hosted Private Cloud') and
a.[Oppt Id] is not null
--and a.[Oppt Id] in (
--'0060z00001w4bT3AAI',
--'0060z00001w4bT8AAI'
--)
--and a.[Oppt Id] in ('0060z000020v6ixAAA')
--and a.[Partner created quote] = 'T'

/**********************************************************************/
/* All Opportunity Closed in FY2020 */
/**********************************************************************/
select O.id , O.Name Oppt_Name, Rec.Name RecType, cast(O.CreatedDate as Date) CreatedDate, cast(O.CloseDate as Date) CloseDate,
--O.Close_Quarter__c [Close Quarter],
DateFromParts( Year(DateAdd(month, 11, O.CloseDate)), Month(DateAdd(month, 11, O.CloseDate)), 1 ) [Fiscal Close Month],
DateFromParts( Year(DateAdd(month, 11, O.CreatedDate)), Month(DateAdd(month, 11, O.CreatedDate)), 1 ) [Fiscal Created Month],
O.StageName Stage, O.ForecastCategoryName, O.CurrencyIsoCode, O.Amount, O.Converted_Amount_USD__c Amount_in_USD,
case when Converted_Amount_USD__c is null then 'Null'
	 when Converted_Amount_USD__c <= 100000 then '<=$100K'
	 when ((Converted_Amount_USD__c > 100000) and (Converted_Amount_USD__c <=500000)) then '$100K - $500K'
	 when Converted_Amount_USD__c > 500000 then '>$500K'
end as Deal_Size_Bin,
O.Theater__c Theater, O.Sub_Division__c Sub_Division, 
-- A.Name Account [End Customer],
O.Partner_Account__c, P.Name [Partner Name],
P.D_B_City_Name__c [Partner City], P.D_B_State_Province_Abbreviation__c [Partner State], P.D_B_Country_Name__c [Partner Country],
P.Theater__c [Partner Theater], P.Authorized_Partner__c [Authorized Partner], P.Type,
case when O.Partner_Account__c is null then 'No Partner info'
	 else
		case when P.Partner_Tier__c is null then 'None' else P.Partner_Tier__c end
	end [Partner Tier],

case when O.Partner_Account__c is null then 'No Partner info'
	else
		case when P.Partner_Tier__c = 'Elite' then 'Elite' else 'Not' end
end [Elite Partner],

Partner_AE.Name [Partner AE],  Partner_SE.Id [Partner_SE_Id],
Upper(left(Partner_SE.FirstName,1)) + Lower(substring(Partner_SE.FirstName, 2, len(Partner_SE.FirstName)-1)) + ' ' +
Upper(left(Partner_SE.LastName,1)) + Lower(substring(Partner_SE.LastName, 2, len(Partner_SE.LastName)-1)) [Partner SE],
Partner_SE.[Role_Type__c] [Role],

case when O.Partner_Account__c is null then 0 else 1 end as [Partner Name Available],
case when O.Partner_SE__c is null then 0 else 1 end as [Partner SE identified],

case when Partner_SE.Partner_Class__c is null then '' else Partner_SE.Partner_Class__c end [Partner Class],

case when (O.Partner_SE__c is not null and Partner_SE.PPR_FlashArray_Architect_Professional__c = 'True') then 'Trained' else '' end [FlashArray Architect Professional], -- SE, Nedit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_FlashArray_Architect_Professional__c = 'True') then 1 else 0 end [FlashArray Architect Professional Count], -- SE, Nedit

case when (O.Partner_SE__c is not null and Partner_SE.PPR_FlashArray_Implementation_Prof__c = 'True') then 'Trained' else '' end [FlashArray Implementation Professional], -- SE, Nedit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_FlashArray_Implementation_Prof__c = 'True') then 1 else 0 end [FlashArray Implementation Professional Count], -- SE, Nedit

case when (O.Partner_SE__c is not null and Partner_SE.PPR_Pure_Foundation_Certification_Exam__c = 'True') then 'Trained' else '' end [Pure Foundation Certification Exam], -- SE, Nedit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_Pure_Foundation_Certification_Exam__c = 'True') then 1 else 0 end [Pure Foundation Certification Exam Count], -- SE, Nedit

case when (O.Partner_SE__c is not null and Partner_SE.PPR_Sizing_Configuration_Proficiency__c = 'True') then 'Trained' else '' end [Capacity sizing proficiency], -- SE, Edit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_Sizing_Configuration_Proficiency__c = 'True') then 1 else 0 end [Capacity sizing proficiency Count], -- SE, Edit

case when (O.Partner_SE__c is not null and Partner_SE.PPR_TCO_Evergreen_Proficiency__c = 'True') then 'Trained' else '' end[TCO/Evergreen Proficiency] , -- SE, Edit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_TCO_Evergreen_Proficiency__c = 'True') then 1 else 0 end [TCO/Evergreen Proficiency Count], -- SE, Edit

case when (O.Partner_SE__c is not null and Partner_SE.PPR_Perform_PureTEC_GUI_demo__c = 'True') then 'Trained' else '' end [Perform PureTEC GUI demo], -- SE, Edit
case when (O.Partner_SE__c is not null and Partner_SE.PPR_Perform_PureTEC_GUI_demo__c = 'True') then 1 else 0 end [Perform PureTEC GUI demo Count], -- SE, Edit

case when O.Channel_Led_Deal__c = 'true' then 1 else 0 end [CLed Deal],
case when O.Partner_Sourced__c = 'true' then 1 else 0 end [Partner Sourced], --when CAM convert a Partner registrated oppt to a SFDC oppt, the checkbox is checked
case 
	when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
	when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss, Disqualified, Undecided'
	else 'Open'
end [Won/Loss],

case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 else 0 end Won_Count,
case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 1 else 0 end Loss_Count,
case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit','Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 0 else 1 end Open_Count,
O.Age_Pipeline_to_Close__c [Pipeline to Close Age]

from PureDW_SFDC_Staging.dbo.Opportunity O
left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = O.AccountId
left join PureDW_SFDC_Staging.dbo.Contact Partner_AE on Partner_AE.Id = O.Partner_AE__c
left join PureDW_SFDC_Staging.dbo.Contact Partner_SE on Partner_SE.Id = O.Partner_SE__c
left join PureDW_SFDC_STaging.dbo.Account P on P.Id = O.Partner_Account__c
where (O.CloseDate >= '2019-02-01')
-- or (O.CloseDate >='2018-02-01' and O.CloseDate <= GetDate()))
and Rec.Name in ('Sales Opportunity','ES2 Opportunity')


/***********************************/
/* Campaign                        */
/***********************************/

  Declare @CTM_List TABLE(item nvarchar(50))
  insert into @CTM_List(item) values ('Julie Rosenberg'), ('Steven Heusser'), ('Steve Heusser'), ('Chad Short'), ('Bruce Modell'),
									 ('Dana Thews'), ('Greg Davidson'), ('Gregory Davidson'), ('James Siejk'),
									 ('John DiCostanzo'), ('Shane Harris'), ('Mike Vahey'), ('Frank Mueller'),
									 ('Jan Tveit'), ('Maciej Kot'),('Max Brown'),
									 ('Michel Chalogany'), ('Mohamed Eissa'), ('Umberto Galtarossa'),
									 ('Victor Sanchez'), ('Shuichi Nanri'), ('Osamu Mizoguchi'),
									 ('Shunsuke Ikoma'), ('Alex Yung'), ('Darren Ou'),
									 ('Francis Kwang'), ('Denny Jaya'), ('Richard Noh'), ('SK Cheung'), ('Tarso Dos Santos'),
									 ('Mark Hirst'), ('Markus Wolf'), ('Yi-Shuen'), ('YiShuen Chin'),('Nathan Hall'),('Carl McQuillan'),
									 ('George Lopez'), ('April Liu')

  Select cast(CP.CreatedDate as Date) CreatedDate, 
  cast(CP.StartDate as Date) StartDate, cast(CP.EndDate as Date) EndDate,
  CP.Id, CP.Name [Campaign Name],
  O.Name [Owner Name], O.Email [Owner Email],
  AE.Name [AE Owner], AE.Email [AE Email], Acc.Theater__c [Partner Theater], Acc.Sub_Division__c [Partner SubDivision],
  CP.Theater__c, CP.Region__c, CP.Sub_Division__c, CP.Program__c [Program Type],CP.Type [Tatic],  CP.Campaign_Program__c [Global Campaign],
  CP.Partner_Account_Association__c, Acc.Name [Partner Account Association],
  CP.Description, CP.Department_Code__c,
  CP.IsActive [Active], CP.Status
   FROM [PureDW_SFDC_Staging].[dbo].[Campaign] CP
   left join PureDW_SFDC_Staging.dbo.[User] O on O.Id = CP.OwnerId
   left join PureDW_SFDC_Staging.dbo.[User] AE on AE.Id = CP.AE_Owner__c
   left join PureDW_SFDC_Staging.dbo.Account Acc on Acc.Id = CP.Partner_Account_Association__c
where (
O.Name in (Select * from @CTM_List) or
AE.Name in (Select * from @CTM_List)
)
   --------
   where CP.IsActive = 'True'
   and Acc.Name like 'Presidio%'
   and CP.StartDate >= '2019-02-01'
   and CP.Id ='7010z000000qwljAAA'
   and O.Name = 'Frank Mueller'


/************************************************************************************************/
/* All Opportunity created since FY2019 + Opportunity closed since FY2019 regardless close date */
/* Long Oppt                                                                                    */
/************************************************************************************************/

select [Final].*,
	Case when datediff(year, Current_Fiscal_Month, [Fiscal Month]) = 0 then 'This year'
		 when datediff(year, Current_Fiscal_Month, [Fiscal Month]) < 0 then 'Last ' + cast(datediff (year, [Fiscal Month], Current_Fiscal_Month) as varchar(2)) + ' year'
		 when datediff(year, Current_Fiscal_Month, [Fiscal Month]) > 0 then 'Next ' + cast(datediff(year, Current_Fiscal_Month, [Fiscal Month]) as varchar(2)) + ' year'
	end [Relative_CloseYear],
	 
	Case when datediff(quarter, Current_Fiscal_Month, [Fiscal Month]) = 0 then 'This quarter'
		 when datediff(quarter, Current_Fiscal_Month, [Fiscal Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Month], Current_Fiscal_Month) as varchar(2)) + ' quarter'
		 when datediff(quarter, Current_Fiscal_Month, [Fiscal Month]) > 0 then 'Next ' + cast(datediff(quarter, Current_Fiscal_Month, [Fiscal Month]) as varchar(2)) + ' quarter'
	end [Relative_CloseQtr]
from (
		Select O.Id, O.Name, T.Date, T.Legends, O.Partner_Account__c, RTRIM(LTRIM(P.Name)) [Partner Name], P.Partner_Tier__c [Partner Tier],
			O.Partner_Account__c [Partner Id], P.Theater__c [Partner Theater],
			O.Partner_SE__c, 
			Upper(left(Partner_SE.FirstName,1)) + Lower(substring(Partner_SE.FirstName, 2, len(Partner_SE.FirstName)-1)) + ' ' +
			Upper(left(Partner_SE.LastName,1)) + Lower(substring(Partner_SE.LastName, 2, len(Partner_SE.LastName)-1)) [Partner SE],
			Partner_SE.Role_Type__c [Assigned Role],
			O.Converted_Amount_USD__c Amount_in_USD,
--			DateFromParts( Year(DateAdd(month, 11, T.[Date])), Month(DateAdd(month, 11, T.[Date])), 1 ) [Fiscal Month],
			DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey,1,4) as int), cast(substring(CloseDate_445.FiscalMonthKey,5,2) as int), 1) [Fiscal Month],
			case when O.Channel_Led_Deal__c = 'true' then 1 else 0 end as [CLed Deal],
			case when O.Partner_Sourced__c = 'true' then 1 else 0 end as [Partner Sourced],
			
			--DateFromParts(Year(DateAdd(month, 11, GetDate())), Month(DateAdd(month, 11, GetDate())), 1) as Current_Fiscal_Month
			DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey,1,4) as int), cast(substring(TodayDate_445.FiscalMonthKey,5,2) as int), 1) [Current_Fiscal_Month]

			from (  /* make a long format of Opportunity Id, Date type & Date */
				Select Id, 'Create' as Legends, cast(CreatedDate as Date) [Date]
				from PureDW_SFDC_Staging.dbo.Opportunity
				where CreatedDate >= '2018-02-01'

				Union

				select id, 'Close-Won' as Legends, cast(CloseDate as date) [Date]
				from PureDW_SFDC_Staging.dbo.Opportunity
				where CloseDate >= '2018-02-01' and CloseDate <= GetDate()
				and StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit')

				Union

				select id, 'Close-Loss' as Legends, cast(CloseDate as date) [Date] 
				from PureDW_SFDC_Staging.dbo.Opportunity
				where CloseDate >= '2018-02-01' and CloseDate <= GetDate()
				and StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity')
			) T
		left join PureDW_SFDC_Staging.dbo.Opportunity O on O.Id = T.Id
		left join PureDW_SFDC_Staging.dbo.Account P on P.Id = O.Partner_Account__c
		left join PureDW_SFDC_Staging.dbo.Contact Partner_SE on Partner_SE.Id = O.Partner_SE__c
		left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.id = O.RecordTypeId
		left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
		left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)

		where Rec.Name in ('Sales Opportunity','ES2 Opportunity')
	) [Final]

where Final.[Partner SE] = 'Tony VanDemark'
--and Legends = 'Close-Won'

/******* Oppt Line, Portfolio *******/
select a.*,
	
	case when (a.CBS_Category__c is not null and a.CBS_Category__c != 'NO CBS') then 'CBS'
		 when a.[RecordType] = 'ES2 Opportunity' then 'PaaS' -- PaaS which has no CBS
		 when a.[RecordType] = 'Sales Opportunity' then 
		 		case when a.Manufacturer__c is null or a.Manufacturer__c = '' then 'Not reported'
		 		 	 when a.Manufacturer__c = 'Pure Storage' then
		 		 	 		case when (a.[Oppt Product] is null or a.[Oppt Product] = '') then 'Not reported'
		 		 	 		else a.[Line Product]
		 		 	 		end
		 		 	 else a.Manufacturer__c
		 		end
	end [Portfolio],
		
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

from
	(			Select Oppt.Id [Oppt Id], Oppt.Name [Opportunity], RecT.Name [RecordType]
				 , Oppt.Manufacturer__c, Oppt.Product_Type__c [Oppt Product], Oppt.CBS_Category__c
				 , P_SE.Name [Partner_SE]
				 , Partner.Name [Partner Name], Partner.Theater__c [Partner Theater], Partner.Id [Partner_Id], 
				 case when Partner.Partner_Tier__c is null then 'None' else Partner.Partner_Tier__c end [Partner Tier]
				 , case when Oppt.Channel_Led_Deal__c = 'true' then 1 else 0 end [CLed Deal]
				 , case when Oppt.Partner_Sourced__c = 'true' then 'T' else 'F' end [Partner Sourced] --when CAM convert a Partner registrated oppt to a SFDC oppt, the checkbox is checked
				 , Oppt.StageName

				 , cast(Oppt.CloseDate as Date) CloseDate, CloseDate_445.FiscalYear [Fiscal Close Year], CloseDate_445.FiscalQuarterName [Fiscal Close Quarter]
				 , DatefromParts(CloseDate_445.FiscalYear, CloseDate_445.FiscalMonth, 1) [Fiscal Close Month]
				 , cast(Oppt.CreatedDate as Date) CreatedDate, CreateDate_445.FiscalYear [Fiscal Create Year], CreateDate_445.FiscalQuarterName [Fiscal Create Quarter]
				 , DATEFROMPARTS(CreateDate_445.FiscalYear, CreateDate_445.FiscalMonth, 1) [Fiscal Create Month]
				 , DateFromParts(TodayDate_445.FiscalYear, TodayDate_445.FiscalMonth, 1) [Current Fiscal Month]

				 , OLI.Product2Id, OLI.Product_Name__c, OLI.Product_Desc__c
				 , OLI.CurrencyIsoCode, OLI.Quantity, OLI.TotalPrice [Total Price], OLI.CPQ_Discount__c
				 , case when OLI.TotalPrice = 0 then 0
						else 
							case when Oppt.Amount = 0 then 0
							else cast(OLI.TotalPrice * (Oppt.Converted_Amount_USD__c/ Oppt.Amount) as decimal(15,2))
							end
				        end TotalPrice_in_USD
				 , Pd.Family, Pd.CPQ_Platform__c [Platform]
				 , case when Pd.Family = 'PS' then 'Professional Service'
						when Pd.Family = 'FlashArray' then 
							case when Pd.CPQ_Platform__c like '%Support%' then 'Support Service'
								 when Pd.CPQ_Platform__c like '%ASP%' then 'Support Service'
								 else 'FA : ' + Pd.CPQ_Platform__c
							end
						when Pd.Family = 'FlashBlade' then 
							case when Pd.CPQ_Platform__c like '%Support%' then 'Support Service'
								 when Pd.CPQ_Platform__c like '%ASP%' then 'Support Service'
								 else 'FB : ' + Pd.CPQ_Platform__c
							end
						else Pd.Family
					end [Line Product]
					
			from PureDW_SFDC_Staging.dbo.OpportunityLineItem OLI
			left join PureDW_SFDC_Staging.dbo.Product2 Pd on Pd.Id = OLI.Product2Id
			left join PureDW_SFDC_Staging.dbo.Opportunity Oppt on Oppt.Id = OLI.OpportunityId
			left join PureDW_SFDC_Staging.dbo.Contact P_SE on P_SE.Id = Oppt.Partner_SE__c
--			left join PureDW_SFDC_Staging.dbo.Account Partner on Partner.Id = P_SE.AccountId
			left join PureDW_SFDC_Staging.dbo.Account Partner on Partner.Id = Oppt.Partner_Account__c
			left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = Oppt.RecordTypeId
			left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, Oppt.CreatedDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
			where Oppt.CloseDate >= '2018-02-03'
			and RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	) a
	
	where a.CloseDate >= '06-01-20'