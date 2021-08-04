/***************************************************************************/
/***                                                                     ***/
/***    Root:                                                            ***/
/***                                                                     ***/
/***    Account                                                          ***/
/***                                                                     ***/
/***************************************************************************/

#Account

With
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
)

Select Acc.Id [Partner Id], Acc.Name [Partner Name], Acc.Theater__c [Partner Theater], 
       PTM.Name [Partner PTM],
       SE.Manager [PTM Manager],
       case when SE.Manager = 'Mark Hirst' then 'America'
       		when SE.Manager = 'Markus Wolf' then 'EMEA'
       		when SE.Manager = 'Shuichi Nanri' then 'JP'
       		when SE.Manager = 'Karen Hoong' then 'APJ'
       		else NULL
       end [PTM Theater],
      case when Partner_Tier__c is null or Partner_Tier__c = 'None' then 'None'
       else Partner_Tier__c end [Partner Tier],
       [Type] [Partner Type]
       
from PureDW_SFDC_Staging.dbo.Account Acc
left join PureDW_SFDC_Staging.dbo.[User] PTM on PTM.Id = Acc.Channel_Technical_Manager__c
left join [GPO_TSF_Dev ].dbo.vSE_Org SE on SE.EmployeeID = PTM.EmployeeNumber
where Acc.Id in (
			Select Id 
			from PureDW_SFDC_staging.dbo.Account
			where Type in ('Reseller','Distributor')
			
			Union
			
			Select O.Partner_Account__c
			from PureDW_SFDC_staging.dbo.[Opportunity] O
			where O.Id in (select * from #Select_Oppt)
)

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
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
),


#Report_Contact as (
		Select C.Id 
		from PureDW_SFDC_Staging.dbo.[Contact] C
		left join PuredW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
		where P.Type in ('Reseller','Distributor')
		and C.Role_Type__c in ('Partner SE') or C.Participate_in_Wavemaker_programme__c = 'Yes'
		
		Union
		
		Select distinct(O.Partner_SE__c) [Id]
		from PureDW_SFDC_staging.dbo.Opportunity O
		where O.Id in (select * from #Select_Oppt)
)


Select C.Id [Contact_Id], Owner.Name [Contact Owner], C.IsDeleted, C.Owner_Is_Active__c
  	 , C.Name [Contact], C.Role_Type__c [Assigned Role], C.Email [Contact Email]
  	 , case when C.Participate_in_Wavemaker_programme__c = 'Yes' then 'Yes' else null end [Wavemaker Participtant]
  	 , C.Wavemaker_level__c [Wavemaker level]
  	 , C.AccountId [Partner Id]
  	 --, C_Acct.Name [Partner Name], C_Acct.Theater__c [Partner Theater], P_CTM.Name [Partner PTM]
  	 --, case when C_Acct.Partner_Tier__c is null or C_Acct.Partner_Tier__c = 'None' then 'None'
  	 --  else C_Acct.Partner_Tier__c end [Partner Tier]
  	 --, C_Acct.Type [Partner Type] 
  	 , C_CTM.Name [Contact PTM]
     , C.MailingCity [Contact City]
     , coalesce(C.MailingState, ' ') as [Contact State], C.MailingPostalCode [Contact PostalCode]
     , coalesce(C.MailingCountry, ' ') as [Contact Country]
     , left(C_User.Id,15) [Contact_UserId]
from PureDW_SFDC_staging.dbo.[Contact] C
--left join PureDW_SFDC_Staging.dbo.[Account] C_Acct on C_Acct.Id = C.AccountId
--left join PureDW_SFDC_Staging.dbo.[User] P_CTM on P_CTM.Id = C_Acct.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] C_CTM on C_CTM.Id = C.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] Owner on Owner.Id = C.OwnerId
left join PureDW_SFDC_Staging.dbo.[User] C_User on C_User.ContactId = C.Id
where C.Id in (Select * from #Report_Contact)
--and C_Acct.Name != 'HIDDEN'




/************************************/
/* Opportunity                      */
/************************************/
WITH
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
),

