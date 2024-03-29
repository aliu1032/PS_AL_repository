WITH

#SE_Org as (
		SELECT cast(Org.EmployeeID as varchar) [Employee ID], PreferredName [Preferred Name], [Manager ID], Manager [Manager Name], Title, [Role] Resource_Group
		from GPO_TSF_Dev.dbo.vSE_Org Org
),	

-- the cte tables go to init SQL

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
			where OpptSplit.LastModifiedDate >= '2021-02-01'
			and SplitType.MasterLabel in ('Temp Coverage')
--			and OpptSplit.TC_Amount__c > 0.00
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
					where 
					convert(date, CreatedDate) <= (getdate()-7) -- values as on the OpptHistory created date
					) groups
			where [Row Number] = 1
),

#L1 AS (
	select ID, [Territory L5] [Hierarchy]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Hierarchy' and [Time] = 'FY22' and ID != ''
),

#L2 AS (
	select ID, [Territory L5] [Geo]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Theater' and [Time] = 'FY22' and ID != ''
),

#L3 AS (
	select ID, [Territory L5] [Area]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Area' and [Time] = 'FY22' and ID != ''
),

#L4 AS (
	select ID, [Territory L5] [Region]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Region' and [Time] = 'FY22' and ID != ''
),

#L5 AS (
	select ID, [Territory L5] [District]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'District' and [Time] = 'FY22' and ID != ''
),

/* Union the Territory IDs */
#Territory_Master as
(
		SELECT #L1.Hierarchy, #L2.Geo, #L3.Area, #L4.Region, #L5.District, CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Territory' and [Time] = 'FY22'
),

/* Geo Quota */
#Geo_M1_Quota as (
	select ID, Right(Period_Yr, 4) [Year], left(Period_Yr,2) [Period],
		   [Level], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		(
				select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [Half_Quota], [FY22] [Annual_Quota]
				from (
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
				) as SRC
				Pivot (sum ([M1_Quota])
				for [Time] in ([Q1 FY22], [Q2 FY22], [FY22])
				) as pvt
		) as SRC2
		UNPIVOT
		([Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
		) as unpvt
			

	UNION

	select ID, Right(Period_Yr, 4) [Year], left(Period_Yr,2) [Period],
		   [Level], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		( 
			select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q3 FY22] as [Half_Quota], [FY22] [Annual_Quota]
			from (
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
			) as SRC
			Pivot (sum ([M1_Quota])
			for [Time] in ([Q3 FY22], [Q4 FY22], [FY22])
			) as pvt
		) as SRC2
		UNPIVOT
		([Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
		) as unpvt
),

#Geo_FB_Quota as (
	select ID, Right(Period_Yr, 4) [Year], left(Period_Yr,2) [Period],
		   [Level], [FB_Quota] [FB_Qtrly_Quota], [FB_Half_Quota], [FB_Annual_Quota]
	from
			(
			select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [FB_Half_Quota], [FY22] [FB_Annual_Quota]
			from 
				(
					select ID, [Level], [Time], cast([Position FlashBlade Overlay Quota] as decimal(18,2)) [FB_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position FlashBlade Overlay Quota] not like '%[A-za-z$]%'
					  and ID != ''
				) as SRC
				Pivot (sum ([FB_Quota])
				for [Time] in ([Q1 FY22], [Q2 FY22], [FY22])
				) as pvt
			) as SRC2
			UNPIVOT
				( [FB_Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
				) as unpvt
			

		UNION

			(
			select ID, Right(Period_Yr, 4) [Year], left(Period_Yr,2) [Period],
				   [Level], [FB_Quota] [FB_Qtrly_Quota], [FB_Half_Quota], [FB_Annual_Quota]
			from
			( 
				select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q4 FY22] as [FB_Half_Quota], [FY22] [FB_Annual_Quota]
				from
				(
						select ID, [Level], [Time], cast([Position FlashBlade Overlay Quota] as decimal(18,2)) [FB_Quota]
						from Anaplan_DM.dbo.[Territory Master SQL Export]
						where [Time] like '%FY22' and [Position FlashBlade Overlay Quota] not like '%[A-za-z$]%'
						  and ID != ''
				) as SRC
				Pivot (sum ([FB_Quota])
				for [Time] in ([Q3 FY22], [Q4 FY22], [FY22])
				) as pvt
			) as SRC2
			UNPIVOT
				( [FB_Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
				) as unpvt
		)
),

