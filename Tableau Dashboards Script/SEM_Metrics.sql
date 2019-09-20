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
#TempCov (OpportunityId, Temp_CoveredBy_Name, Temp_CoveredBy_EmployeeId, Max_rnk) as (
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
)


select a.* 
	, Case 
		when cast(subString(a.Stage,7,1) as Int) <= 3 then 'Low Stage'
		when cast(subString(a.Stage,7,1) as Int) <= 7 then 'Advanced Stage'
		when a.Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Closed/Won'
		when a.Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Closed/Loss'
		else 'Unclassified'
	  end StageGroup

	, CASE When a.[Close Date] = a.[Previous CloseDate] Then 'N' Else 'Y' END CloseDate_changed

	, Case When (a.Oppt_Amount is null) and (a.[Previous Amount] is null) then 'N'
		   When (a.Oppt_Amount is null) and (a.[Previous Amount] is not null) then 'Y'
		   When (a.Oppt_Amount is not null) and (a.[Previous Amount] is null) then 'Y'
		   When a.Oppt_Amount - a.[Previous Amount] = 0 Then 'N' Else 'Y' 
	  End Amt_changed	

	, CASE When a.ForecastCategory = a.[Previous ForecastCategory] Then 'N' Else 'Y' End ForecastCategory_changed
	, CASE When a.Stage = a.[Previous Stage] Then 'N' Else 'Y' END Stage_changed

	, Case   
			 when a.CreatedDate >= (getdate()-7) then 'New'
			 when (a.CreatedDate < (getdate()-7)) and (a.Stage != a.[Previous Stage] or a.[Close Date] != a.[Previous CloseDate]) then 'Updated'
			 when (a.CreatedDate < (getdate()-7)) and (a.Amount is not null and a.[Previous Amount] is null) then 'Updated'
			 when (a.CreatedDate < (getdate()-7)) and (a.Amount is null and a.[Previous Amount] is not null) then 'Updated'
			 when (a.CreatedDate < (getdate()-7)) and (a.Amount is not null and a.[Previous Amount] is not null and a.Oppt_Amount_in_USD-a.[Previous Amount] != 0) then 'Updated'
			 else 'No Change'
	  end Change_Since_SnapShot
	  	  
	, case -- have to tag in this sequence: Closed, New, the stage change. 
		when (a.[Close Date] >= (getdate()-7) and a.Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then 'Won' -- Closed in last 7 days
		when (a.[Close Date] >= (getdate()-7) and a.Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity'))
												then 'Loss, Disqualified, Undecided' -- Closed in last 7 days
		when a.CreatedDate >= (getdate()-7) then 'New'   -- New in the last 7 days
		when cast(SUBSTRING(a.Stage, 7, 1) as Int) > cast(SUBSTRING(a.[Previous Stage], 7, 1) as Int) then 'Advanced'
		when cast(SUBSTRING(a.Stage, 7, 1) as Int) < cast(SUBSTRING(a.[Previous Stage], 7, 1) as Int) then 'Setback'
		when cast(SUBSTRING(a.Stage, 7, 1) as Int) = cast(SUBSTRING(a.[Previous Stage], 7, 1) as Int) then 'No change'
		end Stage_changed_how
	  
	, case when (a.[Close Date] >= (getdate()-7) and cast(SUBSTRING(a.Stage, 7,1) as Int) = 8) then 1 else 0 end as Closed_Count
	, Case when (a.CreatedDate >= (getdate()-7) and cast(SUBSTRING(a.Stage, 7,1) as Int) != 8) then 1 else 0 end as New_Count  -- New this week and have not closed
	, case when cast(SUBSTRING(a.Stage, 7, 1) as Int) > cast(SUBSTRING(a.[Previous Stage], 7, 1) as Int) and
				cast(SUBSTRING(a.Stage, 7,1) as Int) != 8 and  -- not advanced to close
				a.CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Stage_Advanced_Count	  
	, case when cast(SUBSTRING(a.Stage, 7, 1) as Int) < cast(SUBSTRING(a.[Previous Stage], 7, 1) as Int) and
				a.CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Stage_Setback_Count

		
	, Case when a.Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then a.Amount_in_USD else 0 end Won$
	, Case when a.Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then a.Amount_in_USD else 0 end Loss$
	, case when a.Stage in ('Stage 0 - Internal Lead',
				 'Stage 1 - Prequalified',
				 'Stage 2 - At Risk', 'Stage 2 - Qualified', 'Stage 2 - Qualified (RFP, unsolicited proposal, etc.)', 'Stage 2 - Quote Sent',
				 'Stage 3 - Requirements Defined',
				 'Stage 4 - POC/EVAL Engaged', 'Stage 4 - POC/EVAL Waived', 'Stage 4 - POC/EVAL Waived',
				 'Stage 5 - POC/EVAL Complete', 'Stage 5 - Negotiation/Review (Reiteration)', 'Stage 5 - Negotiations'
				 ) then a.Amount_in_USD
		   when a.Stage in ('Stage 6 - Commit','Stage 7 - Commit (Approved Pre-build)', 'Stage 7 - Commit (Approved Pre-build - HOLD)', 'Stage 7 - Commit (Approved Pre-build - SHIP)') then a.Amount_in_USD
	   else 0.00
	   end as [Open$]
	   
    /* populate empty SE_Oppt_Owner_EmployeeID with Opportunity-Sub_Division such that the deal are pulled into the user Tableau view,
     * in tableau, allow a user to see opportunity that is owned by his/her subordinate or is fall into the sub-division where he/she have access */
	, Case when a.SE_Oppt_Owner_EmployeeID_t is null then a.Sub_Division else cast(a.SE_Oppt_Owner_EmployeeID_t as nvarchar(10)) end as SE_Oppt_Owner_EmployeeID
	 
from (
(
Select b1.*, SE_Half_Quota.Quota [Half_Quota] from (
/* Base products: FlashArray for FlashArray AE & SE, FlashBlade for FlashBlade AE & SE */
Select    Oppt.Id
	, Oppt.Name Opportunity
	, Oppt.Opportunity_Account_Name__c Acct_Name
	, RecType.Name RecordType
	, Oppt.Type
	, Oppt.Transaction_Type__c Transaction_Type

	, 'FY' + cast(cast(right(oppt.Close_Quarter__c, 2) as int) + 1 as varchar(4)) as "Close Year"
	, left(oppt.Close_Quarter__c, 2) "Close Quarter"
	, case when left(oppt.Close_Quarter__c, 2) in ('Q1','Q2') then '1H' else '2H' end as Half_Year
	, Oppt.Theater__c Theater
	, Oppt.Division__c Division
	, Oppt.Sub_Division__c Sub_Division

	/* Account Exec on an opportunity */
	, AE.Name AE_Oppt_Owner 
	, AE.Id AE_Oppt_Owner_SFDC_UserID
	, AE.Territory_ID__c AE_Oppt_Owner_Territory_ID
	, Left(AE.Territory_ID__c, 18) as AE_District_ID
	, AE.IsActive AE_Oppt_Owner_IsActive
	
	/* Acct_Exec compensated on the Booking */
	, 'Base' Comp_Category
	, OpptSplitUr.Name Acct_Exec
	, OpptSplitUr.Territory_ID__c Acct_Exec_Territory_ID

	, SE_oppt_owner.Name SE_Oppt_Owner
	, SE_oppt_owner.Id SE_Oppt_Owner_SFDC_UserID
	, SE_oppt_owner.EmployeeNumber SE_Oppt_Owner_EmployeeID_t
	
	, SE_oppt_owner.IsActive SE_Oppt_Owner_ID_IsActive
	, cast(SE_quota.Quota as decimal(15,2)) Quota
	, cast(SE_Annual_Quota.Quota as decimal(15,2)) SE_Annual_Quota

	, Case when Assign_SE.SE is null then '' else Assign_SE.SE end [SE assigned to Territory]
	, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeID

	, #TempCov.Temp_CoveredBy_Name
	, #TempCov.Temp_CoveredBy_EmployeeID

	, case
	  when SE_oppt_owner.EmployeeNumber is null then 'Empty SE Owner'
	  when Assign_SE.SE_EmployeeID is null then 'Not aligned' -- no SE is assigned to the Territory, all SE oppt owner is temp coverage 
	  when charindex (SE_oppt_owner.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then 'Not aligned'
	  else 'Aligned'
	  end as SE_Territory_Alignment

	, case
	  when SE_oppt_owner.EmployeeNumber is null then 'Empty SE Owner'
	  when Assign_SE.SE_EmployeeID is null then 
			case
			when #TempCov.Temp_CoveredBy_EmployeeID is null then 'Missing'
			when charindex(SE_oppt_owner.EmployeeNumber, #TempCov.Temp_CoveredBy_EmployeeID) = 0 then 'Missing'
			else 'Present'
			end
	  when charindex (SE_oppt_owner.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then
			case
			when #TempCov.Temp_CoveredBy_EmployeeID is null then 'Missing'
			when charindex(SE_oppt_owner.EmployeeNumber, #TempCov.Temp_CoveredBy_EmployeeID) = 0 then 'Missing'
			else 'Present'
			end
	  else 'Territory aligned'
	  end as Temp_CoverageRecord
	, Case when oppt.Risk_Lose_Risk__c is null then '' else oppt.Risk_Lose_Risk__c end "Lose Risk"
	, Case when oppt.Push_Risk__c is null then '' else oppt.Push_Risk__c end "Push Risk"

	, OpptSplit.SplitPercentage Split
	, OpptSplit.CurrencyIsoCode Currency
	, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation
	, cast(Oppt.Converted_Amount_USD__c * OpptSplit.SplitPercentage / 100 as decimal(15,2)) Amount_in_USD

	, Oppt.CurrencyIsoCode Oppt_Currency
	, cast(Oppt.Amount as decimal(15,2)) Oppt_Amount
	, Oppt.Converted_Amount_USD__c Oppt_Amount_in_USD

	, Oppt.ForecastCategoryName ForecastCategory
	, Oppt.StageName Stage

	, cast(Oppt.CloseDate as Date) "Close Date"
	, convert(date, oppt.CreatedDate) CreatedDate

	, convert(varchar, getdate()-7, 107) Snapshot_Date
	, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
	, cast(#OpptHist.Amount as decimal(15,2)) [Previous Amount]
	, #OpptHist.ForecastCategory [Previous ForecastCategory]
	, #OpptHist.StageName [Previous Stage]
	, convert(date, #OpptHist.CloseDate) [Previous CloseDate]

from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE_oppt_owner on SE_Opportunity_Owner__c = SE_oppt_owner.Id
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
left join [PureDW_SFDC_staging].[dbo].[User] OpptSplitUr on OpptSplitUr.Id = OpptSplit.SplitOwnerId
left join [SalesOps_DM].[dbo].[Coverage_assignment_byTerritory] Assign_SE on Assign_SE.Territory_ID = OpptSplitUr.Territory_ID__c -- pull in the Territory assigned SEs
left join [SalesOps_DM].[dbo].[SE_Org_Quota] SE_Quota on (SE_Quota.EmployeeID = SE_oppt_owner.EmployeeNumber and SE_Quota.[Period] = left(oppt.Close_Quarter__c, 2))
left join (Select EmployeeID, cast(Quota as decimal(18,2)) Quota from [SalesOps_DM].[dbo].[SE_Org_Quota] where Period = 'FY') 
			SE_Annual_Quota on (SE_Annual_Quota.EmployeeID = SE_oppt_owner.EmployeeNumber) -- Need Annual Quota
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
left join #TempCov on #TempCov.OpportunityId = Oppt.Id
left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id
where Oppt.CloseDate >= '2019-02-01'  and Oppt.CloseDate < '2020-02-01'
and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
and Oppt.Theater__c != 'Renewals'
and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
and OpptSplit.IsDeleted = 'False'

) b1
left join (Select EmployeeID, [Period], cast(Quota as decimal(18,2)) Quota from [SalesOps_DM].[dbo].[SE_Org_Quota] where Period in ('1H', '2H')) SE_Half_Quota on
		  (SE_Half_Quota.EmployeeID = b1.SE_Oppt_Owner_EmployeeID_t and SE_Half_Quota.[Period] = b1.Half_Year) 
)
UNION
(
select b2.*, SE_Half_Quota2.Quota [Half_Quota] from (
/* Overlay Product: FlashBlade Opportunity for FlashArray AE & SE */


/* looking at the FlashArray AE and SE field for pipeline estimation,
   ignoring the Opportunity Split in this sql
   early stage deals, FB opportunity split is not always inserted
   FlashArray AE and SE are populated not only for Theater = FlashBlade,
   there is restriction to populate FlashArray AE for Stage 2 + and Sub Division contains FlashBlade
   No rule on FlashArray SE
*/
-- FlashBlade booking towards FlashArray AE
Select    Oppt.Id
	, Oppt.Name Opportunity
	, Oppt.Opportunity_Account_Name__c Acct_Name
	, RecType.Name RecordType
	, Oppt.Type
	, Oppt.Transaction_Type__c Transaction_Type

	, 'FY' + cast(cast(right(oppt.Close_Quarter__c, 2) as int) + 1 as varchar(4)) as "Close Year"
	, left(oppt.Close_Quarter__c, 2) "Close Quarter"
	, case when left(oppt.Close_Quarter__c, 2) in ('Q1','Q2') then '1H' else '2H' end as Half_Year
	, Oppt.Theater__c Theater
	, Oppt.Division__c Division
	, Oppt.Sub_Division__c Sub_Division

	, AE.Name AE_Oppt_Owner
	, AE.Id AE_Oppt_Owner_SFDC_UserID
	, AE.Territory_ID__c AE_Oppt_Owner_Territory_ID
	, Left(AE.Territory_ID__c, 18) as AE_District_ID
	, AE.IsActive AE_Oppt_Owner_IsActive

	/* FlashBlade booking for FlashArray Team */
	, 'Overlay' Comp_Category
--	, OpptSplitUr.Name Acct_Exec
--	, OpptSplitUr.Territory_ID__c Oppt_Split_User_Territory_ID

	, FA_AE.Name Acct_Exec
	, FA_AE.Territory_ID__c Acct_Exec_Territory_ID

	/* System Engineer on an opportunity */	
    /*
	, SE.Name SE_Oppt_Owner
	, SE.Id SE_Oppt_Owner_SFDC_UserID
	, SE.EmployeeNumber SE_Oppt_Owner_EmployeeID
	, SE.IsActive SE_Oppt_Owner_ID_IsActive
    */
	, FA_SE.Name SE_Oppt_Owner --FlashArray SE
	, FA_SE.Id SE_Oppt_Owner_SFDC_UserID
	, FA_SE.EmployeeNumber SE_Oppt_Owner_EmployeeID_t
	, FA_SE.IsActive SE_Oppt_Owner_ID_IsActive
	, cast(SE_quota.Quota as decimal(15,2)) Quota

	, cast(SE_Annual_Quota.Quota as decimal(15,2)) SE_Annual_Quota

	, Case when Assign_SE.SE is null then '' else Assign_SE.SE end [SE assigned to Territory]
	, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeID
	
	, Null Temp_CoveredBy_Name
--	, Null Temp_CoveredBy_SFDC_UserID
	, Null Temp_CoveredBy_EmployeeID

	, case
	  when FA_SE.EmployeeNumber is null then 'Empty Overlay SE Owner'
	  when Assign_SE.SE_EmployeeID is null then 'Overlay not aligned' -- no SE is assigned to the Territory, all SE oppt owner is temp coverage 
	  when charindex (FA_SE.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then 'Overlay not aligned'
	  else 'Overlay aligned'
	  end as SE_Territory_Alignment

	, 'Not check for overlay' as Temp_CoverageRecord
	  
	, Case when oppt.Risk_Lose_Risk__c is null then '' else oppt.Risk_Lose_Risk__c end "Lose Risk"
	, Case when oppt.Push_Risk__c is null then '' else oppt.Push_Risk__c end "Push Risk"

--	, OpptSplit.SplitPercentage Split
--	, OpptSplit.CurrencyIsoCode Currency
--	, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation
--	, cast(Oppt.Converted_Amount_USD__c * OpptSplit.SplitPercentage / 100 as decimal(15,2)) Amount_in_USD

	/* assume the full oppt amount for overlay product  booking */
	, 100 split
	, Oppt.CurrencyIsoCode Currency
	, Case when Oppt.Amount is null then 0.0 else cast(Oppt.Amount as decimal(15,2)) end Amount
	, cast(Oppt.Converted_Amount_USD__c as decimal(15,2)) Amount_is_USD

	, Oppt.CurrencyIsoCode Oppt_Currency
	, cast(Oppt.Amount as decimal(15,2)) Oppt_Amount
	, Oppt.Converted_Amount_USD__c Oppt_Amount_in_USD

	, Oppt.ForecastCategoryName ForecastCategory
	, Oppt.StageName Stage
	  
	, cast(Oppt.CloseDate as Date) "Close Date"
	, convert(date, oppt.CreatedDate) CreatedDate
	
	, convert(varchar, getdate()-7, 107) Snapshot_Date
	, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
	, cast(#OpptHist.Amount as decimal(15,2)) [Previous Amount]
	, #OpptHist.ForecastCategory [Previous ForecastCategory]
	, #OpptHist.StageName [Previous Stage]
	, convert(date, #OpptHist.CloseDate) [Previous CloseDate]

from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
left join [PureDW_SFDC_staging].[dbo].[User] SE on SE_Opportunity_Owner__c = SE.Id
left join [PureDW_SFDC_Staging].[dbo].[User] FA_AE on FA_AE.Id = Oppt.Flash_Array_AE1__c
left join [PureDW_SFDC_Staging].[dbo].[User] FA_SE on FA_SE.Id = Oppt.Flash_Array_SE1__c
left join [SalesOps_DM].[dbo].[Coverage_assignment_byTerritory] Assign_SE on Assign_SE.Territory_ID = FA_AE.Territory_ID__c
left join [SalesOps_DM].[dbo].[SE_Org_Quota] SE_Quota on (SE_Quota.EmployeeID = FA_SE.EmployeeNumber and SE_Quota.[Period] = left(oppt.Close_Quarter__c, 2))
left join (Select EmployeeID, cast(Quota as decimal(18,2)) Quota from [SalesOps_DM].[dbo].[SE_Org_Quota] where Period = 'FY') 
			SE_Annual_Quota on (SE_Annual_Quota.EmployeeID = FA_SE.EmployeeNumber)
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
left join [PureDW_SFDC_staging].[dbo].[User] OpptSplitUr on OpptSplitUr.Id = OpptSplit.SplitOwnerId
left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
left join #TempCov on #TempCov.OpportunityId = Oppt.Id
left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id
where Oppt.CloseDate >= '2019-02-01' and Oppt.CloseDate <= '2020-02-01'
and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity')
and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
and Oppt.Theater__c = 'FlashBlade'
and (Oppt.Flash_Array_AE1__c is not Null or Oppt.Flash_Array_SE1__c is not Null)

) b2
left join (Select EmployeeID, [Period], cast(Quota as decimal(18,2)) Quota from [SalesOps_DM].[dbo].[SE_Org_Quota] where Period in ('1H', '2H')) SE_Half_Quota2 on
		  (SE_Half_Quota2.EmployeeID = b2.SE_Oppt_Owner_EmployeeID_t and SE_Half_Quota2.[Period] = b2.Half_Year)
)
) a
--where Sub_Division like 'ISO%'
--where a.SE_Oppt_Owner = 'Felipe Bedulli'
where id like '0060z000020VgHlAAK%'

--where a.Id in ('0060z00001yoY1JAAU', '0060z00001yR9qbAAC') 'Arian Bexheti','Dean Brady',
--where a.SE_Oppt_Owner in ( 'Joe Mazur')

-- ('0060z00001wYFllAAG', '0060z00001w8RzNAAU', '0060z00001s5aTtAAI', '0060z00001ywgsbAAA', '0060z00001x9UxnAAE',


/*
select
				Oppt.Theater__c, OpptSplit.OpportunityId, OpptSplit.SplitOwnerID Overlay_SFDC_UserID, SplitOwner.Name Overlay_Name,  SplitOwner.EmployeeNumber Overlay_EmployeeID,
				OpptSplit.SplitPercentage, OpptSplit.SplitAmount,
				SplitType.MasterLabel
		   from [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit
		   left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] splitType on SplitType.Id = OpptSplit.SplitTypeId
		   left join [PureDW_SFDC_staging].[dbo].[User] SplitOwner on SplitOwner.Id = OpptSplit.SplitOwnerId
		   left join [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt on Oppt.Id = OpptSplit.OpportunityId
		   where OpptSplit.LastModifiedDate >= '2019-02-01'
		   and Oppt.Theater__c = 'FlashBlade'
		   and SplitType.MasterLabel = 'Overlay'
		   order by OpptSplit.OpportunityId
*/

