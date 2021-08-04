
/* Source Territory ID Master and Quota from Anaplan_DM.dbo.[Territory Master SQL Export] table
 * Shape it into a ID + a period + a measure per row
 */	
	
	
/* Territory ID Master */
WITH

#L1 AS (
	select ID, [Territory L5] [Hierarchy]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Hierarchy' and [Time] = 'FY22' and ID != ''
),

#L2 AS (
	select ID, [Territory L5] [Theater]
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
#FY19_CFY_Territory as
(
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Territory' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'District' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Region' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Area' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Theater' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Hierarchy' and [Time] = 'FY22'

		Union

		Select Hierarchy, Theater, Area, Region, District, Territory,
			   Territory_ID [ID], Short_Description, Level, Segment, Type, [Year]
		from SalesOps_DM.dbo.Territory_Quota_FY19_21
		where Period ='FY' and Measure = 'M1_Quota'
),

/* M1 Quota */
#M1_Quota as (
	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		( 
		select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [Half_Quota], [FY22] [Annual_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([M1_Quota])
					for
					[Time] in ([Q1 FY22], [Q2 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
			) as unpvt
			
	UNION

	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		( 
		select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q3 FY22] as [Half_Quota], [FY22] [Annual_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([M1_Quota])
					for
					[Time] in ([Q3 FY22], [Q4 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
			) as unpvt

		UNION 
		
		Select [Territory_ID] [ID], [Level], [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q1], [Q2], [Q1]+[Q2] [Half_Quota], [FY] [Annual_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'M1_Quota' and Period in ('Q1','Q2','FY')
--				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q1], [Q2], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q1],[Q2])
			) unpvt
			
		UNION 
		
		Select [Territory_ID] [ID], [Level],  [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q3], [Q4], [Q3]+[Q4] [Half_Quota], [FY] [Annual_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'M1_Quota' and Period in ('Q3','Q4','FY')
--				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q3], [Q4], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q3],[Q4])
			) unpvt			
),

/* FB Quota */
#FB_Quota as (
	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_FB_Quota], [Half_FB_Quota], [Annual_FB_Quota]
	from
		( 
		select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [Half_FB_Quota], [FY22] [Annual_FB_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position FlashBlade Overlay Quota] as decimal(18,2)) [FB_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position FlashBlade Overlay Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([FB_Quota])
					for
					[Time] in ([Q1 FY22], [Q2 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
			) as unpvt
			
	UNION

	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_FB_Quota], [Half_FB_Quota], [Annual_FB_Quota]
	from
		( 
		select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q3 FY22] as [Half_FB_Quota], [FY22] [Annual_FB_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position FlashBlade Overlay Quota] as decimal(18,2)) [FB_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position FlashBlade Overlay Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([FB_Quota])
					for
					[Time] in ([Q3 FY22], [Q4 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
			) as unpvt	
		
		UNION
		
		Select [Territory_ID] [ID], [Level], [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_FB_Quota], [Half_FB_Quota], [Annual_FB_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q1], [Q2], [Q1]+[Q2] [Half_FB_Quota], [FY] [Annual_FB_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'FB_Quota' and Period in ('Q1','Q2','FY')
				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q1], [Q2], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q1],[Q2])
			) unpvt
			
		UNION 
		
		Select [Territory_ID] [ID], [Level],  [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_FB_Quota], [Half_FB_Quota], [Annual_FB_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q3], [Q4], [Q3]+[Q4] [Half_FB_Quota], [FY] [Annual_FB_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'FB_Quota' and Period in ('Q3','Q4','FY')
				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q3], [Q4], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q3],[Q4])
			) unpvt			
			
),
--Select * from #FB_Quota where ID = 'WW_AMS_COM_NEA_CPK_001' 