#Geo_Quota as (
	Select #Geo_M1_Quota.[Year], #Geo_M1_Quota.Period, TM.Geo, TM.Area, TM.Region, TM.District,
	#Geo_M1_Quota.Level, #Geo_M1_Quota.ID [Territory_ID],
	#Geo_M1_Quota.[Qtrly_Quota] [M1_Quota], #Geo_M1_Quota.[Half_Quota], #Geo_M1_Quota.[Annual_Quota],
	#Geo_FB_Quota.[FB_Qtrly_Quota] [FB_Quota], #Geo_FB_Quota.[FB_Half_Quota], #Geo_FB_Quota.[FB_Annual_Quota]
	from #Geo_M1_Quota
	left join #Geo_FB_Quota on #Geo_M1_Quota.ID = #Geo_FB_Quota.ID and #Geo_M1_Quota.Period = #Geo_FB_Quota.Period
	left join #Territory_Master TM on TM.ID = #Geo_M1_Quota.ID
),


/* Per Territory, Territory Qtr Quota, + District + Region + Theater Quota */
#Geo_Quota_Wide as (
		Select R.Territory_ID, DQ.[Year], TQ.Period, TQ.Geo, TQ.Area, TQ.Region, TQ.District
					, TQ.Terr_Qtrly_Quota, TQ.Terr_Qtrly_FB_Quota, TQ.Terr_Half_Quota, TQ.Terr_Half_FB_Quota, TQ.Terr_Annual_Quota, TQ.Terr_Annual_FB_Quota
					, DQ.District_Qtrly_Quota, DQ.District_Qtrly_FB_Quota, DQ.District_Half_Quota, DQ.District_Half_FB_Quota, DQ.District_Annual_Quota, DQ.District_Annual_FB_Quota
					, RQ.Region_Qtrly_Quota, RQ.Region_Qtrly_FB_Quota, RQ.Region_Half_Quota, RQ.Region_Half_FB_Quota, RQ.Region_Annual_Quota, RQ.Region_Annual_FB_Quota
					, SRQ.Area_Qtrly_Quota, SRQ.Area_Qtrly_FB_Quota, SRQ.Area_Half_Quota, SRQ.Area_Half_FB_Quota, SRQ.Area_Annual_Quota, SRQ.Area_Annual_FB_Quota
					, GQ.Geo_Qtrly_Quota, GQ.Geo_Qtrly_FB_Quota, GQ.Geo_Half_Quota, GQ.Geo_Half_FB_Quota, GQ.Geo_Annual_Quota, GQ.Geo_Annual_FB_Quota

		from (Select distinct(ID) [Territory_ID] from Anaplan_DM.dbo.[Territory Master SQL Export] where Level = 'Territory' and Time = 'FY22'
			 -- UNION
			 -- Select distinct(ID) [Territory_ID] from Anaplan_DM.dbo.[Territory Master SQL Export] where Level = 'District' and Time = 'FY22'
			 ) R

   		left join (Select Territory_ID, [Year], Period, Geo, Area, Region, District,
			      		  M1_Quota [Terr_Qtrly_Quota], Half_Quota [Terr_Half_Quota], Annual_Quota [Terr_Annual_Quota],
			      		  FB_Quota [Terr_Qtrly_FB_Quota], FB_Half_Quota [Terr_Half_FB_Quota], FB_Annual_Quota [Terr_Annual_FB_Quota]
			       from #Geo_Quota where Level = 'Territory'
				  ) TQ on TQ.Territory_ID = R.Territory_ID 
			 
		left join (Select Territory_ID, [Year], Period,
					      M1_Quota [District_Qtrly_Quota], Half_Quota [District_Half_Quota], Annual_Quota [District_Annual_Quota],
					      FB_Quota [District_Qtrly_FB_Quota], FB_Half_Quota [District_Half_FB_Quota], FB_Annual_Quota [District_Annual_FB_Quota]
					      from #Geo_Quota where Level = 'District' 
				   ) DQ on DQ.Territory_ID = substring(R.Territory_ID, 1, 18) and TQ.Period = DQ.Period

		left join (Select Territory_ID, Period,
						  M1_Quota [Region_Qtrly_Quota], Half_Quota [Region_Half_Quota], Annual_Quota [Region_Annual_Quota],
						  FB_Quota [Region_Qtrly_FB_Quota], FB_Half_Quota [Region_Half_FB_Quota], FB_Annual_Quota [Region_Annual_FB_Quota]
				   from #Geo_Quota where Level = 'Region'
				   ) RQ on RQ.Territory_ID = left(R.Territory_ID, 14) and RQ.Period = DQ.Period

		left join (Select Territory_ID, Period,
					      M1_Quota [Area_Qtrly_Quota], Half_Quota [Area_Half_Quota], Annual_Quota [Area_Annual_Quota],
					      FB_Quota [Area_Qtrly_FB_Quota], FB_Half_Quota [Area_Half_FB_Quota], FB_Annual_Quota [Area_Annual_FB_Quota]
				   from #Geo_Quota where Level = 'Area' 
				   ) SRQ on SRQ.Territory_ID = left(R.Territory_ID, 10) and SRQ.Period = DQ.Period

		left join (Select Territory_ID, Period, 
						  M1_Quota [Geo_Qtrly_Quota], Half_Quota [Geo_Half_Quota], Annual_Quota [Geo_Annual_Quota],
						  FB_Quota [Geo_Qtrly_FB_Quota], FB_Half_Quota [Geo_Half_FB_Quota], FB_Annual_Quota [Geo_Annual_FB_Quota]
				   from #Geo_Quota where Level = 'Theater' 
				   ) GQ on GQ.Territory_ID = left(R.Territory_ID, 6) and GQ.Period = DQ.Period
),

