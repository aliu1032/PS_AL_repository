/* 
Change made on and after May 3
- Renname Oppt_Split_User_Territory_ID to Acct_Exec_TerritoryID
- Select closed date between 2019-02-01 to 2020-01-31
- For Overlay, include only Theater = 'FlashBlade'
- TempCoverage, select the TC_Amount is positive, and concatenate the Temp_Covered Names by Oppt Id. There could be multiple Temp Coverage Records
- Remove Transaction_Type = ES2 Renewal. There is null value in Transaction Type (need to do 'Transaction_type is null or Transaction_type != ES2 Renewal)
*/


--Declare @Snapshot_date Date
--set @Snapshot_date = '2019-04-01'

-- the cte tables go to init SQL
with
/* Listings, Combined, Last_row :: roll up multiple Temp Coverage Oppt Split Record
   Summarize the Temp Coveage split owner into 1 TempCov record
*/
Listings (OpptId, rnk, SplitOwner, EmployeeNumber) as (
			select OpptSplit.OpportunityId, 
			ROW_NUMBER() over (Partition by OpptSplit.OpportunityId order by OpptSplit.CreatedDate),
			CAST(SplitOwner.Name as NVARCHAR(1000)),
			CAST(SplitOwner.EmployeeNumber as NVARCHAR(1000))
			from [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit
			left join [PureDW_SFDC_staging].[dbo].[User] SplitOwner on SplitOwner.Id = OpptSplit.SplitOwnerId
			left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on SplitType.Id = OpptSplit.SplitTypeId
			where OpptSplit.LastModifiedDate >= '2019-02-01'
			and SplitType.MasterLabel in ('Temp Coverage')
			and OpptSplit.TC_Amount__c > 0.00
			),

Combined (OpptId, rnk, SplitOwner, EmployeeNumber) as (
			select Listings.OpptId, Listings.rnk, 
			cast(Listings.SplitOwner as NVARCHAR(1000)), 
			cast(Listings.EmployeeNumber as NVARCHAR(1000))
			from Listings
			where Listings.rnk = 1

			UNION ALL -- to keep the duplicte oppt id

			Select Listings.OpptId, Listings.rnk, 
			cast((Combined.SplitOwner + ' | ' + Listings.SplitOwner) as NVARCHAR(1000)) as SplitOwner,
			cast((Combined.EmployeeNumber + ' | ' + Listings.EmployeeNumber) as NVARCHAR(1000)) as EmployeeNumber
			from Listings
			inner join Combined on Combined.OpptId = Listings.OpptId and Listings.rnk = Combined.rnk+1
			),

Last_row (OpptId, rnk) as (
			select OpptId, Max(rnk)
			from Listings
			group by OpptId),

TempCov1 (OpportunityId, Temp_CoveredBy_Name, Temp_CoveredBy_EmployeeId, Max_rnk) as (
		select OpptId, MAX(SplitOwner), MAX(EmployeeNumber), Max(rnk)
		from Combined
		group by OpptId),
		
/* Pull the SE Temp Coverage Records */		
#TempCov (OpportunityId, Temp_CoveredBy_Name, Temp_CoveredBy_EmployeeNumber, Max_rnk) as (
		select Combined.OpptId, Combined.SplitOwner, Combined.EmployeeNumber, Combined.rnk
		from Combined
		right join Last_row 
		on Last_row.OpptId = Combined.OpptId and Last_row.rnk = Combined.rnk),

/* Opportunity values on a week ago */
#OpptHist as(
		select groups.OpportunityId, groups.CurrencyIsoCode, groups.Amount, groups.ForecastCategory, groups.StageName, groups.CloseDate
				from (
					Select OpportunityId, CurrencyIsoCode, Amount, ForecastCategory, StageName, CloseDate, CreatedDate,
					ROW_Number() over (partition by OpportunityId order by CreatedDate desc) as [Row Number]
					from [PureDW_SFDC_Staging].[dbo].[OpportunityHistory]
					where convert(date, CreatedDate) <= (getdate()-7) -- values as on the OpptHistory created date
					) groups
			where [Row Number] = 1
),

/* Geo Annual Quota */
#Geo_Annual_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.Territory_Quota
	where Period = 'FY'
	),