#Quote_Count (Oppt_Id, Quote_Created_Count, Partner_Quote_Created_Count)
as (
	Select [Oppt Id], count([Quote Id]) [Count Quotes Created], sum([Partner_Created_Quote]) [Count Partner Created Quote]
	from (
		Select Q.Id [Quote Id], Q.Name [Quote Name], Q.SBQQ__Opportunity2__c [Oppt Id], Q.CPQ_Opportunity_Name__c, Q.SBQQ__Primary__c, Q.Theater__c,
		Q.CPQ_Community_Quote__c, Case when Q.CPQ_Community_Quote__c = 'True' then 1 else 0 end [Partner_Created_Quote],
		case when CB.Email like '%purestorage.com' then 1 else 0 end [Created by PTSG doman],
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

#Multi_Oppt as (   /* number of Opportunity > $0 that this Partner has */
	select Partner_Account__c, AccountId, Multi_Oppt_on_Date, Partner_ToDate_Oppt_Count,
	case when RN = 1 then 'F' else 'T' end [Multi-Oppt_TF], -- equals T on the 2nd opportunity of a Partner + Account
	case when RN = 1 then 0 else 1 end [Multi-Oppt]
	from (
			select Id, Name, Partner_Account__c, AccountId, cast(CreatedDate as date) Multi_Oppt_on_Date,
				   row_number() over (partition by Partner_Account__c, AccountId order by CreatedDate) RN,
				   count(id) over (partition by Partner_Account__c, AccountId) Partner_ToDate_Oppt_Count
			from PureDW_SFDC_Staging.dbo.Opportunity
			where Partner_Account__c is not null
			and (Amount > 0)
	) a where (RN = 1 and Partner_ToDate_Oppt_Count = 1) or (RN=2) --get the 1st and the 2nd deals of a Partner + Account
),

#Multi_Won as (  /* number of Opportunity Won that this Partner has for a customer */
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
	select Opp_Id, [Number] [CSC PoC Number], State [CSC PoC State], created_at_date [CSC PoC CreatedDate], [SE First Name] + ' ' + [SE Last Name] [SE Requested CSC]
	from (
			select [SE First Name], [SE Last Name], [Email Address], Opp_ID, State, Number, created_at_Date,
				   ROW_NUMBER() over (partition by Opp_Id order by created_at_Date desc) rn
			from Datascience_Workbench_Views.dbo.v_csc_poc_clean
			where Opp_ID is not null
		  ) a where a.rn = 1
)

