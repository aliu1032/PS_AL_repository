

/*******************/
/* by Partner User */
/*******************/
Select 
C.Name [Partner SE], C.Id [Partner SE Id], C.Email, C.Role_type__c [Role Type], C.MailingCity, C.MailingState, C.MailingCountry,
-- C. Partner_Class__c,
C.PRMNotes__c Notes,
A.Name [Partner Name], A.Id [Partner Id], A.D_B_City_Name__c [Partner City], A.D_B_State_Province_Abbreviation__c [Partner State], A.D_B_Country_Name__c [Partner Country],
A.Theater__c [Partner Theater], A.Territory__c [Partner Territory],
T.Oppt_count, T.Avg_Oppt_Amt,
T.Win_amt, T.Win_count, T.Open_amt, T.Open_count, T.Loss_amt, T.Loss_count, T.[Avg Pipeline to CloseWin],

case 
	when (T.Win_count is null) and (T.Loss_count is null) then Null
	when (T.Win_count > 0) and (T.Loss_count is null) then 100.00
	when (T.Win_count is null) and (T.Loss_count > 0) then 0.00
	when (T.Win_count > 0) and (T.Loss_count > 0) then cast(cast(T.Win_count as float)/(T.Win_count + T.Loss_count)*100 as decimal(5,2))
	else Null
end as Win_Rate,

case when C.PPR_Pure_Storage_Sales_Accreditation__c = 'True' then 1 when C.PPR_Pure_Storage_Sales_Accreditation__c = 'False' then 0 else -1 end [Pure Storage Sales Accreditation],
case when C.PPR_Participate_in_sales_call__c = 'True' then 1 else 0 end [Participate in sales call], --AE Edit
case when C.PPR_Shadow_array_installation__c = 'True' then 1 else 0 end [Shadow array installation],  -- AE Edit
case when C.PPR_Value_Prop_TCO_Proficiency__c = 'True' then 1 else 0 end [Value Prop/TCO Proficiency], --AE Edit

case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 1 else 0 end [Pure Foundation Certification Exam], -- SE, Nedit
case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 'Trained' else 'Not Trained' end [_Pure Foundation Certification Exam], -- SE, Nedit

case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 1 else 0 end [FlashArray Architect Professional], -- SE, Nedit
case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 'Trained' else 'Not Trained' end [_FlashArray Architect Professional], -- SE, Nedit

case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 1 else 0 end [FlashArray Implementation Professional], -- SE, Nedit
case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 'Trained' else 'Not Trained' end [_FlashArray Implementation Professional], -- SE, Nedit

case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 1 else 0 end [Capacity sizing proficiency], -- SE, Edit
case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 'Trained' else 'Not Trained' end [_Capacity sizing proficiency], -- SE, Edit

case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 1 else 0 end[TCO/Evergreen Proficiency] , -- SE, Edit
case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 'Trained' else 'Not Trained' end[_TCO/Evergreen Proficiency] , -- SE, Edit

case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 1 else 0 end [Perform PureTEC GUI demo], -- SE, Edit
case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 'Trained' else 'Not Trained' end [_Perform PureTEC GUI demo] -- SE, Edit

