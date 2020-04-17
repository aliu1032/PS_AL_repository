
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
/*
TempCov1 (OpportunityId, Temp_CoveredBy_Name, Temp_CoveredBy_EmployeeId, Max_rnk) as (
		select OpptId, MAX(SplitOwner), MAX(EmployeeNumber), Max(rnk)
		from Combined
		group by OpptId),
*/		
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
),

/* Geo Quota */
#Geo_M1_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota
	where Measure = 'M1_Quota'
	),
#Geo_FB_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota
	where Measure = 'FB_Quota'
	),

#Geo_Quota as (
Select #Geo_M1_Quota.[Year], #Geo_M1_Quota.Period, #Geo_M1_Quota.Half_Period, #Geo_M1_Quota.Geo, #Geo_M1_Quota.Super_Region, #Geo_M1_Quota.Region, #Geo_M1_Quota.District,
#Geo_M1_Quota.Level, #Geo_M1_Quota.Territory_ID, #Geo_M1_Quota.Quota [M1_Quota], #Geo_FB_Quota.Quota [FB_Quota]
from #Geo_M1_Quota
left join #Geo_FB_Quota on #Geo_M1_Quota.Territory_ID = #Geo_FB_Quota.Territory_ID and #Geo_M1_Quota.Period = #Geo_FB_Quota.Period
),

#Geo_Quota_Wide as (
		Select R.Territory_ID, DQ.[Year], DQ.Period, DQ.Geo, DQ.Super_Region, DQ.Region, DQ.District
					, DQ.District_Qtrly_Quota, DQ.District_Qtrly_FB_Quota, DH.District_Half_Quota, DH.District_Half_FB_Quota, DA.District_Annual_Quota, DA.District_Annual_FB_Quota
					, RQ.Region_Qtrly_Quota, RQ.Region_Qtrly_FB_Quota, RH.Region_Half_Quota, RH.Region_Half_FB_Quota, RA.Region_Annual_Quota, RA.Region_Annual_FB_Quota
					, SRQ.SuperRegion_Qtrly_Quota, SRQ.SuperRegion_Qtrly_FB_Quota, SRH.SuperRegion_Half_Quota, SRH.SuperRegion_Half_FB_Quota, SRA.SuperRegion_Annual_Quota, SRA.SuperRegion_Annual_FB_Quota
					, GQ.Geo_Qtrly_Quota, GQ.Geo_Qtrly_FB_Quota, GH.Geo_Half_Quota, GH.Geo_Half_FB_Quota, GA.Geo_Annual_Quota, GA.Geo_Annual_FB_Quota

		from (Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota where Level = 'Territory' and Period = 'FY') R
		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Super_Region, Region, District,
					      M1_Quota [District_Qtrly_Quota], FB_Quota [District_Qtrly_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('Q1','Q2','Q3','Q4'))
				   DQ on DQ.Territory_ID = substring(R.Territory_ID, 1, 18)
		left join (Select Territory_ID, Period, M1_Quota [District_Half_Quota], FB_Quota [District_Half_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('1H','2H'))
				   DH on DH.Territory_ID = substring(R.Territory_ID, 1, 18) and DH.Period = DQ.Half_Period
		left join (Select Territory_ID, M1_Quota [District_Annual_Quota], FB_Quota [District_Annual_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('FY'))
				   DA on DA.Territory_ID = substring(R.Territory_ID, 1, 18)

		left join (Select Territory_ID, Period, M1_Quota [Region_Qtrly_Quota], FB_Quota [Region_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('Q1','Q2','Q3','Q4'))
				   RQ on RQ.Territory_ID = left(R.Territory_ID, 14) and RQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Half_Quota], FB_Quota [Region_Half_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('1H','2H'))
				   RH on RH.Territory_ID = left(R.Territory_ID, 14) and RH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Annual_Quota], FB_Quota [Region_Annual_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('FY'))
				   RA on RA.Territory_ID = left(R.Territory_ID, 14)

		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Qtrly_Quota], FB_Quota [SuperRegion_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('Q1','Q2','Q3','Q4'))
				   SRQ on SRQ.Territory_ID = left(R.Territory_ID, 10) and SRQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Half_Quota], FB_Quota [SuperRegion_Half_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('1H','2H'))
				   SRH on SRH.Territory_ID = left(R.Territory_ID, 10) and SRH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Annual_Quota], FB_Quota [SuperRegion_Annual_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('FY'))
				   SRA on SRA.Territory_ID = left(R.Territory_ID, 10)

		left join (Select Territory_ID, Period, M1_Quota [Geo_Qtrly_Quota], FB_Quota [Geo_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('Q1','Q2','Q3','Q4'))
				   GQ on GQ.Territory_ID = left(R.Territory_ID, 6) and GQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Half_Quota], FB_Quota [Geo_Half_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('1H','2H'))
				   GH on GH.Territory_ID = left(R.Territory_ID, 6) and GH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Annual_Quota], FB_Quota [Geo_Annual_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('FY'))
				   GA on GA.Territory_ID = left(R.Territory_ID, 6)
),
	
	
/* SE Quota */	
#SE_M1_Quota as (
	select Name, EmployeeID, [Year], [Period], cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.SE_Org_Quota
	where Measure = 'M1'
	),