----------------------------
Select Oppt.*,
/*	Case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff (year, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' year'
		 when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' year'
	end [Relative_CloseYear_T],
	 
	Case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' quarter'
		 when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' quarter'
	end [Relative_CloseQtr_T],

	Case when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(month, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' month'
		 when datediff(month, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(month, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' month'
	end [Relative_CloseMonth_T],
*/
	
	datediff(year, [Current Fiscal Month], [Fiscal Close Month])  [Relative_CloseYear],
	datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) [Relative_CloseQtr],
	datediff(month, [Current Fiscal Month], [Fiscal Close Month]) [Relative_CloseMonth]
	
	from (
		Select					
			O.Id [Oppt Id], O.Name [Opportunity], EU_Acct.Name [Customer], EU_Acct.Id [Oppt_AccountId],
			O.Product_Type__c [Product], O.Manufacturer__c [Mfg], O.[Type], Rec.Name [Oppt RecType],
			
		    case
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
			end [Solution],
			
			O.Theater__c [Theater], O.Sub_Division__c [Sub_Division], O.Division__c [Division],
			O.StageName,
			O.Stage_Prior_to_Close__c [Stage Prior to Close],
			
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 1 else 0 end Won_Count,
			case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 1 else 0 end Loss_Count,
			case when cast(substring(O.StageName,7,1) as int) < 8  then 0 else 1 end Open_Count,
			case when cast(substring(O.StageName,7,1) as int) = 8 then 1 else 1 end Close_Count,
	
			case 
			 	 when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
			 	 when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss'
				 else 'Open'
			end [StageGroup],
							
			O.CurrencyIsoCode, O.Amount, O.Converted_Amount_USD__c [Amount_in_USD],
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then O.Converted_Amount_USD__c else 0 end as Booking$,
			case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then O.Converted_Amount_USD__c else 0 end as Loss$,

			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and 
					  O.Partner_Sourced__c = 'true' then O.Converted_Amount_USD__c else 0 end as [PSourced Booking$],
			case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') and
					  O.Partner_Sourced__c = 'true' then O.Converted_Amount_USD__c else 0 end as [PSourced Loss$],
			
			O.Partner_Sourced__c [Partner Sourced], O.Channel_Led_Deal__c [CLed],
--			case when O.Channel_Led_Deal__c = 'true' then 1 else 0 end [CLed Deal 1/0],
--			case when O.Partner_Sourced__c = 'true' then 1 else 0 end [Partner Sourced 1/0], --when CAM convert a Partner registrated oppt to a SFDC oppt, the checkbox is checked
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_Account__c is not null then O.Partner_Account__c else null end [Won Partner],
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_AE__c != O.Partner_SE__c and O.Partner_SE__c is not null then O.Partner_SE__c else null end [Won Partner SE],
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_Sourced__c = 'true' then O.Partner_Account__c else null end [Won P-Sourced Partner],
			case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Partner_Sourced__c = 'true' then O.Id else null end [Won P-Sourced Opportunity],
			
			O.Partner_SE_Contribution__c,
			O.Partner_SE_Engagement_Level__c,

			POC.Id [POC Id],
			POC.Eval_Stage__c [Eval Stage],
			--case when POC.Eval_Stage__c is null then 'false' else 'true' end [Customer_Site_POC_Used T/F],
			case when POC.Ship_Date__c is null then 'false' else 'true' end [Customer_Site_POC_Used T/F],
			POC.Customer_Site_PoC__c,
			CSC.[CSC PoC Number],
			case when CSC.[CSC PoC Number] is null then 'false' else 'true' end [CSC_POC_Used T/F],
	
			QC.Quote_Created_Count, 
			QC.Partner_Quote_Created_Count,
			Case when QC.Partner_Quote_Created_Count > 0 then 1 else 0 end [Partner created quote 1/0],
				
			O.Partner_AE__c [Partner AE], O.Partner_SE__c [Partner SE Id],
			Partner_SE.Name [Partner SE], Partner_SE.Wavemaker_level__c [Wavemaker level],
	  	    case when Partner_SE.Participate_in_Wavemaker_programme__c = 'Yes' then 'Yes' else null end [Wavemaker Participtant],
	  	    
			-- the Partner listed on an Opportunity
			case when O.Partner_Account__c is null then 0 else 1 end [Oppt has Partner],
			O.Partner_Account__c [Partner Id], P.Name [Partner Name],
			case when P.Partner_Tier__c is null or P.Partner_Tier__c = 'None' then 'None'
			else P.Partner_Tier__c end [Partner Tier],
			P.Type [Partner Type],  /* User Oppt.Partner Account. Impact the Partner SE may be grouped into a different account, the Partner SE count could impacted */
			P.Theater__c [Partner Theater], P.Sub_Division__c [Partner SubDivision],
			
			-- the Distributor listed on an Opportunity			
			case when O.Partner_Account__c is null then 0 else 1 end [Oppt has Disti],
			O.Distributor_Account__c, Dist.Name [Disti],
			--Dist.Ultimate_Parent_Id__c [UL Id],  /* use the mapping provided by Scott Dedmen */
	
			case when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is null) then 'Other'
				 when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is not null) then Dist_UL.[Disti]
		 		 else null
			end as [Parent Disti],
			
			case when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is null) then 'Other'
				 when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is not null) then Dist_UL.[Theater]
				 else null
			end as [Parent Disti Theater],
			
			cast(O.CreatedDate as Date) CreatedDate,
			DateFromParts(cast(substring(CreateDate_445.FiscalMonthKey,1,4) as int), cast(substring(CreateDate_445.FiscalMonthKey,5,2) as int),1) [Fiscal Created Month],
			'FY' + right(CreateDate_445.FiscalYear,2) [Fiscal Create Year],
			'FY' + right(CreateDate_445.FiscalYear,2) + ' ' + CreateDate_445.FiscalQuarterName [Fiscal Created Quarter], 
	
			cast(O.CloseDate as Date) CloseDate,
			DateFromParts(CloseDate_445.FiscalYear, CloseDate_445.FiscalMonth, 1) [Fiscal Close Month],
			dateadd(month, 1, DateFromParts(CloseDate_445.FiscalYear, CloseDate_445.FiscalMonth, 1)) [Fiscal Close Month Label],
			'FY' + right(CloseDate_445.FiscalYear,2) [Fiscal Close Year],
			'FY' + right(CloseDate_445.FiscalYear,2) + ' '+ CloseDate_445.FiscalQuarterName [Fiscal Close Quarter],
			--'FY' + right(cast(O.Fiscal_Year__c as varchar),2) [Fiscal Close Year], /* SFDC Fiscal values are not 445 value */
			--'FY'+ right(cast(O.Fiscal_Year__c as varchar),2) + ' ' + left(O.Close_Fiscal_Quarter__c,2) [Fiscal Close Quarter],
			
			DateFromParts(Year(DateAdd(month, 11, GetDate())), Month(DateAdd(month, 11, GetDate())), 1) as [Current Fiscal Month]
						
			, MO.Multi_Oppt_on_Date
			, Case when MO.Partner_ToDate_Oppt_Count is null then 0 else MO.Partner_ToDate_Oppt_Count end Partner_ToDate_Oppt_Count
			, Case when MO.[Multi-Oppt_TF] is null then 'F' else MO.[Multi-Oppt_TF] end [Multi-Oppt_TF]
			, Case when MO.[Multi-Oppt] is null then 0 else MO.[Multi-Oppt] end [Multi-Oppt]
	
			, MW.Multi_Won_On_Date
			, Case when MW.Partner_ToDate_Won_Count is null then 0 else MW.Partner_ToDate_Won_Count end Partner_ToDate_Won_Count
			, Case when MW.[Multi-Won_TF] is null then 'F' else MW.[Multi-Won_TF] end [Multi-Won_TF]
			, Case when MW.[Multi-Won] is null then 0 else MW.[Multi-Won] end [Multi-Won]
		
			from PureDW_SFDC_Staging.dbo.Opportunity O
			left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
			left join PureDW_SFDC_Staging.dbo.Account P on P.Id = O.Partner_Account__c
			left join PureDW_SFDC_Staging.dbo.[Contact] Partner_SE on Partner_SE.Id = O.Partner_SE__c
			left join PureDW_SFDC_Staging.dbo.Account Dist on Dist.Id = O.Distributor_Account__c
			left join SalesOps_DM.dbo.CTM_Disti_Map Dist_UL on Dist_UL.Child_Account_Id = O.Distributor_Account__c
						
			left join PureDW_SFDC_Staging.dbo.Account EU_Acct on EU_Acct.Id = O.AccountId
			
			left join PureDW_SFDC_Staging.dbo.POC__c POC on POC.Opportunity__c = O.Id
			left join #CSC_POC CSC on CSC.Opp_Id = O.Id
	
			left join #Quote_Count QC on QC.Oppt_Id = O.Id
			left join #Oppt_MDE_Solution Sol on Sol.Id = O.Id
			
			left join #Multi_Oppt MO on MO.Partner_Account__c = O.Partner_Account__c and MO.AccountId = O.AccountId
			left join #Multi_Won MW on MW.Partner_Account__c = O.Partner_Account__c and MW.AccountId = O.AccountId
	
			left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, O.CreatedDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)
						
			where O.Id in (Select * from #Select_Oppt)
			--and O.Partner_Account__c is not null  --- Selecting Capax and PaaS Oppt where Partner Account is stamped
) Oppt