#SE_Anaplan_Quota as (
	select Q.*
			, Geo.District, Geo.District_Qtrly_Quota, Geo.District_Half_Quota, Geo.District_Annual_Quota
			, Geo.District_Qtrly_FB_Quota, Geo.District_Half_FB_Quota, Geo.District_Annual_FB_Quota
	
			, Geo.Region, Geo.Region_Qtrly_Quota, Geo.Region_Half_Quota, Geo.Region_Annual_Quota
			, Geo.Region_Qtrly_FB_Quota, Geo.Region_Half_FB_Quota, Geo.Region_Annual_FB_Quota
	
			, Geo.Area, Geo.Area_Qtrly_Quota, Geo.Area_Half_Quota, Geo.Area_Annual_Quota
			, Geo.Area_Qtrly_FB_Quota, Geo.Area_Half_FB_Quota, Geo.Area_Annual_FB_Quota
	
			, Geo.Geo, Geo.Geo_Qtrly_Quota, Geo.Geo_Half_Quota, Geo.Geo_Annual_Quota
			, Geo.Geo_Qtrly_FB_Quota, Geo.Geo_Half_FB_Quota, Geo.Geo_Annual_FB_Quota

	from (
			select [Employee ID] [EmployeeID], [Workday Employees E1] [SE_Name], [Manager],
				   case when CHARINDEX(',' , [Measure 1 Coverage Assignment ID]) = 0 then
							case when len([Measure 1 Coverage Assignment ID]) > 18 then left([Measure 1 Coverage Assignment ID],18) else [Measure 1 Coverage Assignment ID] end
						else 
							case when len(left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)) > 18 then 
								 left((left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)), 18) else
								 (left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1))
							end
					   end [SE_District_ID],
				   [Measure 1 Q1 Assigned Quota] SE_Quota,
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] [SE_Half_Quota],
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] + [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] as [SE_Annual_Quota],
	   
				   [Measure 2 Q1 Assigned Quota] FB_Quota,	   
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] [SE_Half_FB_Quota],
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] + [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] as [SE_Annual_FB_Quota],
				   'Q1' Period, '1H' Half_Period, 'FY22' [Year]
			from Anaplan_DM.dbo.Employee_Territory_And_Quota

			UNION

			select [Employee ID] [EmployeeID], [Workday Employees E1] [SE_Name], [Manager],
				   case when CHARINDEX(',' , [Measure 1 Coverage Assignment ID]) = 0 then
							case when len([Measure 1 Coverage Assignment ID]) > 18 then left([Measure 1 Coverage Assignment ID],18) else [Measure 1 Coverage Assignment ID] end
						else 
							case when len(left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)) > 18 then 
								 left((left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)), 18) else
								 (left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1))
							end
					   end [SE_District_ID],
				   [Measure 1 Q2 Assigned Quota] SE_Quota,
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] [SE_Half_Quota],
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] + [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] as [SE_Annual_Quota],
	   
				   [Measure 2 Q2 Assigned Quota] FB_Quota,	   
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] [SE_Half_FB_Quota],
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] + [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] as [SE_Annual_FB_Quota],
				   'Q2' Period, '1H' Half_Period, 'FY22' [Year]
			from Anaplan_DM.dbo.Employee_Territory_And_Quota

			UNION


			select [Employee ID] [EmployeeID], [Workday Employees E1] [SE_Name], [Manager],
				   case when CHARINDEX(',' , [Measure 1 Coverage Assignment ID]) = 0 then
							case when len([Measure 1 Coverage Assignment ID]) > 18 then left([Measure 1 Coverage Assignment ID],18) else [Measure 1 Coverage Assignment ID] end
						else 
							case when len(left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)) > 18 then 
								 left((left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)), 18) else
								 (left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1))
							end
					   end [SE_District_ID],
				   [Measure 1 Q3 Assigned Quota] SE_Quota,
				   [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] [SE_Half_Quota],
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] + [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] as [SE_Annual_Quota],
	   
				   [Measure 2 Q3 Assigned Quota] FB_Quota,	   
				   [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] [SE_Half_FB_Quota],
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] + [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] as [SE_Annual_FB_Quota],
				   'Q3' Period, '2H' Half_Period, 'FY22' [Year]
			from Anaplan_DM.dbo.Employee_Territory_And_Quota

			UNION

			select [Employee ID] [EmployeeID], [Workday Employees E1] [SE_Name], [Manager],
				   case when CHARINDEX(',' , [Measure 1 Coverage Assignment ID]) = 0 then
							case when len([Measure 1 Coverage Assignment ID]) > 18 then left([Measure 1 Coverage Assignment ID],18) else [Measure 1 Coverage Assignment ID] end
						else 
							case when len(left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)) > 18 then 
								 left((left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1)), 18) else
								 (left([Measure 1 Coverage Assignment ID], CHARINDEX(',',[Measure 1 Coverage Assignment ID])-1))
							end
					   end [SE_District_ID],
				   [Measure 1 Q4 Assigned Quota] SE_Quota,
				   [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] [SE_Half_Quota],
				   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] + [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] as [SE_Annual_Quota],
	   
				   [Measure 2 Q4 Assigned Quota] FB_Quota,	   
				   [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] [SE_Half_FB_Quota],
				   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] + [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] as [SE_Annual_FB_Quota],
				   'Q4' Period, '2H' Half_Period, 'FY22' [Year]
			from Anaplan_DM.dbo.Employee_Territory_And_Quota
		) Q 
		left join #Geo_Quota_Wide Geo on Geo.Territory_ID = Q.SE_District_ID+'_001' and Geo.Period = Q.Period
		where Q.EmployeeID in (Select distinct([Employee ID]) from #SE_Org) --where Resource_Group = 'SE' or Resource_Group is null)
), 
	