from (
	Select * from (
		Select M1.*, M2.[Avg Pipeline to CloseWin] from 
			(
			Select
			Partner_SE__c, -- cast(Close_Month__c as date) [Close Month],
			count(*) as Oppt_count,
			cast(avg(Converted_Amount_USD__c) as decimal(20,2)) as Avg_Oppt_Amt,
			sum(case when StageName not like 'Stage 8 %' then 1 end) as Open_count,
			sum(case when StageName not like 'Stage 8 %' then Converted_Amount_USD__c end) as Open_amt,
			sum(case when StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 end) as Win_count,
			sum(case when StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then Converted_Amount_USD__c end) as Win_amt,
			sum(case when StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision') then 1 end) as Loss_count,
			sum(case when StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision') then Converted_Amount_USD__c end) as Loss_amt
			from PureDW_SFDC_Staging.dbo.Opportunity O
			left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
			where Partner_SE__c is not null
				and Rec.Name in ('Sales Opportunity', 'ES2 Opportunity')
				and O.CloseDate >= '2019-02-01'
			group by O.Partner_SE__c
			) M1
			left join (  /* Calculate the time to close win for won deals only */
				select
				Partner_SE__c,
				cast(avg(O.Age_Pipeline_to_Close__c) as decimal(10,2)) [Avg Pipeline to CloseWin]
				from PureDW_SFDC_Staging.dbo.Opportunity O
				left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
				where Partner_SE__c is not null
				and Rec.Name in ('Sales Opportunity', 'ES2 Opportunity')
				and O.CloseDate >= '2019-02-01'
				and O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit')
				group by O.Partner_SE__c
			) M2 on M2.Partner_SE__c = M1.Partner_SE__c
		) T0
	) T
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id =T.Partner_SE__c
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
order by [Partner SE] 




/***********************/
/* Per Partner Account */
/***********************/
Select 
PA.Name [Partner Name], PA.Id [Partner Id], 
Case when PA.Partner_Tier__c is null then 'None' else PA.Partner_Tier__c end [Partner Tier],
Case when PA.Partner_Tier__c = 'Elite' then 'Elite' else 'Not' end [Elite Partner], 
PA.D_B_State_Province_Abbreviation__c [Partner State], PA.D_B_Country_Name__c [Partner Country], PA.Theater__c [Partner Theater], PA.Territory__c [Partner Territory],
T.Oppt_count, T.Avg_Oppt_Amt,
T.Win_amt, T.Win_count, T.Open_amt, T.Open_count, T.Loss_amt, T.Loss_count,
T.[<=$100K], T.[$100K - $500K], T.[>$500K],
T.[Avg Pipeline to CloseWin],
case 
	when (T.Win_count is null) and (T.Loss_count is null) then Null
	when (T.Win_count > 0) and (T.Loss_count is null) then 100.00
	when (T.Win_count is null) and (T.Loss_count > 0) then 0.00
	when (T.Win_count > 0) and (T.Loss_count > 0) then cast(cast(T.Win_count as float)/(T.Win_count + T.Loss_count)*100 as decimal(5,2))
	else Null
end as Win_Rate

from (
	Select * from (
		Select M1.*, M2.[Avg Pipeline to CloseWin] from 	
			(Select
			Partner_Account__c, -- cast(Close_Month__c as date) [Close Month],
			count(*) as Oppt_count,
			cast(avg(Converted_Amount_USD__c) as decimal(20,2)) Avg_Oppt_Amt,
			sum(case when Converted_Amount_USD__c <= 100000 then 1 else 0 end) as '<=$100K',
			sum(case when ((Converted_Amount_USD__c > 100000) and (Converted_Amount_USD__c <=500000)) then 1 else 0 end) as '$100K - $500K',
			sum(case when Converted_Amount_USD__c > 500000 then 1 else 0 end) as '>$500K',
			sum(case when StageName not like 'Stage 8 %' then 1 end) as Open_count,
			sum(case when StageName not like 'Stage 8 %' then Converted_Amount_USD__c end) as Open_amt,
			sum(case when StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 end) as Win_count,
			sum(case when StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then Converted_Amount_USD__c end) as Win_amt,
			sum(case when StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision') then 1 end) as Loss_count,
			sum(case when StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision') then Converted_Amount_USD__c end) as Loss_amt
			from PureDW_SFDC_Staging.dbo.Opportunity O
			left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
			where Partner_Account__c is not null
			and Rec.Name in ('Sales Opportunity', 'ES2 Opportunity')
			and O.CloseDate >= '2019-02-01'
			group by O.Partner_Account__c
			) M1
			left join (  /* Calculate the time to close win for won deals only */
				select
				O.Partner_Account__c,
				cast(avg(O.Age_Pipeline_to_Close__c) as decimal(10,2)) [Avg Pipeline to CloseWin]
				from PureDW_SFDC_Staging.dbo.Opportunity O
				left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
				where Partner_Account__c is not null
				and Rec.Name in ('Sales Opportunity', 'ES2 Opportunity')
				and O.CloseDate >= '2019-02-01'
				and O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit')
				group by O.Partner_Account__c
			) M2 on M2.Partner_Account__c = M1.Partner_Account__c
	) T0
) T
left join PureDW_SFDC_Staging.dbo.Account PA on PA.Id =T.Partner_Account__c
order by PA.Id


/************************************************************/
/***    Partner contacts                                  ***/
/***    All Not deleted contact associated with a Partner ***/
/************************************************************/
select O.Name Owner,
C.Id [Contact Id], 
-- C.Name Contact,
Upper(left(C.FirstName,1)) + Lower(substring(C.FirstName, 2, len(C.FirstName)-1)) + ' ' +
Upper(left(C.LastName,1)) + Lower(substring(C.LastName, 2, len(C.LastName)-1)) [Partner SE],  -- Contact First and Last Name are blank

C.Email, C.Role_type__c [Role Type],

--C.MailingCity, C.MailingState, C.MailingCountry, C.PRMNotes__c Notes,
A.Name [Partner Name], A.Id [Partner Id] , A.D_B_City_Name__c [Partner City], A.D_B_State_Province_Abbreviation__c [Partner State], A.D_B_Country_Name__c [Partner Country],
A.Theater__c [Partner Theater], A.Authorized_Partner__c [Authorized Partner], A.Type, A.Partner_Tier__c [Partner Tier],

case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 'Trained' else 'Not trained' end [FlashArray Architect Professional], -- SE, Nedit
case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 1 else 0 end [FlashArray Architect Professional Count], -- SE, Nedit

case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 'Trained' else 'Not trained' end [FlashArray Implementation Professional], -- SE, Nedit
case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 1 else 0 end [FlashArray Implementation Professional Count], -- SE, Nedit

case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 'Trained' else 'Not trained' end [Pure Foundation Certification Exam], -- SE, Nedit
case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 1 else 0 end [Pure Foundation Certification Exam Count], -- SE, Nedit

case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 'Trained' else 'Not trained' end [Capacity sizing proficiency], -- SE, Edit
case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 1 else 0 end [Capacity sizing proficiency Count], -- SE, Edit

case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 'Trained' else 'Not trained' end[TCO/Evergreen Proficiency] , -- SE, Edit
case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 1 else 0 end[TCO/Evergreen Proficiency Count], -- SE, Edit

case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 'Trained' else 'Not trained' end [Perform PureTEC GUI demo], -- SE, Edit
case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 1 else 0 end [Perform PureTEC GUI demo Count] -- SE, Edit

from PureDW_SFDC_Staging.dbo.Contact C
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
left join PureDW_SFDC_Staging.dbo.[User] O on O.Id = C.OwnerId
where C.IsDeleted = 'false'
--and C.Role_Type__c is not null
--and A.Authorized_Partner__c = 'True'
--and A.Id = '0016000000hfzCKAAY'
--and A.Name = 'ES2'

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
)


select *,
	Case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff (year, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' year'
	end [Relative_CloseYear],
	 
	Case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' quarter'
	end [Relative_CloseQtr]

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

		Oppt.Id [Oppt Id], Oppt.[Oppt_Name], Oppt.Customer,
		Oppt.RecType, Oppt.Product, Oppt.Mfg, Oppt.Type,
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

/*		case 
		 	 when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
		 	 when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss, Disqualified, Undecided'
			 else 'Open'
		end [Won/Loss],
*/
		case 
		 	 when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
		 	 when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss, Disqualified, Undecided'
--			 when cast(substring(Oppt.StageName, 7,1) as int) < 4 then 'Early Stage'
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
					Select O.Id, O.Name [Oppt_Name], Rec.Name RecType, EU_Acct.Name [Customer]
					, O.Product_Type__c [Product], O.Manufacturer__c [Mfg], O.[Type]
					,cast(O.CreatedDate as Date) CreatedDate, cast(O.CloseDate as Date) CloseDate
					, DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey,1,4) as int), cast(substring(CloseDate_445.FiscalMonthKey,5,2) as int), 1) [Fiscal Close Month]
					, DateFromParts(cast(substring(CreateDate_445.FiscalMonthKey,1,4) as int), cast(substring(CreateDate_445.FiscalMonthKey,5,2) as int),1) [Fiscal Created Month]				
										
					/* calculate Today's reference */
					, DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey,1,4) as int), cast(substring(TodayDate_445.FiscalMonthKey,5,2) as int), 1) [Current Fiscal Year-Month],
					O.StageName, O.Eval_Stage__c,
					O.CurrencyIsoCode, O.Amount, O.Converted_Amount_USD__c Amount_in_USD,
					O.Theater__c Theater, O.Sub_Division__c Sub_Division,
					O.Partner_Sourced__c, O.Channel_Led_Deal__c, O.Age_Pipeline_to_Close__c [Pipeline to Close Age],

				    O.Partner_Account__c [Partner Id], P.Name [Partner Name],
					P.Partner_Tier__c [Partner Tier], 
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
					--left join PureDW_SFDC_Staging.dbo.Account Dist_UL on substring(Dist_UL.Id,1,15) = cast(Dist.Ultimate_Parent_Id__c as varchar(15)) COLLATE SQL_Latin1_General_CP1_CS_AS
					left join SalesOps_DM.dbo.CTM_Disti_Map Dist_UL on Dist_UL.Child_Account_Id = O.Distributor_Account__c
					
					left join PureDW_SFDC_Staging.dbo.Account EU_Acct on EU_Acct.Id = O.AccountId
					
					left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, O.CreatedDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)
					
					left join #Quote_Count QC on QC.Oppt_Id = O.Id
					
					where 
					--(O.CreatedDate >= '2018-02-01' or (O.CloseDate >='2018-02-01' and O.CloseDate <= GetDate()))
					O.CloseDate >= '2018-02-01'
					and Rec.Name in ('Sales Opportunity','ES2 Opportunity')
					and O.Partner_Account__c is not null  --- Selecting Capax and PaaS Oppt where Partner Account is stamped
				   ) Oppt on C.Id = Oppt.Partner_SE__c --and C.AccountId = Oppt.Partner_Account__c
		) a