/**********************************************/
/* Opportunity Portfolio breakdown            */
/**********************************************/ 
/** Product Category mimic Clari  
 *  Portfolio is how PTM/PTD wants to look at */
 
-- OpEX Opportunity
Select O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName, O.Converted_Amount_USD__c [Amount_in_USD],
	   Case when (CBS_Category__c is not null and CBS_Category__c != 'NO CBS') then 'CBS'
	   		when O.Transaction_Type__c in ('Debook','ES2 Initial Deal','ES2 Reserve Expansion','ES2 Billing','ES2', 'ES2 Renewal') then 'PaaS'
	   		else 'Misc.' end [Portfolio],
	   O.Converted_Amount_USD__c [Portfolio_Amount_in_USD], 
	   
	   Case when O.Transaction_Type__c in ('Debook','ES2 Initial Deal','ES2 Reserve Expansion','ES2 Billing', 'ES2 Renewal') then 'PaaS' else 'Misc.' end [Product],
	   O.Converted_Amount_USD__c [Product_Amount_in_USD]
	   
from PureDW_SFDC_Staging.dbo.Opportunity O
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('ES2 Opportunity')
  and cast(O.Theater__c as nvarchar(50)) != 'Renewals'
  and CloseDate >= '2018-02-01'

UNION

-- Capex
/* if Opportunity do not have product detail, then use the Manufacturer and Product value to classify the amount */  
Select O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName, O.Converted_Amount_USD__c [Amount_in_USD],
	    Case when O.Manufacturer__c != 'Pure Storage' and O.Manufacturer__c is not null then O.Manufacturer__c
	   	     when O.Manufacturer__c = 'Pure Storage' and O.Product_Type__c = 'FlashArray' then NULL
	   	     when O.Manufacturer__c = 'Pure Storage' and O.Product_Type__c = 'FlashBlade' then O.Product_Type__c
	   	    else 'Unknown'
	   end [Portfolio],

	   0 [Portfolio_Amount_in_USD],
	   Case when O.Manufacturer__c != 'Pure Storage' and O.Manufacturer__c is not null then O.Manufacturer__c
	   	    When O.Manufacturer__c = 'Pure Storage' then O.Product_Type__c
	   	    else 'Unknown'
	   end [Product],
	   O.Converted_Amount_USD__c [Product_Amount_in_USD]
	   
from PureDW_SFDC_Staging.dbo.Opportunity O
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('Sales Opportunity')
  and cast(O.Theater__c as nvarchar(50)) != 'Renewals'
  and CloseDate >= '2018-02-01'
  and (Count_of_Products__c is null or Count_of_Products__c = 0)