/* Geo Half Year Quota */
#Geo_Half_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.Territory_Quota
	where Period in ('1H','2H')
	),
	
/* Geo Half Year Quota */
#Geo_Qtrly_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region
	from SalesOps_DM.dbo.Territory_Quota
	where Period in ('Q1','Q2','Q3','Q4')
	),


#AE_Coverage as (
		select Name, EmployeeID, Territory_ID from (
			select Name, EmployeeID, Territory_ID
			, ROW_NUMBER() over (PARTITION by EmployeeID order by Territory_ID) as [Row Number]
			from SalesOps_DM.dbo.Coverage_assignment_byName
		) a where [Row Number] = 1
)		

/*   SQL             */

select a.*

	, CASE When [Close Date] = [Previous CloseDate] Then 'N' Else 'Y' END CloseDate_changed

	, Case When (Oppt_Amount is null) and ([Previous Amount] is null) then 'N'
		   When (Oppt_Amount is null) and ([Previous Amount] is not null) then 'Y'
		   When (Oppt_Amount is not null) and ([Previous Amount] is null) then 'Y'
		   When Oppt_Amount - [Previous Amount] = 0 Then 'N' Else 'Y' 
	  End Amt_changed	

	, CASE When Stage = a.[Previous Stage] Then 'N' Else 'Y' END Stage_changed
	
	, Case   
		   when CreatedDate >= (getdate()-7) then 'New'
		   when (CreatedDate < (getdate()-7)) and (Stage != [Previous Stage] or [Close Date] != [Previous CloseDate]) then 'Updated'
		   when (CreatedDate < (getdate()-7)) and (Oppt_Amount is not null and [Previous Amount] is null) then 'Updated'
		   when (CreatedDate < (getdate()-7)) and (Oppt_Amount is null and [Previous Amount] is not null) then 'Updated'
		   when (CreatedDate < (getdate()-7)) and (Oppt_Amount is not null and [Previous Amount] is not null and Amount_in_USD-[Previous Amount] != 0) then 'Updated'
		   else 'No Change'
	  end Change_Since_SnapShot

	/* setup date for 7 days change summary */  
	, case -- have to tag in this sequence: Closed, New, the stage change. 
		when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then 'Won' -- Closed in last 7 days
		when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity'))
											  then 'Loss, Disqualified, Undecided' -- Closed in last 7 days
		when CreatedDate >= (getdate()-7) then 'New'   -- New in the last 7 days
		when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Advanced'
		when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Setback'
		when cast(SUBSTRING(Stage, 7, 1) as Int) = cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'No change'
		end Stage_changed_how
	  
	, case when ([Close Date] >= (getdate()-7) and cast(SUBSTRING(Stage, 7,1) as Int) = 8) then 1 else 0 end as Closed_Count
	, case when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then Amount_in_USD else 0 end as Won$_ThisWeek
	, Case when (CreatedDate >= (getdate()-7) and cast(SUBSTRING(Stage, 7,1) as Int) != 8) then 1 else 0 end as New_Count  -- New this week and have not closed
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				cast(SUBSTRING(Stage, 7,1) as Int) != 8 and  -- not advanced to close
				CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Stage_Advanced_Count	  
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Stage_Setback_Count

	, Case 
		when cast(subString(Stage,7,1) as Int) <= 3 then 'Early Stage'
		when cast(subString(Stage,7,1) as Int) <= 5 then 'Advanced Stage'
		when cast(subString(Stage,7,1) as Int) <= 7 then 'Commit'
		when Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Closed/Won'
		when Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Closed/Loss'
		else 'Unclassified'
	  end StageGroup
		
	, Case when Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then Amount_in_USD else 0 end Bookings$
	, Case when Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then split/100 else 0 end Won_Count	
	, Case when Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then a.Amount_in_USD else 0 end Loss$
	, Case when Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then split/100 else 0 end Loss_Count

	, case when cast(substring(a.Stage, 7, 1) as int) <= 7 then Amount_in_USD else 0.00 end as [Open$]
	, Case when cast(subString(a.Stage,7,1) as Int) <= 3 then Amount_in_USD else 0 end Early_Stage$
	, Case when cast(subString(a.Stage,7,1) as Int) = 4 or cast(subString(a.Stage,7,1) as Int) = 5 then Amount_in_USD else 0 end Adv_Stage$
	, Case when cast(subString(a.Stage,7,1) as Int) = 6 or cast(subString(a.Stage,7,1) as Int) = 7 then Amount_in_USD else 0 end Commit$
		
	, case when Amount_in_USD < 0 then 'Debook'
		   when (Amount_in_USD = 0 or Amount_in_USD is null) then '$0'
		   when Amount_in_USD <= 250000 then '<=$250K'
		   when Amount_in_USD <= 1000000 then '$250K-$1M'
		   else '>$1M'
	  End Deal_Size
	  
	, CASE
		when SE_Oppt_Owner_EmployeeNumber is null then 'Empty SE Owner'
		when Assigned_SE_EmployeeNumber is null then 'Not aligned' -- no SE is assigned to the Territory, SE working on the deal is not aligned
		when charindex(SE_Oppt_Owner_EmployeeNumber, Assigned_SE_EmployeeNumber) = 0 then 'Not aligned'
		else 'Aligned'
	  end as SE_Territory_Alignment
	  
	, Case 
		when SE_Oppt_Owner_EmployeeNumber is null then 'Empty SE Owner'
		when Assigned_SE_EmployeeNumber is null then
			case
				when Temp_CoveredBy_EmployeeNumber is null then 'Missing'
				when charindex(SE_Oppt_Owner_EmployeeNumber, Temp_CoveredBy_EmployeeNumber) = 0 then 'Missing' 
				else 'Present'
			end
		when charindex (SE_Oppt_Owner_EmployeeNumber , Assigned_SE_EmployeeNumber) = 0 then
			case
				when Temp_CoveredBy_EmployeeNumber is null then 'Missing'
				when charindex(SE_Oppt_Owner_EmployeeNumber, Temp_CoveredBy_EmployeeNumber) = 0 then 'Missing' 
				else 'Present'
			end
		else 'Territory aligned'
	  end as Temp_Coverage_Split_Record
	
	  
	/***** file only have current year quota, need to check the logic, attainment calculation have issues */  
	, SE_Quota.Quota Quota
	, SE_Half_Quota.Quota SE_Half_Quota
	, SE_Annual_Quota.Quota SE_Annual_Quota
	
	, District_Quota.Quota [District Quota]
	, District_Half_Quota.Quota [District Half Quota]
	, District_Annual_Quota.Quota [District Annual Quota]
	
	/* populate empty SE_Oppt_Owner_EmployeeID with Opportunity-Sub_Division such that the deal are pulled into the user Tableau view,
     * in tableau, allow a user to see opportunity that is owned by his/her subordinate or is fall into the sub-division where he/she have access */
	, case 
		when SE_Oppt_Owner_EmployeeNumber is null then Sub_Division 
		else cast(SE_Oppt_Owner_EmployeeNumber as nvarchar(10))
	  end as SEM_Permission--SE_Oppt_Owner_EmployeeNumber_P
	  
	/* calculate the relative period */
	, case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This quarter'
			when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' quarter'
			when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' quarter'
	  end as [Relative_closeqtr]
	  
	, case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'This year'
			when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(year, [Fiscal Close Month], [Current Fiscal Month]) as varchar(2)) + ' year'
			when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, [Current Fiscal Month], [Fiscal Close Month]) as varchar(2)) + ' year'
	  end as [Relative_closeyear]
	  
	/* flag whether the Fiscal Close Period is open or closed */
	, case when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Open'
		   when datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Closed'
		   else 'Current'
	  end as [CloseQtr_State]

	, case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Closed'
		   when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Open'
		   else 
		   		case when datepart(month, [Current Fiscal Month]) > 6 and datepart(month, [Fiscal Close Month]) <= 6 then 'Closed'
		   		else 'Current'
		   		end
	  end [CloseSemi_State]

	, case when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) > 0 then 'Open'
			when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) < 0 then 'Closed'
			when datediff(year, [Current Fiscal Month], [Fiscal Close Month]) = 0 then 'Current'
	  end as [CloseYr_State]
	  

	from (
		-- append other opportunity attributes
		Select 
			  Deals.Id
			, Deals.RecordType
			, Oppt.Name Opportunity
			, Oppt.Opportunity_Account_Name__c Acct_Name
			, Oppt.[Type]
			, Oppt.Transaction_Type__c Transaction_Type
			, Oppt.CPQ_Product_Type__c [Product Type]
			, Oppt.Theater__c Theater
			, Oppt.Division__c Division
			, Oppt.Sub_Division__c Sub_Division
			
			, Oppt.StageName Stage
			, Oppt.Eval_Stage__c POC_Stage
			, case when (Eval_Stage__c is null or Eval_Stage__c in ('No POC')) then 'No POC' 
		 		   when Eval_Stage__c in ('POC Potential') then 'Potential'
		 		   when Eval_Stage__c in ('POC Installed') then 'Active'
		 		   when Eval_Stage__c in ('POC Uninstalled') then 'Yet Return'
		 		   when Eval_Stage__c in ('POC Converted to Sale','POC Give-Away') then 'Completed'
		 		   else 'Error'
		 	  end POC_Status
			
		 	, case when Oppt.LeadSource = 'Install Mining' then Oppt.LeadSource else 'Other' end as LeadSource
			/* Account Exec on an Opportunity */
			, Oppt_Owner.Name Oppt_Owner

			/* Acct Exec who is compensated from the booking */
			, Deals.Acct_Exec
			, Deals.Acct_Exec_SFDC_UserID
			, Deals.Acct_Exec_Territory_ID
			, Deals.Geo
			, Deals.Region
			, Deals.District
			, Case when (len(Deals.Acct_Exec_Territory_ID) <=18) then Deals.Acct_Exec_Territory_ID else Left(Deals.Acct_Exec_Territory_ID, 18) end as AE_District_Territory_ID

			, case when Deals.Acct_Exec_Territory_ID in
				( --FY21
				 'WW_AMS_COM_CEN_TEN_CO1', 'WW_AMS_COM_CEN_TEN_CO2', 'WW_AMS_COM_CEN_CHI_CO1', 'WW_AMS_COM_CEN_HLC_CO1',
				 'WW_AMS_COM_NEA_CPK_CO1', 'WW_AMS_COM_NEA_GTH_CO1', 'WW_AMS_COM_NEA_LIB_CO1', 'WW_AMS_COM_NEA_YAT_CO1',
				 'WW_AMS_COM_SEC_CAR_CO1', 'WW_AMS_COM_SEC_SPE_CO1', 'WW_AMS_COM_SEC_TCO_CO1', 'WW_AMS_COM_WST_BAC_CO1',
				 'WW_AMS_COM_WST_PNW_CO1', 'WW_AMS_COM_WST_RKC_CO1', 'WW_AMS_COM_WST_SWC_CO1', 'WW_AMS_COM_WST_SWC_CO2',
				 'WW_AMS_PUB_SLD_CEN_CO1', 'WW_AMS_PUB_SLD_NOE_CO1', 'WW_AMS_PUB_SLD_SOE_CO1', 'WW_AMS_PUB_SLD_WST_CO1',
				 -- FY20
				 'WW_AMS_COM_CEN_TEN_009', 'WW_AMS_COM_CEN_TEN_010', 'WW_AMS_COM_CEN_HLC_008', 'WW_AMS_COM_CEN_HLC_009', 'WW_AMS_COM_CEN_IWC_008', 'WW_AMS_COM_CEN_IWC_009',
				 'WW_AMS_COM_NEA_CPK_007', 'WW_AMS_COM_NEA_EMP_010', 'WW_AMS_COM_NEA_EMP_011', 'WW_AMS_COM_NEA_LIB_006', 'WW_AMS_COM_NEA_YAT_009', 'WW_AMS_COM_NEA_YAT_010',
				 'WW_AMS_COM_SEC_CAR_006', 'WW_AMS_COM_SEC_SPE_006', 'WW_AMS_COM_SEC_SSC_007', 'WW_AMS_COM_SEC_TCO_006', 'WW_AMS_COM_SEC_TDA_006',
				 'WW_AMS_COM_WST_BAC_009', 'WW_AMS_COM_WST_PNW_007', 'WW_AMS_COM_WST_PNW_008', 'WW_AMS_COM_WST_RKC_008', 'WW_AMS_COM_WST_RKC_009', 'WW_AMS_COM_WST_SWC_008', 'WW_AMS_COM_WST_SWC_009',
				 'WW_AMS_PUB_SLD_CEN_006', 'WW_AMS_PUB_SLD_NOE_009', 'WW_AMS_PUB_SLD_SOE_009', 'WW_AMS_PUB_SLD_SOE_010', 'WW_AMS_PUB_SLD_WST_010', 'WW_AMS_PUB_SLD_WST_011'
				 )
			then 'ISO' else 'Direct' end Direct_ISO
			
			
			/* SE Oppt Owner */
			, Deals.SE_Oppt_Owner
			, Deals.SE_Oppt_Owner_SFDC_UserId
			, Deals.SE_Oppt_Owner_EmployeeNumber
		
			/* calculate the SEs assigned to the Acct_Exec's Territory */
			, Case when Assign_SE.SE is null then '' else Assign_SE.SE end [SE assigned to Territory]
			, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeNumber	
	
			/* pull the temp coverage record if exist */	
			, #TempCov.Temp_CoveredBy_Name
			, #TempCov.Temp_CoveredBy_EmployeeNumber
	
			, convert(date, oppt.CreatedDate) CreatedDate

			, cast(Oppt.CloseDate as Date) "Close Date"
			, Deals.[Fiscal Close Month]
			, Deals.[Current Fiscal Month]
			, 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) [Close Year]
			, 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' Q' + substring(Deals.CloseDate_FiscalQuarterKey, 5,1) [Close Quarter]
			, Case when cast(substring(Deals.CloseDate_FiscalQuarterKey, 5,1) as int) <= 2 then 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' 1H'
				   else 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' 2H'
			  end [Close Semi Year]
	
			, Deals.Split
			, Deals.Currency
			, Deals.Amount
			, Cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) as Amount_in_USD
			, Oppt.Amount Oppt_Amount  -- snapshot amount is the opportunity amount
			
			, Oppt.Technical_Win_State__c [Technical Win Status]
			--, Oppt.Tech_Differentiation_Busines_Out__c
			--, Oppt.Current_Risk__c [Current Risk]
			--, Oppt.Risk_Detail__c [Risk Comment / SE Concern]
			
			, Oppt.Reason_s_for_Win_Loss__c [Reason for Win/Loss]
			, Oppt.Reasons_for_Win__c [Win Reasons]
			, Oppt.Reasons_for_Loss__c [Loss Reasons]
			
			/* pull in data from 7 days ago */
			, convert(varchar, getdate()-7, 107) Snapshot_Date
			, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
			, cast(#opptHist.Amount as decimal(15,2)) [Previous Amount]
			, #OpptHist.ForecastCategory [Previous ForecastCategory]
			, #OpptHist.StageName [Previous Stage]
			, convert(date, #OpptHist.CloseDate) [Previous CloseDate]
	  
		from (
			-- extract the rows of opportunity which are needed in the report
			
			/* Base products: FlashArray for FlashArray AE & SE, FlashBlade for FlashBlade AE & SE */
			Select Oppt.Id
			    --'Base' Comp_Category
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Acct_Exec.Name Acct_Exec
				, Acct_Exec.Territory_ID__c Acct_Exec_Territory_ID
				--, left(Acct_Exec.Territory_ID__c, 18) as Acct_Exec_District_ID
				--, AE_Coverage.Territory_ID Acct_Exec_Territory_ID
				--, left(AE_Coverage.Territory_ID, 18) as Acct_Exec_District_ID
				--, OpptSplit.Territory_ID__c Acct_Exec_Territory_ID /* Split Owner Territory Id recorded in Oppt Split */
				--, left(OpptSplit.Territory_ID__c, 18) as Acct_Exec_District_ID
				, Territory_Master.Theater Geo
				, Territory_Master.Region
				, Territory_Master.District
				
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, SE_OpptOwner.Name SE_Oppt_Owner
				, SE_OpptOwner.EmployeeNumber SE_Oppt_Owner_EmployeeNumber

				, OpptSplit.SplitPercentage Split
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation

				, RecType.Name RecordType
				--, DateFromParts( Year(DateAdd(month, 11, Oppt.CloseDate)), Month(DateAdd(month, 11, Oppt.CloseDate)), 1)  [Fiscal Close Month]
				, DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey,1,4) as int), cast(substring(CloseDate_445.FiscalMonthKey,5,2) as int), 1) [Fiscal Close Month]
				, DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey,1,4) as int), cast(substring(TodayDate_445.FiscalMonthKey,5,2) as int), 1) [Current Fiscal Month]
				, CloseDate_445.FiscalQuarterKey CloseDate_FiscalQuarterKey				
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Acct_Exec on Acct_Exec.Id = OpptSplit.SplitOwnerID
				--left join #AE_Coverage AE_Coverage on AE_Coverage.EmployeeID = Acct_Exec.EmployeeNumber
				left join [PureDW_SFDC_staging].[dbo].[User] SE_OpptOwner on SE_OpptOwner.Id = Oppt.SE_Opportunity_Owner__c
				left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
				left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
				left join [SalesOps_DM].[dbo].[TerritoryID_Master] Territory_Master on Territory_Master.Territory_ID = Acct_Exec.Territory_ID__c

			where Oppt.CloseDate >= '2020-02-03'  and Oppt.CloseDate < '2021-02-01'
			and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
			and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
			and cast(Oppt.Theater__c as nvarchar(2)) != 'Renewals'
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
			
		) Deals
		
		left join PureDW_SFDC_Staging.dbo.Opportunity Oppt on Oppt.Id = Deals.Id
		left join PureDW_SFDC_Staging.dbo.[User] Oppt_Owner on Oppt_Owner.Id = Oppt.OwnerId --AE_Oppt_Ower
		left join PureDW_SFDC_Staging.dbo.[User] SE_oppt_owner on SE_oppt_owner.Id = Deals.SE_Oppt_Owner_SFDC_UserId
		left join [SalesOps_DM].[dbo].[Coverage_assignment_byTerritory] Assign_SE on Assign_SE.Territory_ID = Deals.Acct_Exec_Territory_ID -- pull in the Territory assigned SEs
		left join #TempCov on #TempCov.OpportunityId = Oppt.Id
		left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id		
	) a
