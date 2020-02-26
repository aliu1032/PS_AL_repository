
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
),

/* Geo Annual Quota */
#Geo_Annual_Quota as (
	select Territory_ID, [Period], Level, cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.Territory_Quota
	where Period = 'FY'
	),

/* Geo Half Year Quota */
#Geo_Half_Quota as (
	select Territory_ID, [Period], Level, cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.Territory_Quota
	where Period in ('1H','2H')
	),

/* Geo Half Year Quota */
#Geo_Qtrly_Quota as (
	select Territory_ID, [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region
	from SalesOps_DM.dbo.Territory_Quota
	where Period in ('Q1','Q2','Q3','Q4')
	)

/* District id for AE assigned to Geo/Region - Created District_Pemission
 * District id for Retired Territory Id
 */
-- SQL extract dataset

Select [Final].*,
	District_Quota.District District, District_Quota.Quota [District_Qtrly_Quota], District_Half_Quota.Quota [District_Half_Quota], District_Annual_Quota.Quota [District_Annual_Quota],
	Region_Quota.Region Region, Region_Quota.Quota [Region_Qtrly_Quota], Region_Half_Quota.Quota [Region_Half_Quota], Region_Half_Quota.Quota [Region_Annual_Quota],
	SuperRegion_Quota.Super_Region Super_Region, SuperRegion_Quota.Quota [SuperRegion_Qtrly_Quota], SuperRegion_Half_Quota.Quota [SuperRegion_Half_Quota], SuperRegion_Annual_Quota.Quota [SuperRegion_Annual_Quota],
	Geo_Quota.Geo Geo, Geo_Quota.Quota [Geo_Qtrly_Quota], Geo_Half_Quota.Quota [Geo_Half_Quota], Geo_Annual_Quota.Quota [Geo_Annual_Quota]
	