UNION

/* insert another FA line for Portfolio amount */
Select O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName, O.Converted_Amount_USD__c [Amount_in_USD],
	   Case when O.Product_Type__c = 'FlashArray' then 'FA-Other' end [Portfolio],
	   O.Converted_Amount_USD__c [Portfolio_Amount_in_USD], 
	   null as [Product], 0 [Product_Amount_in_USD]
from PureDW_SFDC_Staging.dbo.Opportunity O
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('Sales Opportunity')
  and cast(O.Theater__c as nvarchar(50)) != 'Renewals'
  and CloseDate >= '2018-02-01'
  and (Count_of_Products__c is null or Count_of_Products__c = 0)

/* FlashArray Amount = FA-X + FA-C + FA-Other. Don't double count the amount */
UNION

-- CapEx Opportunity which has product details
Select Oppt_Id, [Oppt RecType], [CBS_Category__c], Manufacturer__c, Product_Type__c, StageName, [Amount_in_USD],

	   case when [upvt_Portfolio_Col] = 'Total_C_Amount__c' then 'FA-C'
			when [upvt_Portfolio_Col] = 'Total_X_Amount__c' then 'FA-X'
			when [upvt_Portfolio_Col] = 'Total_FA_Other_Amount' then 'FA-Other'
			--when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 'FlashArray'
			when [upvt_Portfolio_Col] = 'Total_FlashBlade_Amount__c' then 'FlashBlade'
			when [upvt_Portfolio_Col] = 'Total_Cisco_MDS_Amount__c' then 'Cisco MDS'
			when [upvt_Portfolio_Col] = 'Total_Cohesity_Amount__c' then 'Cohesity'
			when [upvt_Portfolio_Col] = 'Total_Brocade_Amount__c' then 'Brocade'
			when [upvt_Portfolio_Col] = 'Total_Professional_Services_Amount__c' then 'Professional Services'
		 	when [upvt_Portfolio_Col] = 'Total_Training_Amount__c' then 'Training'
		 	when [upvt_Portfolio_Col] = 'Total_Credit_Amount__c' then 'Credit'
		 	when [upvt_Portfolio_Col] = 'Total_Misc_Amount' then 'Misc.'
		end [Portfolio],

		case when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 0
			 else upvt_Amt_USD
		end [Portfolio_Amt_USD],

		case --when [upvt_Portfolio_Col] = 'Total_C_Amount__c' then 'FA-C'
			--when [upvt_Portfolio_Col] = 'Total_X_Amount__c' then 'FA-X'
			--when [upvt_Portfolio_Col] = 'Total_FA_Other_Amount' then 'FA-Other'
			when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 'FlashArray'
			when [upvt_Portfolio_Col] = 'Total_FlashBlade_Amount__c' then 'FlashBlade'
			when [upvt_Portfolio_Col] = 'Total_Cisco_MDS_Amount__c' then 'Cisco MDS'
			when [upvt_Portfolio_Col] = 'Total_Cohesity_Amount__c' then 'Cohesity'
			when [upvt_Portfolio_Col] = 'Total_Brocade_Amount__c' then 'Brocade'
			when [upvt_Portfolio_Col] = 'Total_Professional_Services_Amount__c' then 'Professional Services'
		 	when [upvt_Portfolio_Col] = 'Total_Training_Amount__c' then 'Training'
		 	when [upvt_Portfolio_Col] = 'Total_Credit_Amount__c' then 'Credit'
		 	when [upvt_Portfolio_Col] = 'Total_Misc_Amount' then 'Misc.'
		end [Product],
		
		case when [upvt_Portfolio_Col] in ('Total_C_Amount__c','Total_X_Amount__c','Total_FA_Other_Amount') then 0
			 else upvt_Amt_USD
		end [Product_Amt_USD]