left join SalesOps_DM.dbo.SE_Org_Quota SE_Quota on (SE_Quota.EmployeeID = a.SE_Oppt_Owner_EmployeeNumber and SE_Quota.Period = substring(a.[Close Quarter], 6,2) and SE_Quota.[Year] = a.[Close Year])
left join SalesOps_DM.dbo.SE_Org_Quota SE_Half_Quota on (SE_Half_Quota.EmployeeID = a.SE_Oppt_Owner_EmployeeNumber and SE_Half_Quota.Period = substring(a.[Close Semi Year], 6, 2) and SE_Quota.Year = a.[Close Year])
left join SalesOps_DM.dbo.SE_Org_Quota SE_Annual_Quota on (SE_Annual_Quota.EmployeeID = a.SE_Oppt_Owner_EmployeeNumber and SE_Annual_Quota.Period = 'FY' and SE_Quota.Year = a.[Close Year])
left join #Geo_Qtrly_Quota District_Quota on (a.AE_District_Territory_ID = District_Quota.Territory_ID and District_Quota.Period = substring(a.[Close Quarter], 6,2) and District_Quota.[Year] = a.[Close Year])
left join #Geo_Half_Quota District_Half_Quota on (a.AE_District_Territory_ID = District_Half_Quota.Territory_ID and District_Half_Quota.Period = substring(a.[Close Quarter], 6,2) and District_Quota.[Year] = a.[Close Year])
left join #Geo_Annual_Quota District_Annual_Quota on (a.AE_District_Territory_ID = District_Annual_Quota.Territory_ID and District_Annual_Quota.Period = substring(a.[Close Quarter], 6,2) and District_Quota.[Year] = a.[Close Year])


where a.Id in ('0060z000021vldpAAA','0060z000021z6pEAAQ','0060z00001xjvTsAAI','0060z00001zjsWBAAY')
--where Sub_Division like 'ISO%'
--where a.SE_Oppt_Owner = 'Felipe Bedulli'
--where a.Id like '0060z00001xXD9SAAW%'
--'0060z000020VmEPAA0'
-- 

--where a.Id in ('0060z00001yoY1JAAU', '0060z00001yR9qbAAC') 'Arian Bexheti','Dean Brady',
--where a.SE_Oppt_Owner in ( 'Joe Mazur')