from (	

	select
		a.Id, a.Opportunity, a.Acct_Name, a.RecordType, a.Type, a.Transaction_Type, 
		a.[Close Date], a.[Close Quarter], a.[Close Year], a.[Half_Year], a.CreatedDate,
		a.Currency, a.Amount, a.Oppt_Amount_in_USD, a.Split, a.Amount_in_USD, a.Comp_Category, a.ForecastCategory, a.Stage,
		a.Acct_Exec, a.Acct_Exec_Territory_ID,

		/* replace the ISO Region, District Id */
		'OL_ISR' as Acct_Exec_Geo_ID,  -- make it ISO-xxx, so not to mix, double count the Theater pipe. 
		'OL_ISR_AMS' as Acct_Exec_SuperRegion_ID, -- need to update for EMEA
		'OL_ISR_AMS_AMS' as Acct_Exec_Region_ID, -- need to update with EMEA

		Case
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_CEN_TEN_009', 'WW_AMS_COM_CEN_TEN_010', 'WW_AMS_COM_CEN_HLC_008', 'WW_AMS_COM_CEN_HLC_009', 'WW_AMS_COM_CEN_IWC_008', 'WW_AMS_COM_CEN_IWC_009') then 'OL_ISR_AMS_AMS_CEN'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_NEA_CPK_007', 'WW_AMS_COM_NEA_EMP_010', 'WW_AMS_COM_NEA_EMP_011', 'WW_AMS_COM_NEA_LIB_006', 'WW_AMS_COM_NEA_YAT_009', 'WW_AMS_COM_NEA_YAT_010') then 'OL_ISR_AMS_AMS_NOE'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_SEC_CAR_006', 'WW_AMS_COM_SEC_SPE_006', 'WW_AMS_COM_SEC_SSC_007', 'WW_AMS_COM_SEC_TCO_006', 'WW_AMS_COM_SEC_TDA_006') then 'OL_ISR_AMS_AMS_SOE'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_WST_BAC_009', 'WW_AMS_COM_WST_PNW_007', 'WW_AMS_COM_WST_PNW_008', 'WW_AMS_COM_WST_RKC_008', 'WW_AMS_COM_WST_RKC_009', 'WW_AMS_COM_WST_SWC_008', 'WW_AMS_COM_WST_SWC_009') then 'OL_ISR_AMS_AMS_WST'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_PUB_SLD_CEN_006', 'WW_AMS_PUB_SLD_NOE_009', 'WW_AMS_PUB_SLD_SOE_009', 'WW_AMS_PUB_SLD_SOE_010', 'WW_AMS_PUB_SLD_WST_010', 'WW_AMS_PUB_SLD_WST_011') then 'OL_ISR_AMS_AMS_PUB'
			end as Acct_Exec_District_ID,

		Case when (Left(a.Acct_Exec_Territory_ID, 18) is null) then a.Acct_Exec_Territory_ID 
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_CEN_TEN_009', 'WW_AMS_COM_CEN_TEN_010', 'WW_AMS_COM_CEN_HLC_008', 'WW_AMS_COM_CEN_HLC_009', 'WW_AMS_COM_CEN_IWC_008', 'WW_AMS_COM_CEN_IWC_009') then 'OL_ISR_AMS_AMS_CEN'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_NEA_CPK_007', 'WW_AMS_COM_NEA_EMP_010', 'WW_AMS_COM_NEA_EMP_011', 'WW_AMS_COM_NEA_LIB_006', 'WW_AMS_COM_NEA_YAT_009', 'WW_AMS_COM_NEA_YAT_010') then 'OL_ISR_AMS_AMS_NOE'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_SEC_CAR_006', 'WW_AMS_COM_SEC_SPE_006', 'WW_AMS_COM_SEC_SSC_007', 'WW_AMS_COM_SEC_TCO_006', 'WW_AMS_COM_SEC_TDA_006') then 'OL_ISR_AMS_AMS_SOE'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_COM_WST_BAC_009', 'WW_AMS_COM_WST_PNW_007', 'WW_AMS_COM_WST_PNW_008', 'WW_AMS_COM_WST_RKC_008', 'WW_AMS_COM_WST_RKC_009', 'WW_AMS_COM_WST_SWC_008', 'WW_AMS_COM_WST_SWC_009') then 'OL_ISR_AMS_AMS_WST'
			when a.Acct_Exec_Territory_ID in ('WW_AMS_PUB_SLD_CEN_006', 'WW_AMS_PUB_SLD_NOE_009', 'WW_AMS_PUB_SLD_SOE_009', 'WW_AMS_PUB_SLD_SOE_010', 'WW_AMS_PUB_SLD_WST_010', 'WW_AMS_PUB_SLD_WST_011') then 'OL_ISR_AMS_AMS_PUB'
			else Left(a.Acct_Exec_Territory_ID, 18)
		end as District_Permission,

		Case when a.Sub_Division like '%ISO%' then 'ISO' else 'Direct' end Direct_ISO,

		a.SE_Oppt_Owner, 
		a.AE_Oppt_Owner, a.AE_Oppt_Owner_Territory_ID,
	
		case 
			when a.Stage in ('Stage 0 - Internal Lead',
					 'Stage 1 - Prequalified',
					 'Stage 2 - At Risk', 'Stage 2 - Qualified', 'Stage 2 - Qualified (RFP, unsolicited proposal, etc.)', 'Stage 2 - Quote Sent',
					 'Stage 3 - Requirements Defined',
					 'Stage 4 - POC/EVAL Engaged', 'Stage 4 - POC/EVAL Waived', 'Stage 4 - POC/EVAL Waived',
					 'Stage 5 - POC/EVAL Complete', 'Stage 5 - Negotiation/Review (Reiteration)', 'Stage 5 - Negotiations'
				 ) then 'Stage 0-5'
			when a.Stage in ('Stage 6 - Commit', 'Stage 7 - Commit (Approved Pre-build)', 'Stage 7 - Commit (Approved Pre-build - HOLD)', 'Stage 7 - Commit (Approved Pre-build - SHIP)') then 'Commit'
			when a.Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Won'
			when a.Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then 'Loss'
		end as StageGroup,

		case
			when a.Stage in ('Stage 4 - POC/EVAL Engaged', 'Stage 4 - POC/EVAL Waived', 'Stage 4 - POC/EVAL Waived',
							 'Stage 5 - POC/EVAL Complete', 'Stage 5 - Negotiation/Review (Reiteration)', 'Stage 5 - Negotiations') then a.Amount_in_USD
			when a.Stage in ('Stage 6 - Commit', 'Stage 7 - Commit (Approved Pre-build - HOLD)', 'Stage 7 - Commit (Approved Pre-build - SHIP)') then a.Amount_in_USD
			else 0
		end as [Adv. Stage$],

		case 
			when a.Stage in ('Stage 0 - Internal Lead',
							 'Stage 1 - Prequalified',
							 'Stage 2 - At Risk', 'Stage 2 - Qualified', 'Stage 2 - Qualified (RFP, unsolicited proposal, etc.)', 'Stage 2 - Quote Sent',
							 'Stage 3 - Requirements Defined',
							 'Stage 4 - POC/EVAL Engaged', 'Stage 4 - POC/EVAL Waived', 'Stage 4 - POC/EVAL Waived',
							 'Stage 5 - POC/EVAL Complete', 'Stage 5 - Negotiation/Review (Reiteration)', 'Stage 5 - Negotiations'
				 ) then a.Amount_in_USD
			when a.Stage in ('Stage 6 - Commit','Stage 7 - Commit (Approved Pre-build)', 'Stage 7 - Commit (Approved Pre-build - HOLD)', 'Stage 7 - Commit (Approved Pre-build - SHIP)') then a.Amount_in_USD
			else 0
		end as [Open$],

		case 
			when a.Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit') then a.Amount_in_USD
			else 0
			end as [Bookings],
	
		case 
			when a.Stage in ('Stage 6 - Commit', 'Stage 7 - Commit (Approved Pre-build)','Stage 7 - Commit (Approved Pre-build - HOLD)', 'Stage 7 - Commit (Approved Pre-build - SHIP)') then a.Amount_in_USD
			else 0
		end as [Commit$],

		case 
			when a.Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then a.Amount_in_USD
			else 0
			end as [Loss$]

