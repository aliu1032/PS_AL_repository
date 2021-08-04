--select Email [User], Name, Subordinate_EmployeeID
--from SalesOps_DM.dbo.SE_Subordinate_Permission_FY22

/***   FY17 to Current Quarter M1 Attainment, FY21 M2 Attainment, and All Attainment from Sales Comp  ******************/
WITH

#SE_Org as (
	Select Org.Name, cast(Org.EmployeeID as varchar) [EmployeeID], Org.Manager, cast(Org.[Manager ID] as varchar) [Manager_EmployeeID], Org.Role,
	   cast(Org.PositionEffectDate as date) [Position_Date], cast(Org.HireDate as date) [Hire_Date],
	   case when Org.IC_MGR = 'IC' then '1' else '0' end IC_TF, Org.[Employee Level] [Level],
	   datediff(day, Org.PositionEffectDate, getdate()) Days_of_Service,
	   Org.[Level1_Name],
	   case when Org.[Level2_Name] is NULL and Org.[Employee Level] = 1 then Org.Name else Org.[Level2_Name] end as [Level2_Name],
	   case when Org.[Level3_Name] is null and Org.[Employee Level] = 2 then Org.Name else Org.[Level3_Name] end as [Level3_Name],
  	   case when Org.[Level4_Name] is null and Org.[Employee Level] = 3 then Org.Name else Org.[Level4_Name] end as [Level4_Name],
  	   case when Org.[Level5_Name] is null and Org.[Employee Level] = 4 then Org.Name else Org.[Level5_Name] end as [Level5_Name],
  	   case when Org.[Employee Level] = 5 then Org.Name else '' end [Level6_Name],
  	   Org.Level2_Name Org_Gp
	from GPO_TSF_Dev.dbo.vSE_Org Org
),

#Today_FYDate as (
	SELECT Date_ID, FiscalMonthKey + '01' [Fiscal_Date_ID]
	from NetSuite.dbo.DM_Date_445_With_Past
	where Date_ID = convert(varchar, getdate(), 112)
),