#AE_Coverage as (
		select Name, EmployeeID, Territory_ID from (
			select Name, EmployeeID, Territory_ID
			, ROW_NUMBER() over (PARTITION by EmployeeID order by Territory_ID) as [Row Number]
			from SalesOps_DM.dbo.Coverage_assignment_byName
		) a where [Row Number] = 1
)

	
-- SQL extract dataset	
select
	[Final].*

	/* calculate the relative period */
	, case when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) = 0 then 'This quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) as varchar(2)) + ' quarter'
	  end as [Relative_closeqtr]
	  
	, case when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) = 0 then 'This year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(year, [Fiscal Close Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) as varchar(2)) + ' year'
	  end as [Relative_closeyear]

	/* calculate the relative period */
	, case when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) = 0 then 'This quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Create Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) > 0 then 'Next ' + cast(datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) as varchar(2)) + ' quarter'
	  end as [Relative_createqtr]
	  
	, case when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) = 0 then 'This year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) < 0 then 'Last ' + cast(datediff(year, [Fiscal Create Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) > 0 then 'Next ' + cast(datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) as varchar(2)) + ' year'
	  end as [Relative_createyear]
	  
	/* setup date for 7 days change summary */  
	, case -- have to tag in this sequence: Closed, New, the stage change. 
		when ([Close Date] >= Snapshot_Date and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then 'Won' -- Closed in last 7 days
		when ([Close Date] >= Snapshot_Date and Stage in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity'))
			then 'Loss, Disqualified, Undecided' -- Closed in last 7 days
		when CreatedDate >= Snapshot_Date  then 'New'   -- New in the last 7 days cast(getdate()-7 as date)
		when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Advanced'
		when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'Setback'
		when cast(SUBSTRING(Stage, 7, 1) as Int) = cast(SUBSTRING([Previous Stage], 7, 1) as Int) then 'No change'
      end as Week_Stage_changed
      
	, case when ([Close Date] >= Snapshot_Date and cast(SUBSTRING(Stage, 7,1) as Int) = 8) then 1 else 0 end as Week_Close_Count
	, case when ([Close Date] >= Snapshot_Date and Stage in ('Stage 8 - Closed/Won','Stage 8 - Credit')) then Amount_in_USD else 0 end as Week_Won$
	, Case when (CreatedDate >= Snapshot_Date and cast(SUBSTRING(Stage, 7,1) as Int) != 8) then 1 else 0 end as Week_New_Count  -- New this week and have not closed
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) > cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				cast(SUBSTRING(Stage, 7,1) as Int) != 8 and  -- not advanced to close
				CreatedDate < Snapshot_Date  -- not new this week
		   then 1 else 0 end Week_Advanced_Count	  
	, case when cast(SUBSTRING(Stage, 7, 1) as Int) < cast(SUBSTRING([Previous Stage], 7, 1) as Int) and
				CreatedDate < Snapshot_Date  -- not new this week
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
		, Oppt.Product_Type__c
		, Case when Oppt.Manufacturer__c = 'Pure Storage' then Oppt.Product_Type__c else Oppt.Manufacturer__c end Product

		/* Account Exec on an Opportunity */
		, Oppt_Owner.Name Oppt_Owner
		
		/* Acct_Exec compensated on the booking */
		, Deals.Acct_Exec
		, Deals.Split_Territory_ID Acct_Exec_Territory_ID
		, case when Deals.Split_Territory_ID in
			('WW_AMS_COM_CEN_TEN_CO1', 'WW_AMS_COM_CEN_TEN_CO2', 'WW_AMS_COM_CEN_CHI_CO1', 'WW_AMS_COM_CEN_HLC_CO1',
			 'WW_AMS_COM_NEA_CPK_CO1', 'WW_AMS_COM_NEA_GTH_CO1', 'WW_AMS_COM_NEA_LIB_CO1', 'WW_AMS_COM_NEA_YAT_CO1',
			 'WW_AMS_COM_SEC_CAR_CO1', 'WW_AMS_COM_SEC_SPE_CO1', 'WW_AMS_COM_SEC_TCO_CO1', 'WW_AMS_COM_WST_BAC_CO1',
			 'WW_AMS_COM_WST_PNW_CO1', 'WW_AMS_COM_WST_RKC_CO1', 'WW_AMS_COM_WST_SWC_CO1', 'WW_AMS_COM_WST_SWC_CO2',
			 'WW_AMS_PUB_SLD_CEN_CO1', 'WW_AMS_PUB_SLD_NOE_CO1', 'WW_AMS_PUB_SLD_SOE_CO1', 'WW_AMS_PUB_SLD_WST_CO1')
		then 'ISO' else 'Direct' end Direct_ISO
		
---		, District_Permission = coalesce (left(Acct_Exec_Territory_ID, 18), left(SE_Quota.SE_District_ID, 18)) 
		, District_Permission = coalesce (left(Deals.Split_Territory_ID, 18), left(SE_Quota.SE_District_ID, 18)) 

		/* SE Opportunity Owner */
		, case when Deals.Acct_Exec is null then coalesce(SE_Oppt_Owner.Name, SE_Quota.SE_Name) else SE_Oppt_Owner.Name end SE_Oppt_Owner
		, case when Deals.Acct_Exec is null then coalesce(SE_Oppt_Owner.EmployeeNumber, SE_Quota.EmployeeID) else SE_Oppt_Owner.EmployeeNumber end SE_Oppt_Owner_EmployeeID

		, #TempCov.Temp_CoveredBy_Name   -- pull the Temp Coverage record, to calculate whether a temp coverage record is missing
		, #TempCov.Temp_CoveredBy_EmployeeID

--		, Assign_SE.SE_EmployeeID Assigned_SE_EmployeeID
--		, Assign_SE.SE [SE assigned to Territory]
		, Assign_SE.[SE ID] Assigned_SE_EmployeeID
		, Assign_SE.[SE Name] [SE assigned to Territory]
		
		, case
				when SE_Oppt_Owner.EmployeeNumber is null then 'Empty SE Owner'
--				when Assign_SE.SE_EmployeeID is null then 'Not aligned' -- no SE is assigned to the Territory, all SE oppt owner is temp coverage 
--				when charindex (SE_Oppt_Owner.EmployeeNumber, Assign_SE.SE_EmployeeID) = 0 then 'Not aligned'
				when Assign_SE.[SE ID] is null then 'Not aligned' -- no SE is assigned to the Territory, all SE oppt owner is temp coverage 
				when charindex (SE_Oppt_Owner.EmployeeNumber, Assign_SE.[SE ID]) = 0 then 'Not aligned'
				else 'Aligned'
			end as SE_Territory_Alignment

		, case
				when SE_Oppt_Owner.EmployeeNumber is null then 'Empty SE Owner'
--				when Assign_SE.SE_EmployeeID is null then
				when Assign_SE.[SE ID] is null then
					case
						when #TempCov.Temp_CoveredBy_EmployeeID is null then 'Missing'
						when charindex(SE_Oppt_Owner.EmployeeNumber, #TempCov.Temp_CoveredBy_EmployeeID) = 0 then 'Missing'
					else 'Present'
					end
				when charindex (SE_Oppt_Owner.EmployeeNumber, Assign_SE.[SE ID]) = 0 then
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

		, case when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 
		  then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
		  else 0 
		  end as [Open$]

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
--		, CreateDate_445.FiscalYear [Fiscal_CreateYear]
--		, CreateDate_445.FiscalQuarterName [Fiscal_CreateQuarter]
		, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
		
		, cast(Oppt.CloseDate as Date) [Close Date]
		, [Fiscal Close Month] = Coalesce(DateFromParts(cast(CloseDate_445.FiscalYear as int), cast(CloseDate_445.FiscalMonth as int), 1) ,
										  DateFromParts(cast(substring(SE_Quota.[Year],3,2) as int) + 2000, cast(substring(SE_Quota.[Period],2,1) as Int)*3-1, 1))
		, [Close Year] = COALESCE('FY' + substring(CloseDate_445.FiscalYear,3,2), SE_Quota.[Year])
		, [Close Quarter] = COALESCE('FY'+ substring(CloseDate_445.FiscalYear, 3,2) + ' ' + CloseDate_445.FiscalQuarterName, SE_Quota.[Year] + ' ' + SE_Quota.Period)
		, [Close Semi Year] = COALESCE (
									 case when cast(CloseDate_445.FiscalMonth as int) <= 6 then 'FY'+ substring(CloseDate_445.FiscalYear,3,2) + ' 1H'
									 else 'FY'+ substring(CloseDate_445.FiscalYear,3,2) + ' 2H'
									 end,
									 SE_Quota.Year + ' ' + SE_Quota.Half_Period)
									 
		, [TodayKey] = convert(varchar, getDate(), 112)
		, cast(getdate()-7 as date) Snapshot_Date

		, #OpptHist.CurrencyIsoCode [Previous CurrencyCode]
		, cast(#OpptHist.Amount as decimal(15,2)) [Previous Amount]
		, #OpptHist.ForecastCategory [Previous ForecastCategory]
		, #OpptHist.StageName [Previous Stage]
		, convert(date, #OpptHist.CloseDate) [Previous CloseDate]

		, CASE When Oppt.ForecastCategory = #OpptHist.ForecastCategory Then 'N' Else 'Y' End ForecastCategory_changed
		, CASE When oppt.StageName = #OpptHist.StageName Then 'N' Else 'Y' END Stage_changed
		, CASE When oppt.CloseDate = #OpptHist.CloseDate Then 'N' Else 'Y' END CloseDate_changed
		, Case When (oppt.Amount is null) and (#OpptHist.Amount is null) then 'N'
			   When (oppt.Amount is null) and (#OpptHist.Amount is not null) then 'Y'
			   When (oppt.Amount is not null) and (#OpptHist.Amount is null) then 'Y'
			   When oppt.Amount - #OpptHist.Amount = 0 Then 'N' Else 'Y' 
		  End Amt_changed
		, Case when oppt.CreatedDate >= cast((getdate()-7) as date) then 'New'
			   when (oppt.CreatedDate < cast((getdate()-7) as date)) and (oppt.StageName != #OpptHist.StageName or oppt.CloseDate != #OpptHist.CloseDate) then 'Updated'
			   when (oppt.CreatedDate < cast((getdate()-7) as date)) and (oppt.Amount is not null and #OpptHist.Amount is null) then 'Updated'
			   when (oppt.CreatedDate < cast((getdate()-7) as date)) and (oppt.Amount is null and #OpptHist.Amount is not null) then 'Updated'
			   when (oppt.CreatedDate < cast((getdate()-7) as date)) and (oppt.Amount is not null and #OpptHist.Amount is not null and oppt.Amount-#OpptHist.Amount != 0) then 'Updated'
			   else 'No Change'
		  end Change_Since_SnapShot
		
		  
		  /* when a Oppt is owned by someone with a district/region/theater quota, then the territory quota is not merged, and 'District', Region, Super Region, Geo values are not populated */
		/* Pull the SE Oppt Owner quota
		 * if the SE Oppt is not a SE, then the SE_Quota dataset does not have an entry
		 * then pull the territory/district/region/theater quota by the Oppt Owner Territory Id
		 * 
		 */
		, District = coalesce(AE_Quota.District, SE_Quota.District)
		, District_Qtrly_Quota = coalesce(AE_Quota.District_Qtrly_Quota, SE_Quota.District_Qtrly_Quota)
		, District_Half_Quota = coalesce(AE_Quota.District_Half_Quota, SE_Quota.District_Half_Quota)
		, District_Annual_Quota = coalesce(AE_Quota.District_Annual_Quota, SE_Quota.District_Annual_Quota)

		, District_Qtrly_FB_Quota = coalesce(AE_Quota.District_Qtrly_FB_Quota, SE_Quota.District_Qtrly_FB_Quota)
		, District_Half_FB_Quota = coalesce(AE_Quota.District_Half_FB_Quota, SE_Quota.District_Half_FB_Quota)
		, District_Annual_FB_Quota = coalesce(AE_Quota.District_Annual_FB_Quota, SE_Quota.District_Annual_FB_Quota)
	
		, Region = coalesce(AE_Quota.Region, SE_Quota.Region)
		, Region_Qtrly_Quota = coalesce(AE_Quota.Region_Qtrly_Quota, SE_Quota.Region_Qtrly_Quota)
		, Region_Half_Quota = coalesce(AE_Quota.Region_Half_Quota, SE_Quota.Region_Half_Quota)
		, Region_Annual_Quota = coalesce(AE_Quota.Region_Annual_Quota, SE_Quota.Region_Annual_Quota)

		, Region_Qtrly_FB_Quota = coalesce(AE_Quota.Region_Qtrly_FB_Quota, SE_Quota.Region_Qtrly_FB_Quota)
		, Region_Half_FB_Quota = coalesce(AE_Quota.Region_Half_FB_Quota, SE_Quota.Region_Half_FB_Quota)
		, Region_Annual_FB_Quota = coalesce(AE_Quota.Region_Annual_FB_Quota, SE_Quota.Region_Annual_FB_Quota)
	
		, Area = coalesce(AE_Quota.Area, SE_Quota.Area)
		, Area_Qtrly_Quota = coalesce(AE_Quota.Area_Qtrly_Quota, SE_Quota.Area_Qtrly_Quota)
		, Area_Half_Quota = coalesce(AE_Quota.Area_Half_Quota, SE_Quota.Area_Half_Quota)
		, Area_Annual_Quota = coalesce(AE_Quota.Area_Annual_Quota, SE_Quota.Area_Annual_Quota)

		, Area_Qtrly_FB_Quota = coalesce(AE_Quota.Area_Qtrly_FB_Quota, SE_Quota.Area_Qtrly_FB_Quota)
		, Area_Half_FB_Quota = coalesce(AE_Quota.Area_Half_FB_Quota, SE_Quota.Area_Half_FB_Quota)
		, Area_Annual_FB_Quota = coalesce(AE_Quota.Area_Annual_FB_Quota, SE_Quota.Area_Annual_FB_Quota)
	
		, Geo = coalesce(AE_Quota.Geo, SE_Quota.Geo)
		, Geo_Qtrly_Quota = coalesce(AE_Quota.Geo_Qtrly_Quota, SE_Quota.Geo_Qtrly_Quota)
		, Geo_Half_Quota = coalesce(AE_Quota.Geo_Half_Quota, SE_Quota.Geo_Half_Quota)
		, Geo_Annual_Quota = coalesce(AE_Quota.Geo_Annual_Quota, SE_Quota.Geo_Annual_Quota)

		, Geo_Qtrly_FB_Quota = coalesce(AE_Quota.Geo_Qtrly_FB_Quota, SE_Quota.Geo_Qtrly_FB_Quota)
		, Geo_Half_FB_Quota = coalesce(AE_Quota.Geo_Half_FB_Quota, SE_Quota.Geo_Half_FB_Quota)
		, Geo_Annual_FB_Quota = coalesce(AE_Quota.Geo_Half_FB_Quota, SE_Quota.Geo_Half_FB_Quota)


		, SE_Quota = coalesce(SE_Quota.SE_Quota, AE_Quota.Terr_Qtrly_Quota)
		, SE_Half_Quota = coalesce(SE_Quota.SE_Half_Quota , AE_Quota.Terr_Half_Quota)
		, SE_Annual_Quota = coalesce(SE_Quota.SE_Annual_Quota, AE_Quota.Terr_Annual_Quota)

		, FB_Quota = coalesce(SE_Quota.FB_Quota, AE_Quota.Terr_Qtrly_FB_Quota)
		, SE_Half_FB_Quota = coalesce(SE_Quota.SE_Half_FB_Quota, AE_Quota.Terr_Half_FB_Quota)
		, SE_Annual_FB_Quota = coalesce(SE_Quota.SE_Annual_FB_Quota, AE_Quota.Terr_Annual_FB_Quota)
		
	from (
			/* there is 1 row of no split opportunity, N rows of an opportunity based on the number of revenue split
			 * If need to do pool coverage calculation, then need an opportunity row for every SE covering the territory
			 * then there will be duplicate when review at the territor/district level
			 */
			/* a copy of the original deals */
			Select Oppt.Id
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, Acct_Exec.Name Acct_Exec
				--, Acct_Exec.Territory_ID__c Acct_Exec_Territory_ID /* Split Owner Territory Id in User Profile */
				--, left(Acct_Exec.Territory_ID__c, 18) as Acct_Exec_District_ID
				, case when OpptSplit.Override_Territory__c is null then OpptSplit.Territory_ID__c else OpptSplit.Override_Territory__c end Split_Territory_ID
				, case when OpptSplit.Override_Territory__c is null then left(OpptSplit.Territory_ID__c,18) else left(OpptSplit.Override_Territory__c,18) end Split_District_ID

				, OpptSplit.SplitPercentage Split
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation

				, RecType.Name RecordType
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Acct_Exec on Acct_Exec.Id = OpptSplit.SplitOwnerID
				
			where Oppt.CloseDate >= '2021-02-03' and cast(Oppt.Fiscal_Year__c as varchar) = '2022'
			and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
			--and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
			and cast(Oppt.Theater__c as nvarchar(50)) != 'Renewals'
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
	) Deals
	left join PureDW_SFDC_Staging.dbo.Opportunity Oppt on Oppt.Id = Deals.Id
	left join PureDW_SFDC_Staging.dbo.[User] Oppt_Owner on Oppt_Owner.Id = Oppt.OwnerId
	left join PureDW_SFDC_Staging.dbo.[User] Acct_Exec on Acct_Exec.Id = Deals.Acct_Exec_SFDC_UserID
	left join PureDW_SFDC_Staging.dbo.[User] SE_Oppt_Owner on SE_Oppt_Owner.Id = Deals.SE_Oppt_Owner_SFDC_UserID		
	left join PureDW_SFDC_STaging.dbo.Account P on P.Id = Oppt.Partner_Account__c
	left join PureDW_SFDC_Staging.dbo.[Contact] P_SE on P_SE.Id = Oppt.Partner_SE__c

    left join Anaplan_DM.dbo.SE_Territory_Alignment Assign_SE on Assign_SE.[Territory Code] = Deals.Split_Territory_ID
	
	left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
	left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, Oppt.CreatedDate, 112)
	left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
	
	left join #TempCov on #TempCov.OpportunityId = Oppt.Id
	left join #OpptHist on #OpptHist.OpportunityId = Oppt.Id
	left join #Geo_Quota_Wide AE_Quota on (AE_Quota.Territory_ID = Split_Territory_ID and AE_Quota.Period = CloseDate_445.FiscalQuarterName and AE_Quota.[Year] = 'FY' + substring(CloseDate_445.FiscalYear, 3,2))
	full join #SE_Anaplan_Quota SE_Quota on SE_Quota.EmployeeID = SE_Oppt_Owner.EmployeeNumber 
			  		and SE_Quota.Period = CloseDate_445.FiscalQuarterName 
			  		and SE_Quota.[Year] = 'FY' + substring(CloseDate_445.FiscalYear, 3,2)
--			  		and substring(SE_Quota.SE_District_ID,1,18) = substring(AE_Quota.Territory_ID,1,18) 
	
) [Final]
left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = [Final].TodayKey
where
--[Final].[Won_Count] = 1
--[Final].[SE_Oppt_Owner] = 'Chris Otis'
[Final].Id = '0060z000023XNuxAAG'
--= 'WW_AMS_COM_NEA_GTH'
--  and [Final].Opportunity is null
--where [Final].SE_Oppt_Owner='Mehul Patel'
--where [Final].SE_Oppt_Owner_EmployeeID = '104942'