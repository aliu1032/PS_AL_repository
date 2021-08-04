 
  DROP Table SalesOps_DM.dbo.Territory_Quota_FY22_ANA
  Select OpsM.Hierarchy, OpsM.Theater, OpsM.Area, OpsM.Region, OpsM.District, OpsM.Territory, a.Territory_Id
	   , OpsM.SFDC_Theater, OpsM.SFDC_Division, OpsM.SFDC_Sub_Division, OpsM.Level
	   , a.Period, a.Quota, a.Measure, a.Year
	into SalesOps_DM.dbo.Territory_Quota_FY22_ANA
    from (
 
			 /* Quarterly & Annual M1 Quota */
  			  select 
					 Id [Territory_Id], [Position Discrete Quota] [Quota], 'M1_Quota' as Measure,
					 case when [Time] like 'Q[1-9] FY[1-9][1-9]' then left([Time],2)
					      when [Time] like 'FY[1-9][1-9]' then 'FY'
						  else 'FM' end [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like '%FY[1-9][1-9]'

			  Union

			  /* Quarterly & Annual FB Quota */
  			  select 
					 Id [Territory_Id], [Position FlashBlade Overlay Quota] [Quota], 'FB_Quota' as Measure,
					 case when [Time] like 'Q[1-9] FY[1-9][1-9]' then left([Time],2)
					      when [Time] like 'FY[1-9][1-9]' then 'FY'
						  else 'FM' end [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like '%FY[1-9][1-9]'

			  Union

			  /* 1H M1 Quota */
  			  select 
					 Id [Territory_Id],
					 sum(cast([Position Discrete Quota] as float)) over (partition by Id) [Quota]
					 , 'M1_Quota' as Measure,
					 '1H' [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like 'Q1%' or [Time] like 'Q2%'

			  Union

			  /* 1H M1 Quota */
  			  select 
					 Id [Territory_Id],
					 sum(cast([Position Discrete Quota] as float)) over (partition by Id) [Quota]
					 , 'M1_Quota' as Measure,
					 '2H' [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like 'Q3%' or [Time] like 'Q4%'

			  Union
			  /* 1H FB Quota */
  			  select 
					 Id [Territory_Id],
					 sum(cast([Position FlashBlade Overlay Quota] as float)) over (partition by Id) [Quota]
					 , 'FB_Quota' as Measure,
					 '1H' [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like 'Q1%' or [Time] like 'Q2%'

			  Union

			  /* 1H FB Quota */
  			  select 
					 Id [Territory_Id],
					 sum(cast([Position FlashBlade Overlay Quota] as float)) over (partition by Id) [Quota]
					 , 'FB_Quota' as Measure,
					 '2H' [Period],
					 right([Time],4) [Year]
			  from Anaplan_DM.dbo.[Territory Master SQL Export]
			  where [Time] like 'Q3%' or [Time] like 'Q4%'
) a
left join SalesOps_DM.dbo.TerritoryID_Master_FY22 OpsM on OpsM.Territory_ID = a.Territory_Id
where len(a.Territory_Id) > 0