/* from Anaplan_DM.dbo.QoQ_Historical_Performance */
#M1_Achievement as (
		select [Achievement Update Date] Report_Date, [Employee ID], '2017' FiscalYear, 'FY' Period,
				cast([FY17 Quota] as decimal(20,2)) [M1 Quota], cast([FY17 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY17 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY17 Quota] is null and [FY17 Actual] is null then 'No M1 plan'
					 when Cast([FY17 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance 
			left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
				    on FQtr_Date.FiscalYear = '2017' 
	
		Union
	
		select [Achievement Update Date] Report_Date, [Employee ID], '2018' FiscalYear, 'FY' Period,
				cast([FY18 Quota] as decimal(20,2)) [M1 Quota], cast([FY18 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY18 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY18 Quota] is null and [FY18 Actual] is null then 'No M1 plan'
					 when Cast([FY18 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
			left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
				    on FQtr_Date.FiscalYear = '2018' 
	
	-- 2019
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2019' FiscalYear, 'FY' Period,
				cast([FY19 Quota] as decimal(20,2)) [M1 Quota], cast([FY19 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY19 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY19 Quota] is null and [FY19 Actual] is null then 'No M1 plan'
					 when Cast([FY19 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
			left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
				    on FQtr_Date.FiscalYear = '2019' 
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2019' FiscalYear, 'Q1' Period,
				cast([FY19 Q1 Quota] as decimal(20,2)) [M1 Quota], cast([FY19 Q1 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY19 Q1 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY19 Q1 Quota] is null and [FY19 Q1 Actual] is null then 'No M1 plan'
					 when Cast([FY19 Q1 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2019' and FQtr_Date.FiscalQuarter = 'Q1'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2019' FiscalYear, 'Q2' Period,
				cast([FY19 Q2 Quota] as decimal(20,2)) [M1 Quota], cast([FY19 Q2 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY19 Q2 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY19 Q2 Quota] is null and [FY19 Q2 Actual] is null then 'No M1 plan'
					 when Cast([FY19 Q2 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2019' and FQtr_Date.FiscalQuarter = 'Q2'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2019' FiscalYear, 'Q3' Period,
				cast([FY19 Q3 Quota] as decimal(20,2)) [M1 Quota], cast([FY19 Q3 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY19 Q3 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY19 Q3 Quota] is null and [FY19 Q3 Actual] is null then 'No M1 plan'
					 when Cast([FY19 Q3 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2019' and FQtr_Date.FiscalQuarter = 'Q3'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2019' FiscalYear, 'Q4' Period,
				cast([FY19 Q4 Quota] as decimal(20,2)) [M1 Quota], cast([FY19 Q4 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY19 Q4 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY19 Q4 Quota] is null and [FY19 Q4 Actual] is null then 'No M1 plan'
					 when Cast([FY19 Q4 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2019' and FQtr_Date.FiscalQuarter = 'Q4'
	
	-- 2020
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2020' FiscalYear, 'FY' Period,
				cast([FY20 Quota] as decimal(20,2)) [M1 Quota], cast([FY20 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY20 Attn %], 12) as decimal(8,2)) [M1 Attainment],
				case when [FY20 Quota] is null and [FY20 Actual] is null then 'No M1 plan'
					 when Cast([FY20 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
			left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
				    on FQtr_Date.FiscalYear = '2020' 
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2020' FiscalYear, 'Q1' Period,
				cast([FY20 Q1 Quota] as decimal(20,2)) [M1 Quota], cast([FY20 Q1 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY20 Q1 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY20 Q1 Quota] is null and [FY20 Q1 Actual] is null then 'No M1 plan'
					 when Cast([FY20 Q1 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2020' and FQtr_Date.FiscalQuarter = 'Q1'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2020' FiscalYear, 'Q2' Period,
				cast([FY20 Q2 Quota] as decimal(20,2)) [M1 Quota], cast([FY20 Q2 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY20 Q2 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY20 Q2 Quota] is null and [FY20 Q2 Actual] is null then 'No M1 plan'
					 when Cast([FY20 Q2 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2020' and FQtr_Date.FiscalQuarter = 'Q2'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2020' FiscalYear, 'Q3' Period,
				cast([FY20 Q3 Quota] as decimal(20,2)) [M1 Quota], cast([FY20 Q3 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY20 Q3 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY20 Q3 Quota] is null and [FY20 Q3 Actual] is null then 'No M1 plan'
					 when Cast([FY20 Q3 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2020' and FQtr_Date.FiscalQuarter = 'Q3'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2020' FiscalYear, 'Q4' Period,
				cast([FY20 Q4 Quota] as decimal(20,2)) [M1 Quota], cast([FY20 Q4 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY20 Q4 Attn %],12) as decimal(8,2)) [M1 Attainment],
					 case when [FY20 Q4 Quota] is null and [FY20 Q4 Actual] is null then 'No M1 plan'
					 when Cast([FY20 Q4 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2020' and FQtr_Date.FiscalQuarter = 'Q4'
	
	-- 2021
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'FY' Period,
				cast([FY21 Quota] as decimal(20,2)) [M1 Quota], cast([FY21 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY21 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY21 Quota] is null and [FY21 Actual] is null then 'No M1 plan'
					 when Cast([FY21 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
			left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
				    on FQtr_Date.FiscalYear = '2021' 
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q1' Period,
				cast([FY21 Q1 Quota] as decimal(20,2)) [M1 Quota], cast([FY21 Q1 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY21 Q1 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY21 Q1 Quota] is null and [FY21 Q1 Actual] is null then 'No M1 plan'
					 when Cast([FY21 Q1 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q1'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q2' Period,
				cast([FY21 Q2 Quota] as decimal(20,2)) [M1 Quota], cast([FY21 Q2 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY21 Q2 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY21 Q2 Quota] is null and [FY21 Q2 Actual] is null then 'No M1 plan'
					 when Cast([FY21 Q2 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q2'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q3' Period,
				cast([FY21 Q3 Quota] as decimal(20,2)) [M1 Quota], cast([FY21 Q3 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY21 Q3 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY21 Q3 Quota] is null and [FY21 Q3 Actual] is null then 'No M1 plan'
					 when Cast([FY21 Q3 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q3'
	
		Union
		select [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q4' Period,
				cast([FY21 Q4 Quota] as decimal(20,2)) [M1 Quota], cast([FY21 Q4 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY21 Q4 Attn %],12) as decimal(8,2)) [M1 Attainment],
				case when [FY21 Q4 Quota] is null and [FY21 Q4 Actual] is null then 'No M1 plan'
					 when Cast([FY21 Q4 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
					 else 'M1 QBH'
				end M1_CompPlan_Flag,
				FQtr_date.[FY_Date]
		from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
				   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q4'

-- 2022
	Union
	select [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'FY' Period,
			cast([FY22 Quota] as decimal(20,2)) [M1 Quota], cast([FY22 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY22 Attn %],12) as decimal(8,2)) [M1 Attainment],
			case when [FY22 Quota] is null and [FY22 Actual] is null then 'No M1 plan'
				 when Cast([FY22 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
				 else 'M1 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
			    on FQtr_Date.FiscalYear = '2022' 

	Union
	select [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q1' Period,
			cast([FY22 Q1 Quota] as decimal(20,2)) [M1 Quota], cast([FY22 Q1 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY22 Q1 Attn %],12) as decimal(8,2)) [M1 Attainment],
			case when [FY22 Q1 Quota] is null and [FY22 Q1 Actual] is null then 'No M1 plan'
				 when Cast([FY22 Q1 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
				 else 'M1 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q1'

	Union
	select [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q2' Period,
			cast([FY22 Q2 Quota] as decimal(20,2)) [M1 Quota], cast([FY22 Q2 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY22 Q2 Attn %],12) as decimal(8,2)) [M1 Attainment],
			case when [FY22 Q2 Quota] is null and [FY22 Q2 Actual] is null then 'No M1 plan'
				 when Cast([FY22 Q2 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
				 else 'M1 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q2'

	Union
	select [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q3' Period,
			cast([FY22 Q3 Quota] as decimal(20,2)) [M1 Quota], cast([FY22 Q3 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY22 Q3 Attn %],12) as decimal(8,2)) [M1 Attainment],
			case when [FY22 Q3 Quota] is null and [FY22 Q3 Actual] is null then 'No M1 plan'
				 when Cast([FY22 Q3 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
				 else 'M1 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q3'

	Union
	select [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q4' Period,
			cast([FY22 Q4 Quota] as decimal(20,2)) [M1 Quota], cast([FY22 Q4 Actual] as decimal(20,2)) [M1 Achievement], cast(left([FY22 Q4 Attn %],12) as decimal(8,2)) [M1 Attainment],
			case when [FY22 Q4 Quota] is null and [FY22 Q4 Actual] is null then 'No M1 plan'
				 when Cast([FY22 Q4 Quota] as decimal(20,2)) = 0 then '$0 M1 Quota'
				 else 'M1 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q4'
),

/* from Anaplan_DM.dbo.QoQ_Historical_Performance */
#M2_Achievement as (
--2021
	select  [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'FY' Period,
			cast([FY21 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY21 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY21 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY21 M2 Quota] is null and [FY21 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY21 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M2_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
			    on FQtr_Date.FiscalYear = '2021' 

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q1' Period,
			cast([FY21 Q1 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY21 Q1 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY21 Q1 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY21 Q1 M2 Quota] is null and [FY21 Q1 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY21 Q1 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M2_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q1'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q2' Period,
			cast([FY21 Q2 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY21 Q2 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY21 Q2 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY21 Q2 M2 Quota] is null and [FY21 Q2 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY21 Q2 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M2_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q2'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q3' Period,
			cast([FY21 Q3 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY21 Q3 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY21 Q3 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY21 Q3 M2 Quota] is null and [FY21 Q3 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY21 Q3 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M2_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q3'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2021' FiscalYear, 'Q4' Period,
			cast([FY21 Q4 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY21 Q4 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY21 Q4 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY21 Q4 M2 Quota] is null and [FY21 Q4 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY21 Q4 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M2_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2021' and FQtr_Date.FiscalQuarter = 'Q4'

--2022	
	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'FY' Period,
			cast([FY22 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY22 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY22 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY22 M2 Quota] is null and [FY22 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY22 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
			    on FQtr_Date.FiscalYear = '2022' 

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q1' Period,
			cast([FY22 Q1 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY22 Q1 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY22 Q1 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY22 Q1 M2 Quota] is null and [FY22 Q1 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY22 Q1 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q1'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q2' Period,
			cast([FY22 Q2 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY22 Q2 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY22 Q2 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY22 Q2 M2 Quota] is null and [FY22 Q2 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY22 Q2 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q2'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q3' Period,
			cast([FY22 Q3 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY22 Q3 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY22 Q3 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY22 Q3 M2 Quota] is null and [FY22 Q3 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY22 Q3 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q3'

	Union
	select  [Achievement Update Date] Report_Date, [Employee ID], '2022' FiscalYear, 'Q4' Period,
			cast([FY22 Q4 M2 Quota] as decimal(20,2)) [M2 Quota], cast([FY22 Q4 M2 Actual] as decimal(20,2)) [M2 Achievement], cast(left([FY22 Q4 M2 Attn %],12) as decimal(8,2)) [M2 Attainment],
			case when [FY22 Q4 M2 Quota] is null and [FY22 Q4 M2 Actual] is null then 'No M2 plan'
				 when Cast([FY22 Q4 M2 Quota] as decimal(20,2)) = 0 then '$0 M2 Quota'
				 else 'M2 QBH'
			end M1_CompPlan_Flag,
			FQtr_date.[FY_Date]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
	left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			   on FQtr_Date.FiscalYear = '2022' and FQtr_Date.FiscalQuarter = 'Q4'
),

/**** Achievement Wide ******/
#M1_Attainment_Wide as (
	select  [Achievement Update Date] Report_Date, [Employee ID],
			case when cast(left([FY17 Attn %],12) as decimal(8,2)) = 0 then null else cast(left([FY17 Attn %],12) as decimal(8,2)) end [2017 M1 Attainment],
			case when cast(left([FY17 Attn %],12) as decimal(8,2)) = 0 then null 
			     when cast(left([FY17 Attn %],12) as decimal(8,2)) >= 1 then 1 else 0 end [2017_Pass_M1_Attainment],

			case when cast(left([FY18 Attn %],12) as decimal(8,2)) = 0 then null else cast(left([FY18 Attn %],12) as decimal(8,2)) end [2018 M1 Attainment],
			case when cast(left([FY18 Attn %],12) as decimal(8,2)) = 0 then null 
			     when cast(left([FY18 Attn %],12) as decimal(8,2)) >= 1 then 1 else 0 end [2018_Pass_M1_Attainment],
		
			case when cast(left([FY19 Attn %],12) as decimal(8,2)) = 0 then null else cast(left([FY19 Attn %],12) as decimal(8,2)) end [2019 M1 Attainment],
			case when cast(left([FY19 Attn %],12) as decimal(8,2)) = 0 then null 
			     when cast(left([FY19 Attn %],12) as decimal(8,2)) >= 1 then 1 else 0 end [2019_Pass_M1_Attainment],
		
			case when cast(left([FY20 Attn %],12) as decimal(8,2)) = 0 then null else cast(left([FY20 Attn %],12) as decimal(8,2)) end [2020 M1 Attainment],
			case when cast(left([FY20 Attn %],12) as decimal(8,2)) = 0 then null 
			     when cast(left([FY20 Attn %],12) as decimal(8,2)) >= 1 then 1 else 0 end [2020_Pass_M1_Attainment],
		
			case when cast(left([FY21 Attn %],12) as decimal(8,2)) = 0 then null else cast(left([FY21 Attn %],12) as decimal(8,2)) end [2021 M1 Attainment],
			case when cast(left([FY21 Attn %],12) as decimal(8,2)) = 0 then null 
			     when cast(left([FY21 Attn %],12) as decimal(8,2)) >= 1 then 1 else 0 end [2021_Pass_M1_Attainment],

			cast([Current QTD Achievement] as decimal(20,2)) [CQtD Achievement],
			cast([Current Quarter Quota] as decimal(20,2)) [CQ Quota],
			cast(left([Current QTD Attainment %],12) as decimal(8,2)) [CQtD Attainment],
			
			cast([Projected Quarterly Achievement] as decimal(20,2)) [Projected Achievement],
			cast(left([Projected Quarterly Attainment %],12) as decimal(8,2)) [Projected Attainment],
			
			[YtD Achievement] = (cast([FY22 Q1 Actual] as decimal(20,2)) + cast([FY22 Q2 Actual] as decimal(20,2))
			                     + cast([FY22 Q3 Actual] as decimal(20,2)) + cast([FY22 Q4 Actual] as decimal(20,2))),
			
			case when [FY22 Quota] is null or cast([FY22 Quota] as decimal(20,2))=0 then null else
			 (cast([FY22 Q1 Actual] as decimal(20,2)) + cast([FY22 Q2 Actual] as decimal(20,2))
			   + cast([FY22 Q3 Actual] as decimal(20,2)) + cast([FY22 Q4 Actual] as decimal(20,2))) / cast([FY22 Quota] as decimal(20,2))
			 end [YtD Attainment]
	from Anaplan_DM.dbo.QoQ_Historical_Performance
)

/* Construct the report */
Select 
	   Org.Org_Gp, Org.Name, Org.EmployeeID, Org.Manager, Org.Manager_EmployeeID,
	   Org.Role, Org.Position_Date, Org.Hire_Date, Org.IC_TF,
	   Org.Level, Org.Days_of_Service,
	   Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name, Org.Level6_Name,
	   Org.FiscalYear, Org.Period, cast(Org.[FY_Date] as date) [Fiscal_Period_Date],
	   
	   datediff(YEAR, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, Org.[FY_Date])) Rel_FY,
	   datediff(Quarter, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, Org.[FY_Date])) Rel_FQ,

	   M1.[M1 Quota], M1.[M1 Achievement], M1.[M1 Attainment], M1.M1_CompPlan_Flag,
	   M2.[M2 Quota], M2.[M2 Achievement], M2.[M2 Attainment], M2.M2_CompPlan_Flag,

	   case
			when M1.[M1 Quota] is null and M2.[M2 Quota] is null then null
	   		when M1.[M1 Quota] is null and M2.[M2 Quota] is not null then M2.[M2 Quota]
	   		when M1.[M1 Quota] is not null and M2.[M2 Quota] is null then M1.[M1 Quota]
	   		else M1.[M1 Quota] + M2.[M2 Quota]
	   end as Quota,

	   case when M1.[M1 Achievement] is null and M2.[M2 Achievement] is null then null
	   		when M1.[M1 Achievement] is null and M2.[M2 Achievement] is not null then M2.[M2 Achievement]
	   		when M1.[M1 Achievement] is not null and M2.[M2 Achievement] is null then M1.[M1 Achievement]
	   		else M1.[M1 Achievement] + M2.[M2 Achievement]
   	   end as Achievement,
	   		
  	   case when M1.[M1 Quota] is null and M2.[M2 Quota] is null then null
	   		when M1.[M1 Quota] > 0 and M2.[M2 Quota] is null then M1.[M1 Achievement] / M1.[M1 Quota]
	   		when M1.[M1 Quota] is null and M2.[M2 Quota] > 0 then M2.[M2 Achievement] / M2.[M2 Quota]
	   		when M1.[M1 Quota] > 0 and M2.[M2 Quota] > 0 then (M1.[M1 Achievement] + M2.[M2 Achievement]) / (M1.[M1 Quota] + M2.[M2 Quota])
	   		else null
	   end as Attainment,
	 		
	   W.[2017 M1 Attainment], W.[2017_Pass_M1_Attainment],
	   W.[2018 M1 Attainment], W.[2018_Pass_M1_Attainment],
	   W.[2019 M1 Attainment], W.[2019_Pass_M1_Attainment],
	   W.[2020 M1 Attainment], W.[2020_Pass_M1_Attainment],
	   W.[2021 M1 Attainment], W.[2021_Pass_M1_Attainment],
	   W.[CQtD Achievement], W.[CQ Quota], W.[CQtD Attainment],
	   W.[Projected Achievement], W.[Projected Attainment],
	   W.[YtD Achievement], W.[YtD Attainment],

	   W.Report_Date [Attainment_Report_Date]
	 from (
	 		/* setup the entries for each Employee in the Org, a Archievement row of the reporting period */
	 		select * from #SE_Org cross join (Select distinct FiscalYear, Period, [FY_Date] from #M1_Achievement) a
	 	  ) Org
left join #M1_Achievement M1 on M1.[Employee ID] = Org.EmployeeID and M1.FiscalYear = Org.FiscalYear and M1.Period = Org.Period
left join #M2_Achievement M2 on M2.[Employee ID] = Org.EmployeeID and M2.FiscalYear = Org.FiscalYear and M2.Period = Org.Period
left join #M1_Attainment_Wide W on W.[Employee ID] = Org.EmployeeID
left join #Today_FYDate on #Today_FYDate.Date_ID = convert(varchar, getdate(), 112)
--left join #QtD_M1_Attainment W on W.[Employee ID] = Org.EmployeeID
--where Org.Name = 'Gregory Robinson'--'Nick DiSarro'--'Ryan Child' --

  where Org.Level3_Name = 'Michael Richardson'
   and Org.[Period] = 'FY'