from 
	(
		Select O.Id [Oppt_Id], O.Name [Oppt], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName,
		    	O.Converted_Amount_USD__c [Amount_in_USD],
       			O.Total_Cisco_MDS_Amount__c, O.Total_Cohesity_Amount__c, O.Total_Brocade_Amount__c,
       			O.Total_FlashArray_Amount__c, O.Total_FlashBlade_Amount__c, O.Total_X_Amount__c, O.Total_C_Amount__c,
       			O.Total_Professional_Services_Amount__c, O.Total_Training_Amount__c, O.Total_Credit_Amount__c,
       			cast((O.Total_FlashArray_Amount__c - O.Total_X_Amount__c - O.Total_C_Amount__c) as decimal(18,2)) as Total_FA_Other_Amount,

       			cast((O.Converted_Amount_USD__c - 
       				  O.Total_Cisco_MDS_Amount__c - O.Total_Cohesity_Amount__c - O.Total_Brocade_Amount__c -
       				  O.Total_FlashArray_Amount__c - O.Total_FlashBlade_Amount__c -
       				  O.Total_Professional_Services_Amount__c - O.Total_Training_Amount__c - O.Total_Credit_Amount__c
       				  ) as decimal(18,2))
       			as Total_Misc_Amount
       			
		from PureDW_SFDC_Staging.dbo.Opportunity O
		left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
		where RecT.Name in ('Sales Opportunity')
		  and cast(O.Theater__c as nvarchar(50)) != 'Renewals'
		  and CloseDate >= '2018-02-01'
		  and Count_of_Products__c > 0
--		  and O.Id = '0060z00001s5bHZAAY' --'0060z00001zqDnvAAE'
	) src
	unpivot (upvt_Amt_USD for [upvt_Portfolio_Col] in (Total_Cisco_MDS_Amount__c, Total_Cohesity_Amount__c, Total_Brocade_Amount__c,
		       Total_FlashArray_Amount__c, Total_FlashBlade_Amount__c, Total_X_Amount__c, Total_C_Amount__c, 
		       Total_Professional_Services_Amount__c, Total_Training_Amount__c, Total_Credit_Amount__c,
		       Total_FA_Other_Amount, Total_Misc_Amount)
	) pvt

/**********************************************/
/* FA Foundation & Professional Certification */
/**********************************************/  
select Cert.Contact__c [Contact_Id]
--	P.Id [Partner Id], P.Name [Partner Name], P.Type, P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater]
	,  C.Name [Contact],Cert.Email_Corporate__c
	,  Cert.Exam_Code__c, Cert.Exam_Group__c, Cert.Exam_Name__c, Cert.Exam_Grade__c, cast(Cert.Exam_Date__c as Date) [Exam Date]
	, case when Cert.Exam_Code__c in ('FAP_001', 'FAP_002') then 'FA Professional'
		   when Cert.Exam_Code__c in ('PCA_001', 'PCA_Acc001', 'PCADA_001', 'PCARA_001') then 'FA Associate'
		   when Cert.Exam_Code__c in ('FAAE_001') then 'FA Expert'
		   when Cert.Exam_Code__c in ('FAIP_001', 'FAIP_002', 'PCIA_001') then 'FA Implementation'
		   when Cert.Exam_Code__c in ('FBAP_001') then 'FB Professional'
		   when Cert.Exam_Code__c in ('PCSA_001') then 'Support Assoicate' -- exclude in the report
		   else 'Other' end [Pure Certification]
from PureDW_SFDC_Staging.dbo.Pure_Certification__c Cert
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Cert.Contact__c
--left join PureDW_SFDC_Staging.dbo.Account P on P.Id = C.AccountId
where Contact__c is not NULL
--and P.[Type] in ('Reseller', 'Disti')
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
With
#Contact_first_TD_and_UseCnt as (
	select [Created by user name], [Created by company type], [Contact 1st TD Created at],
		   [Contact 1st TD session FY], [Contact 1st TD session FQ],
		   [Contact TD Use Cnt], rn 
	from (
		select [Created by], [Created by user name], [Created by company type], convert(date, [Created at], 20) [Contact 1st TD Created at],
			   'FY' + right(cast([FiscalYear] as varchar),2) [Contact 1st TD session FY],
			   'FY' + right(cast([FiscalYear] as varchar),2) + ' ' + [FiscalQuarterName] [Contact 1st TD session FQ],
			   ROW_NUMBER() over (PARTITION by [Created by user name] order by [Created at]) rn,
			   COUNT(*) over (PARTITION by [Created by user name]) [Contact TD Use Cnt]
		from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
	) a where a.rn = 1  
),

#TD_Report_Period as (
		select Date_ID,
		   datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1) [TestDrive_FiscalCreatedMonth],
		   dateadd(month, 1, datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1)) [TestDrive_FiscalCreatedMonth_Label],
		   'FY' + substring(FiscalYear,3,2) + ' ' + FiscalQuarterName [TestDrive_FiscalCreatedQuarter],
		   'FY' + substring(FiscalYear,3,2) [TestDrive_FiscalCreatedYear]
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= (
				/* first day of 23 fiscal month ago */
				select min(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					SELECT left(convert(varchar, dateadd(month, -23, datefromparts(FiscalYear, FiscalMonth,1)), 112),6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112)
					)
			   )
			   and 
			   Date_Id <= (			   
				/* last day of the fiscal momth of the current date */
				select max(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					Select left(FiscalMonthKey, 6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112)
					)
				)
)