from 
(	
			Select b1.*
			from (
			/* Base products: FlashArray for FlashArray AE & SE, FlashBlade for FlashBlade AE & SE */
			Select    Oppt.Id
				, Oppt.Name Opportunity
				, Oppt.Opportunity_Account_Name__c Acct_Name
				, RecType.Name RecordType
				, Oppt.Type
				, Oppt.Transaction_Type__c Transaction_Type

				, Oppt.Theater__c Theater
				, Oppt.Division__c Division
				, Oppt.Sub_Division__c Sub_Division

				/* Account Exec on an opportunity */
				, AE.Name AE_Oppt_Owner 
				, AE.Id AE_Oppt_Owner_SFDC_UserID
				, AE.Territory_ID__c AE_Oppt_Owner_Territory_ID
				, AE.IsActive AE_Oppt_Owner_IsActive
	
				/* Acct_Exec compensated on the Booking */
				, 'Base' Comp_Category
				, OpptSplitUr.Name Acct_Exec
				, OpptSplitUr.Territory_ID__c Acct_Exec_Territory_ID
		
				, SE_oppt_owner.Name SE_Oppt_Owner
				, SE_oppt_owner.Id SE_Oppt_Owner_SFDC_UserID
				, SE_oppt_owner.EmployeeNumber SE_Oppt_Owner_EmployeeID
				, SE_oppt_owner.IsActive SE_Oppt_Owner_ID_IsActive

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
				, case when (Oppt.Converted_Amount_USD__c is null) then 0 else Oppt.Converted_Amount_USD__c end Oppt_Amount_in_USD

				, Oppt.ForecastCategoryName ForecastCategory
				, Oppt.StageName Stage
				, cast(Oppt.CloseDate as Date) "Close Date"
				, convert(date, oppt.CreatedDate) CreatedDate
				, 'FY' + cast(cast(right(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) as int) + 1 as varchar(4)) as "Close Year"
				, left(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) "Close Quarter"
				, case when left(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) in ('Q1','Q2') then '1H' else '2H' end as Half_Year

				, convert(varchar, getdate()-7, 107) Snapshot_Date
				, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
				, cast(#OpptHist.Amount as decimal(15,2)) [Previous Amount]
				, #OpptHist.ForecastCategory [Previous ForecastCategory]
				, #OpptHist.StageName [Previous Stage]
				, convert(date, #OpptHist.CloseDate) [Previous CloseDate]

				, CASE When Oppt.ForecastCategory = #OpptHist.ForecastCategory Then 'N' Else 'Y' End ForecastCategory_changed
				, CASE When oppt.StageName = #OpptHist.StageName Then 'N' Else 'Y' END Stage_changed
				, CASE When oppt.CloseDate = #OpptHist.CloseDate Then 'N' Else 'Y' END Date_changed
				, Case 	When (oppt.Amount is null) and (#OpptHist.Amount is null) then 'N'
					   	When (oppt.Amount is null) and (#OpptHist.Amount is not null) then 'Y'
						When (oppt.Amount is not null) and (#OpptHist.Amount is null) then 'Y'
						When oppt.Amount - #OpptHist.Amount = 0 Then 'N' Else 'Y' 
				  End Amt_changed
				, Case when oppt.CreatedDate >= (getdate()-7) then 'New'
					   when (oppt.CreatedDate < (getdate()-7)) and (oppt.StageName != #OpptHist.StageName or oppt.CloseDate != #OpptHist.CloseDate) then 'Updated'
		  			   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is null) then 'Updated'
					   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is null and #OpptHist.Amount is not null) then 'Updated'
					   when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is not null and oppt.Converted_Amount_USD__c-#OpptHist.Amount != 0) then 'Updated'
					   else 'No Change'
				  end Change_Since_SnapShot

		from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
		left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
		left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
		left join [PureDW_SFDC_staging].[dbo].[User] SE_oppt_owner on SE_Opportunity_Owner__c = SE_oppt_owner.Id
		left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
		left join [PureDW_SFDC_staging].[dbo].[User] OpptSplitUr on OpptSplitUr.Id = OpptSplit.SplitOwnerId
		left join [SalesOps_DM].[dbo].[Coverage_assignment_byTerritory] Assign_SE on Assign_SE.Territory_ID = OpptSplitUr.Territory_ID__c -- pull in the Territory assigned SEs
		left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id

		left join #TempCov on #TempCov.OpportunityId = Oppt.Id
		left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id

		where Oppt.CloseDate >= '2019-02-01'  and Oppt.CloseDate < '2020-02-01'
		and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
		and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
		and cast(Oppt.Theater__c as nvarchar(2)) != 'Renewals'
		and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
		and OpptSplit.IsDeleted = 'False'
		and Oppt.Division__c like 'ISO%'
	) b1

	UNION All

	select b2.*
		from (
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

			, Oppt.Theater__c Theater
			, Oppt.Division__c Division
			, Oppt.Sub_Division__c Sub_Division

			, AE.Name AE_Oppt_Owner
			, AE.Id AE_Oppt_Owner_SFDC_UserID
			, AE.Territory_ID__c AE_Oppt_Owner_Territory_ID
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
			, FA_SE.EmployeeNumber SE_Oppt_Owner_EmployeeID
			, FA_SE.IsActive SE_Oppt_Owner_ID_IsActive

			, Case when Assign_SE.SE is null then '' else Assign_SE.SE end [SE assigned to Territory]
			, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeID
	
			, Null Temp_CoveredBy_Name
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
			, cast(Oppt.Converted_Amount_USD__c as decimal(15,2)) Amount_in_USD

			, Oppt.CurrencyIsoCode Oppt_Currency
			, cast(Oppt.Amount as decimal(15,2)) Oppt_Amount
			, case when (Oppt.Converted_Amount_USD__c is null) then 0 else Oppt.Converted_Amount_USD__c end Oppt_Amount_in_USD

			, Oppt.ForecastCategoryName ForecastCategory
			, Oppt.StageName Stage
			, cast(Oppt.CloseDate as Date) "Close Date"
			, convert(date, oppt.CreatedDate) CreatedDate
			, 'FY' + cast(cast(right(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) as int) + 1 as varchar(4)) as "Close Year"
			, left(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) "Close Quarter"
			, case when left(cast(oppt.Close_Quarter__c as nvarchar(10)), 2) in ('Q1','Q2') then '1H' else '2H' end as Half_Year
	
			, convert(varchar, getdate()-7, 107) Snapshot_Date
			, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
			, cast(#OpptHist.Amount as decimal(15,2)) [Previous Amount]
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
			, Case  when oppt.CreatedDate >= (getdate()-7) then 'New'
					when (oppt.CreatedDate < (getdate()-7)) and (oppt.StageName != #OpptHist.StageName or oppt.CloseDate != #OpptHist.CloseDate) then 'Updated'
					when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is null) then 'Updated'
			 		when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is null and #OpptHist.Amount is not null) then 'Updated'
			 		when (oppt.CreatedDate < (getdate()-7)) and (oppt.Amount is not null and #OpptHist.Amount is not null and oppt.Converted_Amount_USD__c-#OpptHist.Amount != 0) then 'Updated'
			 		else 'No Change'
	  			end Change_Since_Snapshot

			from [PureDW_SFDC_staging].[dbo].[Opportunity] Oppt
			left join [PureDW_SFDC_staging].[dbo].RecordType RecType on RecType.Id = Oppt.RecordTypeId
			left join [PureDW_SFDC_staging].[dbo].[User] AE on OwnerId = AE.Id
			left join [PureDW_SFDC_staging].[dbo].[User] SE on SE_Opportunity_Owner__c = SE.Id
			left join [PureDW_SFDC_Staging].[dbo].[User] FA_AE on FA_AE.Id = Oppt.Flash_Array_AE1__c
			left join [PureDW_SFDC_Staging].[dbo].[User] FA_SE on FA_SE.Id = Oppt.Flash_Array_SE1__c
			left join [SalesOps_DM].[dbo].[Coverage_assignment_byTerritory] Assign_SE on Assign_SE.Territory_ID = FA_AE.Territory_ID__c

			left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
			left join [PureDW_SFDC_staging].[dbo].[User] OpptSplitUr on OpptSplitUr.Id = OpptSplit.SplitOwnerId
			left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
			left join #TempCov on #TempCov.OpportunityId = Oppt.Id
			left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id

			where Oppt.CloseDate >= '2019-02-01' and Oppt.CloseDate < '2020-02-01'
			and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity')
			and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
			and cast(Oppt.Theater__c as nvarchar(10)) = 'FlashBlade'
			and (Oppt.Flash_Array_AE1__c is not Null or Oppt.Flash_Array_SE1__c is not Null)
			and Oppt.Division__c like 'ISO%'

			) b2
	) a
) [Final]
left join #Geo_Qtrly_Quota Geo_Quota on (Geo_Quota.Territory_ID = Acct_Exec_Geo_ID and Geo_Quota.Period = [Close Quarter])
left join #Geo_Half_Quota Geo_Half_Quota on (Geo_Half_Quota.Territory_ID = Acct_Exec_Geo_ID and Geo_Half_Quota.[Period] = [Half_Year])
left join #Geo_Annual_Quota Geo_Annual_Quota on (Geo_Annual_Quota.Territory_ID = Acct_Exec_Geo_ID)

left join #Geo_Qtrly_Quota SuperRegion_Quota on (SuperRegion_Quota.Territory_ID = Acct_Exec_SuperRegion_ID and SuperRegion_Quota.Period = [Close Quarter])
left join #Geo_Half_Quota SuperRegion_Half_Quota on (SuperRegion_Half_Quota.Territory_ID = Acct_Exec_SuperRegion_ID  and SuperRegion_Half_Quota.[Period] = [Half_Year])
left join #Geo_Annual_Quota SuperRegion_Annual_Quota on (SuperRegion_Annual_Quota.Territory_ID = Acct_Exec_SuperRegion_ID)

left join #Geo_Qtrly_Quota Region_Quota on (Region_Quota.Territory_ID = Acct_Exec_Region_ID and Region_Quota.Period = [Close Quarter])
left join #Geo_Half_Quota Region_Half_Quota on (Region_Half_Quota.Territory_ID = Acct_Exec_Region_ID and Region_Half_Quota.[Period] = [Half_Year])
left join #Geo_Annual_Quota Region_Annual_Quota on (Region_Annual_Quota.Territory_ID = Acct_Exec_Region_ID)

left join #Geo_Qtrly_Quota District_Quota on (District_Quota.Territory_ID = Acct_Exec_District_ID and District_Quota.Period = [Close Quarter])
left join #Geo_Half_Quota District_Half_Quota on (District_Half_Quota.Territory_ID = Acct_Exec_District_ID and District_Half_Quota.[Period] = [Half_Year])
left join #Geo_Annual_Quota District_Annual_Quota on (District_Annual_Quota.Territory_ID = Acct_Exec_District_ID)

where 
[Final].Id = '0060z00001tcgSJAAY'
--
--'0060z000020v9WfAAI'