where
a.[Partner Type] in ('Reseller','Distributor')
and a.[Oppt Id] in ('0060z00001uPxdoAAC')
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



/************************************************************************************************/
/* All Opportunity created since FY2019 + Opportunity closed since FY2019 regardless close date */
/* Long Oppt                                                                                    */
/* Pull Pure SE information too                                                                 */
/************************************************************************************************/

Select O.Id, O.Name, T.Date, T.Legends, O.Partner_Account__c, RTRIM(LTRIM(P.Name)) [Partner Name], P.Partner_Tier__c [Partner Tier],  O.Partner_SE__c, 
--Partner_SE.Name [Partner_SE],
Upper(left(Partner_SE.FirstName,1)) + Lower(substring(Partner_SE.FirstName, 2, len(Partner_SE.FirstName)-1)) + ' ' +
Upper(left(Partner_SE.LastName,1)) + Lower(substring(Partner_SE.LastName, 2, len(Partner_SE.LastName)-1)) [Partner SE],
Partner_SE.Role_Type__c [Assigned Role],
O.Converted_Amount_USD__c Amount_in_USD,
DateFromParts( Year(DateAdd(month, 11, T.[Date])), Month(DateAdd(month, 11, T.[Date])), 1 ) [Fiscal Month],
case when O.Channel_Led_Deal__c = 'true' then 1 else 0 end as [CLed Deal],
case when O.Partner_Sourced__c = 'true' then 1 else 0 end as [Partner Sourced],