select #TD_Report_Period.[TestDrive_FiscalCreatedMonth], #TD_Report_Period.[TestDrive_FiscalCreatedMonth_Label],
	   #TD_Report_Period.[TestDrive_FiscalCreatedYear], #TD_Report_Period.[TestDrive_FiscalCreatedQuarter],
	   a.[Created By], a.[TestDrive Created_By_User_Email], a.[Created by company type], a.[Created at],
	   a.[Lab name], a.[Product], a.[Contact TD Use Cnt],
	   a.[Contact 1st TD Created at], a.[Contact 1st TD Session FY], a.[Contact 1st TD session FQ]
from #TD_Report_Period
left join (
					/* select the Test Drive run by Partner Users */
					select U.[Created by], U.[Created by user name],
						   case when U.[Created by user name] like '%.p3' then substring(U.[Created by user name], 1, len(U.[Created by user name])-3)
						   	    else U.[Created by user name]
						   end [TestDrive Created_By_User_Email],
						   U.[Created by company type],U.[Created at], convert(varchar, cast(U.[Created at] as date), 112) [TestDrive_CreatedDate_ID],
						   [Lab name], [Product],
						   FTD.[Contact TD Use Cnt], FTD.[Contact 1st TD Created at], FTD.[Contact 1st TD session FY], FTD.[Contact 1st TD session FQ]
					from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values U
					left join #Contact_first_TD_and_UseCnt FTD on FTD.[Created by user name] = U.[Created by user name]
					where U.[Created by company type] = 'Channel partner'
					and U.[Created by] not like 'Pure Storage%'
) a on a.[TestDrive_CreatedDate_ID] = #TD_Report_Period.Date_ID

/**************************************************/
/* FA Sizer Log in GPO                            */
/* report # of FA Sizer created by Partner Users  */ 
/**************************************************/  
With
#FA_Report_Period as (
		select Date_ID,
		   datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1) [FASizer_FiscalCreatedMonth],
		   dateadd(month, 1, datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1)) [FASizer_FiscalCreatedMonth_Label],
		   'FY' + substring(FiscalYear,3,2) + ' ' + FiscalQuarterName [FASizer_FiscalCreatedQuarter],
		   'FY' + substring(FiscalYear,3,2) [FASizer_FiscalCreatedYear]
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= (
				/* first day of 23 fiscal month ago */
				select min(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					SELECT left(convert(varchar, dateadd(month, -23, datefromparts(FiscalYear, FiscalMonth,1)), 112),6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112))
			   )
			   and 
			   Date_Id <= (			   
				/* last day of the fiscal momth of the current date */
				select max(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					Select left(FiscalMonthKey, 6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112))
				)
),

#FA_Contact_FirstCreate as (
	Select Sizer.Email, Sizer.[Contact 1st Sizer created Date],
	'FY' + right(D.FiscalYear,2) [Contact 1st Sizer created FY],
	'FY' + Right(D.FiscalYear,2) + ' ' + D.FiscalQuarterName [Contact 1st Sizer created FQ]
	from (
			Select email, cast(min(datemin) as Date) [Contact 1st Sizer created Date]
				from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action
				where email not like '%purestorage.com' and email != ''
				  and sizeraction = 'Create Sizing'
				group by email
		 ) Sizer
		 left join NetSuite.dbo.DM_Date_445_With_Past D on D.Date_ID = convert(char(8), [Contact 1st Sizer created Date], 112)				
)

SELECT a.[Sizer_CreatedDate], #FA_Report_Period.[FASizer_FiscalCreatedMonth], #FA_Report_Period.[FASizer_FiscalCreatedMonth_Label],
	   #FA_Report_Period.[FASizer_FiscalCreatedQuarter], #FA_Report_Period.[FASizer_FiscalCreatedYear],
	   a.[Contact Email], a.sizeraction, a.request_id,
	   FC.[Contact 1st Sizer created Date], FC.[Contact 1st Sizer created FY], FC.[Contact 1st Sizer created FQ]
FROM #FA_Report_Period
LEFT JOIN (
		Select datemin [Sizer_CreatedDate], convert(char(8), datemin, 112) [SizerCreate_Date_ID]
			   , Sizer.email [Contact Email], Sizer.sizeraction, request_id
		from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action Sizer
		where Sizer.email not like '%purestorage.com' and Sizer.email != ''
		  and Sizer.sizeraction = 'Create Sizing'
) a on a.[SizerCreate_Date_ID] = #FA_Report_Period.[Date_ID]
LEFT JOIN #FA_Contact_FirstCreate FC on FC.email = a.[Contact Email]