/* PSourced Quota */
#PSourced_Quota as (
	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_PSourced_Quota], [Half_PSourced_Quota], [Annual_PSourced_Quota]
	from
		( 
		select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [Half_PSourced_Quota], [FY22] [Annual_PSourced_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Partner Sourced Quota] as decimal(18,2)) [PSource_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Partner Sourced Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([PSource_Quota])
					for
					[Time] in ([Q1 FY22], [Q2 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
			) as unpvt
			
	UNION

	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_PSourced_Quota], [Half_PSourced_Quota], [Annual_PSourced_Quota]
	from
		( 
		select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q3 FY22] as [Half_PSourced_Quota], [FY22] [Annual_PSourced_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Partner Sourced Quota] as decimal(18,2)) [PSource_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Partner Sourced Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([PSource_Quota])
					for
					[Time] in ([Q3 FY22], [Q4 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
			) as unpvt	
)

--select ID, [Period], Qtrly_Quota District_Qtrly_Quota, Half_Quota District_Half_Quota, Annual_Quota District_Annual_Quota from #M1_Quota where [Level] = 'District' and ID = 'WW_AMS_COM_NEA_CPK'

select *
from (
		SELECT convert(varchar, getdate(), 112) Report_date,
			   cast(right(#M1_Quota.[Year],2) as int) - cast(right(Today_FD.FiscalYear,2) as int) as [Rel_Year_from_RptDate],
			   (cast(right(#M1_Quota.[Year],2) as int) * 4 + cast(right(#M1_Quota.[Period],1) as int))
			    - (cast(right(Today_FD.FiscalYear,2) as int) * 4 + cast(Today_FD.FiscalQuarter as int)) [Rel_Qtr_from_RptDate],

			   M.Hierarchy, M.Theater, M.Area, M.Region, M.District, M.Territory,
			   M.ID [Territory_ID], M.[Short_Description], M.[Level], M.[Segment], M.[Type],
			   #M1_Quota.[Year], #M1_Quota.[Period], #M1_Quota.[Qtrly_Quota], #M1_Quota.[Half_Quota], #M1_Quota.[Annual_Quota],
			   D.[District_Qtrly_Quota], D.[District_Half_Quota], D.[District_Annual_Quota],
			   R.[Region_Qtrly_Quota], R.[Region_Half_Quota], R.[Region_Annual_Quota],
			   A.[Area_Qtrly_Quota], A.[Area_Half_Quota], A.[Area_Annual_Quota],
			   T.[Theater_Qtrly_Quota], T.[Theater_Half_Quota], T.[Theater_Annual_Quota],
			   H.[Hierarchy_Qtrly_Quota], H.[Hierarchy_Half_Quota], H.[Hierarchy_Annual_Quota]
			   
		from #FY19_CFY_Territory M
		left join #M1_Quota on #M1_Quota.ID = M.ID and #M1_Quota.[Year] = M.[Year]
		left join 
			(select ID, [Year], [Period], Qtrly_Quota District_Qtrly_Quota, Half_Quota District_Half_Quota, Annual_Quota District_Annual_Quota from #M1_Quota where [Level] = 'District') D on D.Id = left(#M1_Quota.Id,18) and D.[Period] = #M1_Quota.[Period] and D.[Year] = #M1_Quota.[Year]
		left join 
			(select ID, [Year], [Period], Qtrly_Quota Region_Qtrly_Quota, Half_Quota Region_Half_Quota, Annual_Quota Region_Annual_Quota from #M1_Quota where [Level] = 'Region') R on R.Id = left(#M1_Quota.Id,14) and R.[Period] = #M1_Quota.[Period] and R.[Year] = #M1_Quota.[Year]
		left join 
			(select ID, [Year], [Period], Qtrly_Quota Area_Qtrly_Quota, Half_Quota Area_Half_Quota, Annual_Quota Area_Annual_Quota from #M1_Quota where [Level] = 'Area') A on A.Id = left(#M1_Quota.Id,10) and A.[Period] = #M1_Quota.[Period] and A.[Year] = #M1_Quota.[Year]
		left join 
			(select ID, [Year], [Period], Qtrly_Quota Theater_Qtrly_Quota, Half_Quota Theater_Half_Quota, Annual_Quota Theater_Annual_Quota from #M1_Quota where [Level] = 'Theater') T on T.Id = left(#M1_Quota.Id,6) and T.[Period] = #M1_Quota.[Period] and T.[Year] = #M1_Quota.[Year]
		left join 
			(select ID, [Year], [Period], Qtrly_Quota Hierarchy_Qtrly_Quota, Half_Quota Hierarchy_Half_Quota, Annual_Quota Hierarchy_Annual_Quota from #M1_Quota where [Level] = 'Hierarchy') H on H.Id = left(#M1_Quota.Id,2) and H.[Period] = #M1_Quota.[Period] and H.[Year] = #M1_Quota.[Year]
		left join NetSuite.dbo.DM_Date_445_With_Past Today_FD on Today_FD.Date_ID = convert(varchar, getdate(), 112)
)
a
where a.[Territory_ID] like 'WW_AMS_ENT_CEN%'
--where a.[Territory_ID] in ('WW_AMS_COM_CEN')
--where a.[Territory_ID] in ('WW_AMS_WST_CEN_CEE_001' ,'WW_AMS_COM_NEA_CPK_001')
order by [Area], [Region], [District], [Territory_ID],[Year],[Period]