SE.Name [SE Oppt Owner]

from 
(
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
left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
where Rec.Name in ('Sales Opportunity','ES2 Opportunity')




/* find out the bookings per Product Family & Platform */
with Product_Family as (
Select Pd.Family, Pd.CPQ_Platform__c [Platform]
, Count(Name) [# of Products]
, cast(min(CreatedDate) as date) Min_CreatedDate
, cast(max(CreatedDate) as date) Max_CreatedDate
from PureDW_SFDC_Staging.dbo.Product2 Pd
where Pd.Family is not null 
Group by Pd.CPQ_Platform__c, Pd.Family
order by Family, CPQ_Platform__c
)



/************************************************************************************************/
/* All Opportunity Closed in FY20  */
/* by TAC Partners                 */
/* and the Line Level detail       */

with #QuoteLines as (
	Select a.*
	,	Case when datediff(year, Current_Fiscal_Month, [Fiscal Close Month]) = 0 then 'This year'
			 when datediff(year, Current_Fiscal_Month, [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff (year, [Fiscal Close Month], Current_Fiscal_Month) as varchar(2)) + ' year'
			 when datediff(year, Current_Fiscal_Month, [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, Current_Fiscal_Month, [Fiscal Close Month]) as varchar(2)) + ' year'
		end [Relative_CloseYear]	 
	,	Case when datediff(quarter, Current_Fiscal_Month, [Fiscal Close Month]) = 0 then 'This quarter'
			 when datediff(quarter, Current_Fiscal_Month, [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], Current_Fiscal_Month) as varchar(2)) + ' quarter'
			 when datediff(quarter, Current_Fiscal_Month, [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, Current_Fiscal_Month, [Fiscal Close Month]) as varchar(2)) + ' quarter'
		end [Relative_CloseQtr]
	from (
			select
			  	Oppt.Partner_Account__c, PAcct.Name [Partner], Acct.Name [Account], Oppt.Theater__c [Theater], Oppt.Sub_Division__c [Sub_Division]
			  	, Oppt.Id Oppt_ID, Oppt.Name [Oppt Name], cast(Oppt.CloseDate as date) CloseDate, Oppt.StageName
			  	, Qu.Name [Quote Num] , Qu.CurrencyIsoCode [Currency], Qu.SBQQ__NetAmount__c [Quote Amt], Qu.Converted_Amount__c [Quote Amt in USD]
			  	, Qu.CPQ_Quote_Name__c [Quote Name], QL.Name [Quote Line Name]
			  	, QL.SBQQ__Product__c, QL.SBQQ__ProductName__c [Product], QL.CPQ_Quote_Quantity__c
			  	, QL.CurrencyIsoCode
			  	, QL.SBQQ__ListPrice__c, QL.SBQQ__ListTotal__c
			  	, QL.CPQ_Total_Discount__c, QL.CPQ_Approval_Color__c
			  	, QL.SBQQ__NetPrice__c, QL.SBQQ__NetTotal__c
			  	, Case when QL.CurrencyIsoCode != 'USD' then
						case when (Qu.SBQQ__NetAmount__c is not null and Qu.SBQQ__NetAmount__c > 0) then
							 cast(Qu.Converted_Amount__c / Qu.SBQQ__NetAmount__c * QL.SBQQ__NetTotal__c as decimal(20,2))
						end
					else QL.SBQQ__NetTotal__c
					end as [NetTotal in USD]
				, RecT.name [RecT], Oppt.Transaction_Type__c
				, DateFromParts( Year(DateAdd(month, 11, Oppt.CloseDate)), Month(DateAdd(month, 11, Oppt.CloseDate)), 1 ) [Fiscal Close Month]
				, DateFromParts(Year(DateAdd(month, 11, GetDate())), Month(DateAdd(month, 11, GetDate())), 1) as Current_Fiscal_Month
				from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.SBQQ__Quote__c Qu on Qu.SBQQ__Opportunity2__c = Oppt.Id
				left join PureDW_SFDC_Staging.dbo.SBQQ__QuoteLine__c QL on QL.SBQQ__Quote__c = Qu.Id
				left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = Oppt.RecordTypeId
				left join PureDW_SFDC_Staging.dbo.Account Acct on Acct.Id = Oppt.AccountId
				left join PureDW_SFDC_Staging.dbo.Account PAcct on PAcct.Id = Oppt.Partner_Account__c
			where RecT.Name in ('Sales Opportunity', 'ES2 Opportunity')
			and Oppt.CloseDate >= '2019-02-01' and Oppt.CloseDate <= '2020-01-31'
			and Qu.SBQQ__Primary__c = 'true' /* select the primary quote */
		) a
)		


Select a.*
, Case when A.[TAC Partner Id] is not null then 'TAC Partners' else 'Others' End [TAC Partner]
from  (
	select Pd.Family, Pd.CPQ_Platform__c [Platform], Pd.Name [Product Name], Pd.Id [Product Id]
	, QL.*, TAC.Partner_Id [TAC Partner Id] 
	from PureDW_SFDC_Staging.dbo.Product2 Pd
	left join #QuoteLines QL on QL.SBQQ__Product__c = Pd.Id
	left join (Select Partner_Id from SalesOps_DM.dbo.CTM_Favorite where Name = 'TAC') TAC on TAC.Partner_Id = QL.Partner_Account__c
) a



/************* Play around for Roll up for CTMs' Managers  *********/

/******************************************/
/*    Archieve                            */
/******************************************/

/***********************************************************************************************/
/* Opportunity with Partner SE values, merge with Contact training & certification information */
/***********************************************************************************************/
Select Oppt.OpptId, Oppt.Converted_Amount_USD__c [Oppt Amount], Oppt.CloseDate, Oppt.StageName, Oppt.ForecastCategoryName, Oppt.Theater__c Theater, Oppt.Division__c Division, Oppt.Sub_Division__c Sub_Division,
case when Oppt.StageName not like 'Stage 8 %' then 1 end as Open_count,
case when Oppt.StageName not like 'Stage 8 %' then Oppt.Converted_Amount_USD__c end as Open_amt,
case when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 end as Win_count,
case when Oppt.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then Oppt.Converted_Amount_USD__c end as Win_amt,
case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision')
	              then 1 end Loss_count,
case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision')
	              then Converted_Amount_USD__c end Loss_amt,

case when Oppt.StageName = 'Stage 8 - Closed/Won' then 'Win'
	 when Oppt.StageName in ('Stage 8 - Closed/ Disqualified', 'Stage 8 - Closed/ Low Capacity', 'Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Credit') then 'Loss'
	 else 'Open' end as StageGroup,

C.[Contact Id] [Partner SE Id], C.Contact [Partner SE], C.Email, C.[Role Type], C.[Partner Name], C.[Partner Id],
C.[Pure Storage Sales Accreditation],
C.[Value Prop/TCO Proficiency],
C.[Participate in sales call],
C.[Shadow array installation],
C.[Pure Foundation Certification Exam],
C.[Capacity sizing proficiency],
C.[TCO/Evergreen Proficiency],
C.[Perform PureTEC GUI demo],
C.[FlashArray Architect Profesional],
C.[FlashArray Implementation Professional]

from 
(	select O.Id OpptId, Partner_SE__c, Converted_Amount_USD__c, cast(CloseDate as date) CloseDate, ForecastCategoryName, StageName, Theater__c, Division__c, Sub_Division__c
	from PureDW_SFDC_Staging.dbo.Opportunity O
	where Partner_SE__c is not null
		--and O.Partner_SE__C in ('0030z00002TnOoQAAV')
		and O.CreatedDate >= '2019-02-01' 
		--and O.CreatedDate <'2019-06-01'
		and (O.Theater__c = 'America''s' or O.Theater__c = 'FlashBlade')
	) Oppt
left join (
	select O.Name Owner,
	C.Id [Contact Id], C.Name Contact, C.Email, C.Role_type__c [Role Type], C.MailingCity, C.MailingState, C.MailingCountry, C.Lead_Source_Most_Recent__c,
	C.PRMNotes__c Notes,
	A.Name [Partner Name], A.Id [Partner Id] , A.D_B_City_Name__c [Partner City], A.D_B_State_Province_Abbreviation__c [Partner State], A.D_B_Country_Name__c [Partner Country],

	/** Pure Practice Requirements */

	case when C.PPR_Pure_Storage_Sales_Accreditation__c = 'True' then 1 when C.PPR_Pure_Storage_Sales_Accreditation__c = 'False' then 0 else -1 end [Pure Storage Sales Accreditation],
	case when C.PPR_Value_Prop_TCO_Proficiency__c = 'True' then 1 else 0 end [Value Prop/TCO Proficiency], --AE Edit
	case when C.PPR_Participate_in_sales_call__c = 'True' then 1 else 0 end [Participate in sales call], --AE Edit
	case when C.PPR_Shadow_array_installation__c = 'True' then 1 else 0 end [Shadow array installation],  -- AE Edit

	case when C.PPR_Pure_Foundation_Certification_Exam__c = 'True' then 1 else 0 end [Pure Foundation Certification Exam], -- SE, Nedit
	case when C.PPR_Sizing_Configuration_Proficiency__c = 'True' then 1 else 0 end [Capacity sizing proficiency], -- SE, Edit
	case when C.PPR_TCO_Evergreen_Proficiency__c = 'True' then 1 else 0 end [TCO/Evergreen Proficiency] , -- SE, Edit
	case when C.PPR_Perform_PureTEC_GUI_demo__c = 'True' then 1 else 0 end [Perform PureTEC GUI demo], -- SE, Edit

	case when C.PPR_FlashArray_Architect_Professional__c = 'True' then 1 else 0 end [FlashArray Architect Profesional], -- SE, Nedit
	case when C.PPR_FlashArray_Implementation_Prof__c = 'True' then 1 else 0 end [FlashArray Implementation Professional] -- SE, Nedit

	from PureDW_SFDC_Staging.dbo.Contact C
	left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
	left join PureDW_SFDC_Staging.dbo.[User] O on O.Id = C.OwnerId
	where C.IsDeleted = 'false'
	) C on C.[Contact Id] = Oppt.Partner_SE__c



/* Wide Monthly Oppt Amount by ForecastCategory */
Select 
C.Name [Partner SE], C.Id [Partner SE Id], C.Email, C.Role_type__c [Role Type], C.MailingCity, C.MailingState, C.MailingCountry,
C.PRMNotes__c Notes,
A.Name [Partner Name], A.Id [Partner Id], A.D_B_City_Name__c [Partner City], A.D_B_State_Province_Abbreviation__c [Partner State], A.D_B_Country_Name__c [Partner Country],
Oppt_amt.[Close Month], Oppt_Amt.Pipeline, Oppt_Amt.Upside, Oppt_Amt.[Commit], Oppt_amt.Closed, Oppt_Amt.Omitted,

C.PPR_Pure_Storage_Sales_Accreditation__c [Pure Storage Sales Accreditation],
C.PPR_Value_Prop_TCO_Proficiency__c [Value Prop/TCO Proficiency], --AE Edit
C.PPR_Participate_in_sales_call__c [Participate in sales call], --AE Edit
C.PPR_Shadow_array_installation__c [Shadow array installation],  -- AE Edit

C.PPR_Pure_Foundation_Certification_Exam__c [Pure Foundation Certification Exam], -- SE, Nedit
C.PPR_Sizing_Configuration_Proficiency__c [Capacity sizing proficiency], -- SE, Edit
C.PPR_TCO_Evergreen_Proficiency__c [TCO/Evergreen Proficiency], -- SE, Edit
C.PPR_Perform_PureTEC_GUI_demo__c [Perform PureTEC GUI demo], -- SE, Edit

C.PPR_FlashArray_Architect_Professional__c [FlashArray Architect Profesional], -- SE, Nedit
C.PPR_FlashArray_Implementation_Prof__c [FlashArray Implementation Professional] -- SE, Nedit
from 
(	select Partner_SE__c, Converted_Amount_USD__c [Oppt Amount], cast(Close_Month__c as date) [Close Month], ForecastCategoryName
	from PureDW_SFDC_Staging.dbo.Opportunity O
	where Partner_SE__c is not null
		--and O.Partner_SE__C in ('0030z00002TnOoQAAV')
		and O.CreatedDate >= '2019-02-01' 
		--and O.CreatedDate <'2019-06-01
		and (O.Theater__c = 'America''s' or O.Theater__c = 'FlashBlade')
	--group by O.Partner_SE__c, O.Close_Month__c, O.ForecastCategory
	) TT
	PIVOT
	( sum([Oppt Amount]) for 
	 ForecastCategoryName in ([Pipeline],[Upside],[Commit],[Closed],[Omitted])) as Oppt_Amt
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Oppt_Amt.Partner_SE__c
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
order by [Partner SE], [Close Month] desc

/* Monthly */
Select 
C.Name [Partner SE], C.Id [Partner SE Id], C.Email, C.Role_type__c [Role Type], C.MailingCity, C.MailingState, C.MailingCountry,
C.PRMNotes__c Notes,
A.Name [Partner Name], A.Id [Partner Id], A.D_B_City_Name__c [Partner City], A.D_B_State_Province_Abbreviation__c [Partner State], A.D_B_Country_Name__c [Partner Country],
T.[Close Month], T.Pipeline_amt, T.Pipeline_count, T.Upside_amt, T.Upside_count, T.Commit_amt, T.Commit_count, T.Closed_amt, T.Closed_count, T.Omitted_amt, T.Omitted_count,

C.PPR_Pure_Storage_Sales_Accreditation__c [Pure Storage Sales Accreditation],
C.PPR_Value_Prop_TCO_Proficiency__c [Value Prop/TCO Proficiency], --AE Edit
C.PPR_Participate_in_sales_call__c [Participate in sales call], --AE Edit
C.PPR_Shadow_array_installation__c [Shadow array installation],  -- AE Edit

C.PPR_Pure_Foundation_Certification_Exam__c [Pure Foundation Certification Exam], -- SE, Nedit
C.PPR_Sizing_Configuration_Proficiency__c [Capacity sizing proficiency], -- SE, Edit
C.PPR_TCO_Evergreen_Proficiency__c [TCO/Evergreen Proficiency], -- SE, Edit
C.PPR_Perform_PureTEC_GUI_demo__c [Perform PureTEC GUI demo], -- SE, Edit

C.PPR_FlashArray_Architect_Professional__c [FlashArray Architect Profesional], -- SE, Nedit
C.PPR_FlashArray_Implementation_Prof__c [FlashArray Implementation Professional] -- SE, Nedit

from (
	Select
	Partner_SE__c, cast(Close_Month__c as date) [Close Month],
	sum(case when ForecastCategoryName = 'Pipeline' then Converted_Amount_USD__c end) as Pipeline_amt,
	sum(case when ForecastCategoryName = 'Pipeline' then 1 end) as Pipeline_count,
	sum(case when ForecastCategoryName = 'Upside' then Converted_Amount_USD__c end) as Upside_amt,
	sum(case when ForecastCategoryName = 'Upside' then 1 end) as Upside_count,
	sum(case when ForecastCategoryName = 'Commit' then Converted_Amount_USD__c end) as Commit_amt,
	sum(case when ForecastCategoryName = 'Commit' then 1 end) as Commit_count,
	sum(case when ForecastCategoryName = 'Closed' then Converted_Amount_USD__c end) as Closed_amt,
	sum(case when ForecastCategoryName = 'Closed' then 1 end) as Closed_count,
	sum(case when ForecastCategoryName = 'Omitted' then Converted_Amount_USD__c end) as Omitted_amt,
	sum(case when ForecastCategoryName = 'Omitted' then 1 end) as Omitted_count
	from PureDW_SFDC_Staging.dbo.Opportunity O
	where Partner_SE__c is not null
			--and O.Partner_SE__C in ('0030z00002TnOoQAAV')
			and O.CreatedDate >= '2019-02-01'
			and (O.Theater__c = 'America''s' or O.Theater__c = 'FlashBlade')
	group by O.Close_Month__c, O.Partner_SE__c
	) T
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id =T.Partner_SE__c
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
order by [Partner SE], [Close Month] desc