Select max(datemin)
from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action Sizer
where Sizer.email not like '%purestorage.com' and Sizer.email != ''
		  and Sizer.sizeraction = 'Create Sizing'

		  
		  
/****** CSC       ***/
		  
		  
/****** Certification ******/
--Pure_Certification_Log
Select b.*
		, case when [Contact_Cert_Seq] = 1 then Contact_Id else null end [Certification New Contact]
		, case when [Exam Seq] = 1 then Contact_Id else null end [Contact-s New Certification]
		, 'FY' + right(ED.FiscalYear,2) [Exam Fiscal Year]
		, 'FY' + right(ED.FiscalYear,2) + ' ' + ED.FiscalQuarterName [Exam Fiscal Quarter]
	from (
		Select CreatedDate, Contact__c Contact_Id, Exam_Code__c, Exam_Category_Code
				   , case when (Exam_Code__c like 'PCARA_%') then 'Architect Associate Certificate' --
						  when (Exam_Code__c like 'FAP_%') then 'FA Architect Professional Certificate' --
						  when (Exam_Code__c like 'FAAE_%') then 'FA Architect Expert Certificate'
						  when (Exam_Code__c like 'FBAP_%') then 'FB Architect Professional Certificate' --
						  when (Exam_Code__c like 'FAIP_%') then 'FA Implementation Professional Certificate'
						  when (Exam_Code__c like 'PCIA_%') then 'Implementation Associate Certificate'
						   				   
						  when (Exam_Code__c like 'PCA_%') then 'Pure Storage Foundation Certificate' --
						  when (Exam_Code__c like 'PCADA_%') then 'Adminstration Associate Certificate'
						  when (Exam_Code__c like 'PCSA_%') then 'Support Associate Certificate'
					  end [Pure Certification]
			
				   , Exam_Grade__c, cast(Exam_Date__c as date) [Exam Date], cast(Cert_Expiration_Date__c as date) [Cert Expiration Date] 
				   , case when Cert_Expiration_Date__c > getdate() then 1 else 0 end [Cert_Expired 1/0]
				   , ROW_NUMBER() over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [Exam Seq]
				   , count(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [# of times taken this exam]
				   , min(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_date__c) [1st time taken this exam]
				   , max(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [Most recent taken this exam]
	
				   , ROW_NUMBER() over (partition by Contact__c order by Exam_Date__c) [Contact_Cert_Seq]
				   , min(Exam_Date__c) over (partition by Contact__c ) [Contact 1st Cert]
				   , max(Exam_Date__c) over (partition by Contact__c ) [Contact most recent Cert]
	
			from ( /* Create a standardize the Exam Category Code */
			 		Select CreatedDate, Contact__c
						   , Exam_Grade__c, Exam_Date__c, Cert_Expiration_Date__c
						   , case when Cert_Expiration_Date__c >= getdate() then 1 else 0 end [Cert_Expired 1/0] 
						   , Exam_Code__c, left(Exam_Code__c, charindex('_', Exam_Code__c)-1) Exam_Category_Code
					from PureDW_SFDC_staging.dbo.Pure_Certification__c
					where Contact__c is not null	  
				 ) a
			
	) b
	left join NetSuite.dbo.DM_Date_445_With_Past ED on ED.Date_ID = convert(varchar, b.[Exam Date], 112)

/*
select Cert.Contact__c [Contact_Id]
--	P.Id [Partner Id], P.Name [Partner Name], P.Type, P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater]
	,  C.Name [Contact],Cert.Email_Corporate__c
	,  Cert.Exam_Code__c, Cert.Exam_Group__c, Cert.Exam_Name__c, Cert.Exam_Grade__c, cast(Cert.Exam_Date__c as Date) [Exam Date]
	, case when Cert.Exam_Code__c in ('FAP_001', 'FAP_002') then 'FA Professional'
		   when Cert.Exam_Code__c in ('PCA_001', 'PCA_Acc001', 'PCADA_001', 'PCARA_001') then 'FA Associate'
		   when Cert.Exam_Code__c in ('FAAE_001') then 'FA Expert'
		   when Cert.Exam_Code__c in ('FAIP_001', 'FAIP_002', 'PCIA_001') then 'FA Implementation'
		   when Cert.Exam_Code__c in ('FBAP_001') then 'FB Professional'
		   when Cert.Exam_Code__c in ('PCSA_001') then 'Support Assoicate' -- exclude in the report
		   else 'Other' end [Pure Certification]
from PureDW_SFDC_Staging.dbo.Pure_Certification__c Cert
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Cert.Contact__c
--left join PureDW_SFDC_Staging.dbo.Account P on P.Id = C.AccountId
where Contact__c is not NULL
*/