#SE_M2_Quota as (
	select Name, EmployeeID, [Year], [Period], cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.SE_Org_Quota
	where Measure = 'M2'
	),

#SE_Quota as (
	select #SE_M1_Quota.EmployeeID, #SE_M1_Quota.[Year], #SE_M1_Quota.Period, #SE_M1_Quota.Quota [SE_Quota], #SE_M2_Quota.Quota [FB_Quota]
	from #SE_M1_Quota
	left join #SE_M2_Quota on #SE_M1_Quota.EmployeeID = #SE_M2_Quota.EmployeeID and #SE_M1_Quota.Period = #SE_M2_Quota.Period
),
	
#AE_Coverage as (
		select Name, EmployeeID, Territory_ID from (
			select Name, EmployeeID, Territory_ID
			, ROW_NUMBER() over (PARTITION by EmployeeID order by Territory_ID) as [Row Number]
			from SalesOps_DM.dbo.Coverage_assignment_byName
		) a where [Row Number] = 1
)

/* District id for AE assigned to Geo/Region - Created District_Pemission
 * District id for Retired Territory Id
 */
	
-- SQL extract dataset	
	
select [Final].*

	, Geo_Quota.District
	, Geo_Quota.District_Qtrly_Quota
	, Geo_Quota.District_Half_Quota
	, Geo_Quota.District_Annual_Quota

	, Geo_Quota.District_Qtrly_FB_Quota
	, Geo_Quota.District_Half_FB_Quota
	, Geo_Quota.District_Annual_FB_Quota
	
	, Geo_Quota.Region
	, Geo_Quota.Region_Qtrly_Quota
	, Geo_Quota.Region_Half_Quota
	, Geo_Quota.Region_Annual_Quota

	, Geo_Quota.Region_Qtrly_FB_Quota
	, Geo_Quota.Region_Half_FB_Quota
	, Geo_Quota.Region_Annual_FB_Quota
	
	, Geo_Quota.Super_Region
	, Geo_Quota.SuperRegion_Qtrly_Quota
	, Geo_Quota.SuperRegion_Half_Quota
	, Geo_Quota.SuperRegion_Annual_Quota

	, Geo_Quota.SuperRegion_Qtrly_FB_Quota
	, Geo_Quota.SuperRegion_Half_FB_Quota
	, Geo_Quota.SuperRegion_Annual_FB_Quota
	
	, Geo_Quota.Geo
	, Geo_Quota.Geo_Qtrly_Quota
	, Geo_Quota.Geo_Half_Quota
	, Geo_Quota.Geo_Annual_Quota

	, Geo_Quota.Geo_Qtrly_FB_Quota
	, Geo_Quota.Geo_Half_FB_Quota
	, Geo_Quota.Geo_Annual_FB_Quota

	, SE_Quota.SE_Quota
	, SE_Half_Quota.SE_Quota SE_Half_Quota
	, SE_Annual_Quota.SE_Quota SE_Annual_Quota

	, SE_Quota.FB_Quota
	, SE_Half_Quota.FB_Quota SE_Half_FB_Quota
	, SE_Annual_Quota.FB_Quota SE_Annual_FB_Quota

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
		
	/* setup date for 7 days change summary */  
	, case -- have to tag in this sequence: Closed, New, the stage change. 
		when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then 'Won' -- Closed in last 7 days
		when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity'))
			then 'Loss, Disqualified, Undecided' -- Closed in last 7 days
		when CreatedDate >= (getdate()-7) then 'New'   -- New in the last 7 days
		when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Advanced'
		when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Setback'
		when cast(SUBSTRING(Stage, 7, 1) as Int) = cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'No change'
      end as Week_Stage_changed
      
	, case when ([Close Date] >= (getdate()-7) and cast(SUBSTRING(Stage, 7,1) as Int) = 8) then 1 else 0 end as Week_Close_Count
	, case when ([Close Date] >= (getdate()-7) and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then Amount_in_USD else 0 end as Week_Won$
	, Case when (CreatedDate >= (getdate()-7) and cast(SUBSTRING(Stage, 7,1) as Int) != 8) then 1 else 0 end as Week_New_Count  -- New this week and have not closed
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				cast(SUBSTRING(Stage, 7,1) as Int) != 8 and  -- not advanced to close
				CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Week_Advanced_Count	  
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				CreatedDate < (getdate()-7)  -- not new this week
		   then 1 else 0 end Week_Setback_Count
	
		   
from (
	
	select Deals.Id
		, Oppt.Name Opportunity
		, Oppt.Opportunity_Account_Name__c Acct_Name
		, Deals.RecordType
		, Oppt.[Type]
		, Oppt.Transaction_Type__c Transaction_Type
		
		, Oppt.Theater__c Theater
		, Oppt.Division__c Division
		, Oppt.Sub_Division__c Sub_Division
		
		, Oppt.Manufacturer__c Manufacturer
		, Oppt.Product_Type__c Product
		
		, Oppt.Technical_Win_State__c [Technical Win Status]
		, Oppt.Aggressive_Sizing__c [Agressive Sizing]
		, Oppt.Reason_s_for_Win_Loss__c [Reason for Win/Loss]
		, Oppt.Reasons_for_Win__c [Win Reasons]
		, Oppt.Reasons_for_Loss__c [Loss Reasons]
		
		, case 
			when Oppt.Competition__c like 'Cicso%' then 'Cisco'
			when Oppt.Competition__c like 'Cloud%' then 'Cloud'
			when Oppt.Competition__c like 'Dell%' then 'Dell'
			when Oppt.Competition__c like 'EMC%' then 'Dell'
			when Oppt.Competition__c like 'HDS%' then 'HDS'
			when Oppt.Competition__c like 'HPE%' then 'HPE'
			when Oppt.Competition__c like 'IBM%' then 'IBM'
			when Oppt.Competition__c like 'NetApp%' then 'NetApp'
			when Oppt.Competition__c like 'Nimble%' then 'Nimble'
			else Oppt.Competition__c
			end Competition
--		, Deals.Comp_Category
		
		/* Account Exec on an Opportunity */
		, Oppt_Owner.Name Oppt_Owner
		
		/* Acct_Exec compensated on the booking */
		, Deals.Acct_Exec
		, Deals.Acct_Exec_Territory_ID
		, case when Deals.Acct_Exec_Territory_ID in
			('WW_AMS_COM_CEN_TEN_CO1', 'WW_AMS_COM_CEN_TEN_CO2', 'WW_AMS_COM_CEN_CHI_CO1', 'WW_AMS_COM_CEN_HLC_CO1',
			 'WW_AMS_COM_NEA_CPK_CO1', 'WW_AMS_COM_NEA_GTH_CO1', 'WW_AMS_COM_NEA_LIB_CO1', 'WW_AMS_COM_NEA_YAT_CO1',
			 'WW_AMS_COM_SEC_CAR_CO1', 'WW_AMS_COM_SEC_SPE_CO1', 'WW_AMS_COM_SEC_TCO_CO1', 'WW_AMS_COM_WST_BAC_CO1',
			 'WW_AMS_COM_WST_PNW_CO1', 'WW_AMS_COM_WST_RKC_CO1', 'WW_AMS_COM_WST_SWC_CO1', 'WW_AMS_COM_WST_SWC_CO2',
			 'WW_AMS_PUB_SLD_CEN_CO1', 'WW_AMS_PUB_SLD_NOE_CO1', 'WW_AMS_PUB_SLD_SOE_CO1', 'WW_AMS_PUB_SLD_WST_CO1')
		then 'ISO' else 'Direct' end Direct_ISO
		  
		, left(Deals.Acct_Exec_District_ID, 6) as Acct_Exec_Geo_ID
		, left(Deals.Acct_Exec_District_ID, 10) as Acct_Exec_SuperRegion_ID
		, left(Deals.Acct_Exec_District_ID, 14) as Acct_Exec_Region_ID
		, Deals.Acct_Exec_District_ID
		, Case when (Left(Deals.Acct_Exec_District_ID, 18) is null) then Deals.Acct_Exec_District_ID else Left(Deals.Acct_Exec_District_ID, 18) end as District_Permission
				
		/* SE Opportunity Owner */
		, SE_Oppt_Owner.Name SE_Oppt_Owner
		, SE_Oppt_Owner.EmployeeNumber SE_Oppt_Owner_EmployeeID

		, #TempCov.Temp_CoveredBy_Name   -- pull the Temp Coverage record, to calculate whether a temp coverage record is missing
		, #TempCov.Temp_CoveredBy_EmployeeID

		, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeID
		, Assign_SE.SE [SE assigned to Territory]
		
		, case
				when SE_Oppt_Owner.EmployeeNumber is null then 'Empty SE Owner'
				when Assign_SE.SE_EmployeeID is null then 'Not aligned' -- no SE is assigned to the Territory, all SE oppt owner is temp coverage 
				when charindex (SE_Oppt_Owner.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then 'Not aligned'
				else 'Aligned'
			end as SE_Territory_Alignment

		, case
				when SE_Oppt_Owner.EmployeeNumber is null then 'Empty SE Owner'
				when Assign_SE.SE_EmployeeID is null then 
					case
						when #TempCov.Temp_CoveredBy_EmployeeID is null then 'Missing'
						when charindex(SE_Oppt_Owner.EmployeeNumber, #TempCov.Temp_CoveredBy_EmployeeID) = 0 then 'Missing'
					else 'Present'
					end
				when charindex (SE_Oppt_Owner.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then
					case
						when #TempCov.Temp_CoveredBy_EmployeeID is null then 'Missing'
						when charindex(SE_Oppt_Owner.EmployeeNumber, #TempCov.Temp_CoveredBy_EmployeeID) = 0 then 'Missing'
						else 'Present'
					end
				else 'Territory aligned'

			end as Temp_Coverage_Split_Record
		
		, P.Name Partner
		, P_SE.Name [Partner SE]
		, Oppt.Partner_SE_Engagement_Level__c
		
		, Deals.Split
		, Deals.Currency
		, Deals.Amount
		, cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) Amount_in_USD
		, Oppt.Amount Oppt_Amount
		
		/* skipped oppt original amount */
		
		, Oppt.ForecastCategoryName ForecastCategory
		, Oppt.StageName Stage

		, Oppt.Eval_Stage__c POC_Stage
			, case when (Eval_Stage__c is null or Eval_Stage__c in ('No POC')) then 'No POC' 
		 		   when Eval_Stage__c in ('POC Potential') then 'Potential'
		 		   when Eval_Stage__c in ('POC Installed') then 'Active'
		 		   when Eval_Stage__c in ('POC Uninstalled') then 'Yet Return'
		 		   when Eval_Stage__c in ('POC Converted to Sale','POC Give-Away') then 'Completed'
		 		   else 'Error'
		 	  end POC_Status
		
		, case
			when cast(substring(Oppt.StageName, 7, 1) as int) <= 3 then 'Early Stage'
			when cast(substring(Oppt.StageName, 7, 1) as int) <= 5 then 'Adv. Stage'
			when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 then 'Commit'
			when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Won'
			when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then 'Loss'
		end as StageGroup
			
		, case when Oppt.Converted_Amount_USD__c < 0 then 'Debook'
		   when Oppt.Converted_Amount_USD__c = 0 then '$0'
		   when Oppt.Converted_Amount_USD__c <= 250000 then '<=$250K'
		   when Oppt.Converted_Amount_USD__c <= 1000000 then '$250K-$1M'
		   else '>$1M'
		  end Deal_Size

		, case 
			when cast(substring(Oppt.StageName, 7, 1) as int) < 4
			then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
			else 0
		end as [Early Stage$]
		
		, case 
			when cast(substring(Oppt.StageName, 7, 1) as int) >= 4 and cast(substring(Oppt.StageName, 7, 1) as int) <= 5
			then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
			else 0
		end as [Adv. Stage$]
			
		,case 
			when cast(substring(Oppt.StageName, 7, 1) as int) >= 6 and cast(substring(Oppt.StageName, 7, 1) as int) <= 7
			then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
			else 0
		end as [Commit$]

		,case 
			when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit')
			then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
			else 0
		end as [Bookings$]

		,case 
			when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 1 else 0
		end as [Won_Count]

		,case when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then Deals.Id else '' end as [Won Deal]
		,case 
			when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
								 'Stage 8 - Closed/Lost',
								 'Stage 8 - Closed/No Decision', 
								 'Stage 8 - Closed/ Low Capacity')
			then Deals.Id else '' end as [Loss Deal]
			
		,case 
			when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
							 'Stage 8 - Closed/Lost',
							 'Stage 8 - Closed/No Decision', 
							 'Stage 8 - Closed/ Low Capacity')
			then 1 else 0
		end as [Loss_Count]
				
		, convert(date, oppt.CreatedDate) CreatedDate
		, cast(Oppt.CloseDate as Date) [Close Date]
		, Deals.[Fiscal Close Month]
		, Deals.[Current Fiscal Month]
		, 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) [Close Year]
		, 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' Q' + substring(Deals.CloseDate_FiscalQuarterKey, 5,1) [Close Quarter]
		
		, Case when cast(substring(Deals.CloseDate_FiscalQuarterKey, 5,1) as int) <= 2 then 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' 1H'
			   else 'FY' + substring(Deals.CloseDate_FiscalQuarterKey, 3,2) + ' 2H'
		  end [Close Semi Year]
		  
		, convert(varchar, getdate()-7, 107) Snapshot_Date
		, #OpptHist.CurrencyIsoCode [Pervious CurrencyCode]
		, cast(#OpptHist.Amount as decimal(15,2)) [Pervious Amount]
		, #OpptHist.ForecastCategory [Previous ForecastCategory]
		, #OpptHist.StageName [Previous Stage]
		, convert(date, #OpptHist.CloseDate) [Previous CloseDate]

		, CASE When Oppt.ForecastCategory = #OpptHist.ForecastCategory Then 'N' Else 'Y' End ForecastCategory_changed
		, CASE When oppt.StageName = #OpptHist.StageName Then 'N' Else 'Y' END Stage_changed
		, CASE When oppt.CloseDate = #OpptHist.CloseDate Then 'N' Else 'Y' END Date_changed
		, Case When (oppt.Amount is null) and (#OpptHist.Amount is null) then 'N'
			   When (oppt.Amount is null) and (#OpptHist.Amount is not null) then 'Y'
			   When (oppt.Amount is not null) and (#OpptHist.Amount is null) then 'Y'
			   When oppt.Amount - #OpptHist.Amount = 0 Then 'N' Else 'Y' 
		  End Amt_changed
		, Case when oppt.CreatedDate >= (getdate()-7) then 'New'
			   when (oppt.CreatedDate < (getdate()-7)) and (oppt.StageName != #OpptHist.StageName or oppt.CloseDate != #OpptHist.CloseDate) then 'Updated'
			   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is null) then 'Updated'
			   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is null and #OpptHist.Amount is not null) then 'Updated'
			   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is not null and oppt.Amount-#OpptHist.Amount != 0) then 'Updated'
			   else 'No Change'
		  end Change_Since_SnapShot
				
	from (
			/* a copy of the original deals */
			Select Oppt.Id
				--, 'Base' Comp_Category
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, Acct_Exec.Name Acct_Exec
				, Acct_Exec.Territory_ID__c Acct_Exec_Territory_ID /* Split Owner Territory Id in User Profile */
				, left(Acct_Exec.Territory_ID__c, 18) as Acct_Exec_District_ID
				--, AE_Coverage.Territory_ID Acct_Exec_Territory_ID  /* Split Owner Territory Id from Anaplan */
				--, left(AE_Coverage.Territory_ID, 18) as Acct_Exec_District_ID
				--, OpptSplit.Territory_ID__c Acct_Exec_Territory_ID /* Split Owner Territory Id recorded in Oppt Split */
				--, left(OpptSplit.Territory_ID__c, 18) as Acct_Exec_District_ID

				, OpptSplit.SplitPercentage Split
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation

				, RecType.Name RecordType
				, DateFromParts(cast(substring(CloseDate_445.FiscalMonthKey,1,4) as int), cast(substring(CloseDate_445.FiscalMonthKey,5,2) as int), 1) [Fiscal Close Month]
				, DateFromParts(cast(substring(TodayDate_445.FiscalMonthKey,1,4) as int), cast(substring(TodayDate_445.FiscalMonthKey,5,2) as int), 1) [Current Fiscal Month]
				, CloseDate_445.FiscalQuarterKey CloseDate_FiscalQuarterKey
--				, '1' as [Group]
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Acct_Exec on Acct_Exec.Id = OpptSplit.SplitOwnerID
				--left join #AE_Coverage AE_Coverage on AE_Coverage.EmployeeID = Acct_Exec.EmployeeNumber
				left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
				left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)

			where Oppt.CloseDate >= '2020-02-03'  and Oppt.CloseDate < '2021-02-01'
			and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
			and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
			and cast(Oppt.Theater__c as nvarchar(2)) != 'Renewals'
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
				
	) Deals
	left join PureDW_SFDC_Staging.dbo.Opportunity Oppt on Oppt.Id = Deals.Id
	left join PureDW_SFDC_Staging.dbo.[User] Oppt_Owner on Oppt_Owner.Id = Oppt.OwnerId
	left join PureDW_SFDC_Staging.dbo.[User] Acct_Exec on Acct_Exec.Id = Deals.Acct_Exec_SFDC_UserID
	left join PureDW_SFDC_Staging.dbo.[User] SE_Oppt_Owner on SE_Oppt_Owner.Id = Deals.SE_Oppt_Owner_SFDC_UserID		
	left join PureDW_SFDC_STaging.dbo.Account P on P.Id = Oppt.Partner_Account__c
	left join PureDW_SFDC_Staging.dbo.[Contact] P_SE on P_SE.Id = Oppt.Partner_SE__c

	left join SalesOps_DM.dbo.Coverage_assignment_byTerritory Assign_SE on Assign_SE.Territory_ID = Acct_Exec.Territory_ID__c
	
	left join #TempCov on #TempCov.OpportunityId = Oppt.Id
	left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id
	
) [Final]	

left join #Geo_Quota_Wide Geo_Quota on (Geo_Quota.Territory_ID = [Final].Acct_Exec_Territory_ID and Geo_Quota.Period = substring([Final].[Close Quarter], 6,2) and Geo_Quota.[Year] = [Final].[Close Year])

left join #SE_Quota SE_Quota on (SE_Quota.EmployeeID = [Final].SE_Oppt_Owner_EmployeeID and SE_Quota.Period = substring([Final].[Close Quarter], 6,2) and SE_Quota.[Year] = [Final].[Close Year])
left join #SE_Quota SE_Half_Quota on (SE_Half_Quota.EmployeeID = [Final].SE_Oppt_Owner_EmployeeID and SE_Half_Quota.Period = substring([Final].[Close Semi Year], 6,2) and SE_Half_Quota.[Year] = [Final].[Close Year])
left join #SE_Quota SE_Annual_Quota on (SE_Annual_Quota.EmployeeID = [Final].SE_Oppt_Owner_EmployeeID and SE_Annual_Quota.[Year] = [Final].[Close Year] and SE_Annual_Quota.Period = 'FY')

where Final.[Close Quarter] = 'FY21 Q3'
--where [Final].Id in ('0060z0000201jeGAAQ', '0060z0000204jEBAAY') 
--order by [Final].Id
--('0060z00001zsHt9AAE','0060z00001xkdnHAAQ','0060z00001z67qsAAA')


