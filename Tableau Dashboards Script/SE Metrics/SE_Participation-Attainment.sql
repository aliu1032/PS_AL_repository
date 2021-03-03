/***   FY17 to Current Quarter M1 Attainment, FY21 M2 Attainment, and All Attainment from Sales Comp  ******************/
WITH

#SE_Org as (
		/*
		select Org.Name, Org.EmployeeID, Org.Manager, Org.Manager_EmployeeID, R.Resource_Group [Role], 
		cast(Org.EffectiveDateForPosition as Date) Position_Date, cast(Org.HireDate as Date) Hire_Date,
			   Org.Node IC_TF, Org.[Level],
			   Datediff(day, Org.EffectiveDateForPosition, getDate()) Days_of_Service,
		       Org.Level1_Name,
		       Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name, Org.Level6_Name,
		       Case when Level2_Name = 'Alex McMullan' Then 'FCTO'
		       		when Level2_Name = 'Carl McQuillan' then 'International'
		       		when Level2_Name = 'Nathan Hall' then 'America'
		       		when Level2_Name = 'Scott Dedman' then 'GSI/MSP/Channel'
		       		when Level2_Name = 'Zack Murphy' then 'Data Architect'
		       		else 'GPO'
		       end Org_Gp
		from SalesOps_DM.dbo.SE_Org_Members Org
		left join SalesOps_DM.dbo.SE_User_Role R on R.EmployeeID = Org.EmployeeID
		*/

	select etl.preferredname [Name], CAST(Org.[Employee ID] AS varchar) [EmployeeID], etl.mgr [Manager], cast(etl.mgrid as varchar) [Manager_EmployeeID], R.Resource_Group [Role],
		   cast(etl.posdate as Date) [Position_Date], etl.hiredate [Hire_Date], 
		   case when map.[Is Manager] = 'Yes' then '0' else '1' end IC_TF, map.[Employee Level] [Level],
		   datediff(day, etl.posdate, getDate()) Days_of_Service,	   Org.[Level 1 Manager ] Level1_Name, 
	   case when len(Org.[Level 2 Manager ]) = 0 and map.[Employee Level] = 1 then etl.preferredname else Org.[Level 2 Manager ] end as Level2_Name,
	   case when len(Org.[Level 3 Manager ]) = 0 and map.[Employee Level] = 2 then etl.preferredname else Org.[Level 3 Manager ] end as Level3_Name,
	   case when len(Org.[Level 4 Manager ]) = 0 and map.[Employee Level] = 3 then etl.preferredname else Org.[Level 4 Manager ] end as Level4_Name,
	   case when len(Org.[Level 5 Manager ]) = 0 and map.[Employee Level] = 4 then etl.preferredname else Org.[Level 5 Manager ] end as Level5_Name,
	   case when map.[Employee Level] = 5 then etl.preferredname else '' end as Level6_Name,
		   Case when Org.[Level 2 Manager ] = 'Alex McMullan' Then 'FCTO'
		       	when Org.[Level 2 Manager ] = 'Carl McQuillan' then 'International'
		       	when Org.[Level 2 Manager ] = 'Nathan Hall' then 'America'
		       	when Org.[Level 2 Manager ] = 'Scott Dedman' then 'GSI/MSP/Channel'
		       	when Org.[Level 2 Manager ] = 'Zack Murphy' then 'Data Architect'
		       	else 'GPO'
		   end Org_Gp
	from GPO_TSF_Dev.dbo.vempleveldetailsSFDC Org
	left join GPO_TSF_Dev.dbo.etlemporgmapper etl on etl.empid = Org.[Employee ID]
	left join GPO_TSF_Dev.dbo.vemporgmapper map on map.[Employee ID] = Org.[Employee ID]
	left join SalesOps_DM.dbo.SE_User_Role R on R.EmployeeID = Org.[Employee ID]
),


#Today_FYDate as (
	SELECT Date_ID, FiscalMonthKey + '01' [Fiscal_Date_ID]
	from NetSuite.dbo.DM_Date_445_With_Past
	where Date_ID = convert(varchar, getdate(), 112)
),

#M1_Achievement as (
		/* Current Fiscal Year */
		select SR.EmployeeID, SR.FiscalYear, SR.Period, SR.Quota [M1 Quota], SR.Achievement [M1 Achievement], SR.Attainment [M1 Attainment],
			   case 
			   		when (SR.Quota is null) and (SR.Achievement is null) then 'No M1 plan'
					when (SR.Quota = 0) then '$0 M1 Quota'   --if someone has $0 quota, any achievement is 100%
					else 'M1 QBH'
			   end M1_CompPlan_Flag,
			   FQtr_date.[FY_Date], #Today_FYDate.[Fiscal_Date_ID],
			   datediff(YEAR, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, FQtr_date.[FY_Date])) Rel_FY,		
			   datediff(Quarter, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, FQtr_date.[FY_Date])) Rel_FQ
		from SalesOps_DM.dbo.StackRank SR
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			    on FQtr_Date.FiscalYear = SR.FiscalYear and FQtr_Date.FiscalQuarter = SR.Period
		left join #Today_FYDate on #Today_FYDate.Date_ID = convert(varchar, getdate(), 112)
		where Measure = 'M1' and Period like 'Q%'
		
		UNION
		
		/* Current Fiscal Quarter */
		select SR.EmployeeID, SR.FiscalYear, SR.Period, SR.Quota [M1 Quota], SR.Achievement [M1 Achievement],
			   /* M1 Analplan attainment is calculated using the prorated Quota, this calculation is based on Qtrly Quota */
			   case when (SR.Quota is null) and (SR.Achievement is null) then NULL
			   		when (SR.Quota = 0) and (SR.Achievement = 0) then 0
			   		when (SR.Quota = 0) and (SR.Achievement > 0) then 1
			   		else SR.Achievement/SR.Quota
			   end [M1 Attainment],  /* Booking from the closed month / qtr quota */
			   case 
			   		when (SR.Quota is null) and (SR.Achievement is null) then 'No M1 plan'
					when (SR.Quota = 0) then '$0 M1 Quota'   --if someone has $0 quota, any achievement is 100%
					else 'M1 QBH'
			   end M1_CompPlan_Flag,
			   --FQtr_date.[FY_Date],
			   #Today_FYDate.[Fiscal_Date_ID] [FY_Date],
			   #Today_FYDate.[Fiscal_Date_ID],
			   datediff(YEAR, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, #Today_FYDate.[Fiscal_Date_ID])) Rel_FY,		
			   datediff(Quarter, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, #Today_FYDate.[Fiscal_Date_ID])) Rel_FQ
		from SalesOps_DM.dbo.StackRank SR
		left join #Today_FYDate on #Today_FYDate.Date_ID = convert(varchar, getdate(), 112)
		where Measure = 'M1' and Period like 'CQ'
		
		UNION

		/* FY17 till FY20 Annual Attainment */
		select SR.EmployeeID, SR.FiscalYear, SR.Period, SR.Quota [M1 Quota], SR.Achievement [M1 Achievement], SR.Attainment [M1 Attainment],
			   case
			   		when SR.FiscalYear in ('2019','2020') then
			   			case
					   		when (SR.Quota is null) and (SR.Achievement is null) then 'No M1 plan'
							when (SR.Quota = 0) then '$0 M1 Quota'   --if someone has $0 quota, any achievement is 100%
							else 'M1 QBH'
						end
					else 
						case when (SR.Attainment is null) then 'No M1 plan' else 'M1 QBH' end		
			   end M1_CompPlan_Flag,
			   FQtr_date.[FY_Date], #Today_FYDate.[Fiscal_Date_ID],
			   datediff(YEAR, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, FQtr_date.[FY_Date])) Rel_FY,
			   null Rel_FQ
		from SalesOps_DM.dbo.StackRank_History SR
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear) FQtr_date 
			    on FQtr_Date.FiscalYear = SR.FiscalYear 
		left join #Today_FYDate on #Today_FYDate.Date_ID = convert(varchar, getdate(), 112)
		where Measure = 'M1' and Period like 'FY'
		
		
		UNION
		
		/* FY19 to FY20 Quarterly Attainment */
		select SR.EmployeeID, SR.FiscalYear, SR.Period, SR.Quota [M1 Quota], SR.Achievement [M1 Achievement], SR.Attainment [M1 Attaiment],
			   case 
			   		when (SR.Quota is null) and (SR.Achievement is null) then 'No M1 plan'
					when (SR.Quota = 0) then '$0 M1 Quota'   --if someone has $0 quota, any achievement is 100%
					else 'M1 QBH'
			   end M1_CompPlan_Flag,
			   FQtr_date.[FY_Date], #Today_FYDate.[Fiscal_Date_ID],
			   datediff(YEAR, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, FQtr_date.[FY_Date])) Rel_FY,		
			   datediff(Quarter, convert(date, #Today_FYDate.[Fiscal_Date_ID]), convert(date, FQtr_date.[FY_Date])) Rel_FQ
		from SalesOps_DM.dbo.StackRank_History SR
		left join (select min(FiscalMonthKey) + '01' FY_Date, FiscalYear, 'Q' + FiscalQuarter [FiscalQuarter] from NetSuite.dbo.DM_Date_445_With_Past group by FiscalYear, FiscalQuarter) FQtr_date 
			    on FQtr_Date.FiscalYear = SR.FiscalYear and FQtr_Date.FiscalQuarter = SR.Period
		left join #Today_FYDate on #Today_FYDate.Date_ID = convert(varchar, getdate(), 112)
		where Measure = 'M1' and Period like 'Q%'
),

#M2_Achievement as (

/* Current Fiscal Year */
		select SR.Report_Date, SR.EmployeeID, SR.FiscalYear, SR.Period, SR.Quota [M2 Quota], SR.Achievement [M2 Achievement], SR.Attainment [M2 Attainment],
				case
		  			when (SR.Quota is null) and (SR.Achievement is null) then 'No M2 plan'
		  			when (SR.Quota = 0) then '$0 M2 Quota'
		  			else 'M2 QBH'
		  		end M2_CompPlan_Flag
		from SalesOps_DM.dbo.StackRank SR
		where Measure = 'M2'
),


/**** Achievement Wide ******/
#FY_M1_Attainment_2017 as (
	select Name, EmployeeID, Attainment [2017 M1 Attainment]
	from SalesOps_DM.dbo.StackRank_History
	where Period = 'FY' and Measure = 'M1' and FiscalYear in ('2017')
),

#FY_M1_Attainment_2018 as (
	select Name, EmployeeID, Attainment [2018 M1 Attainment]
	from SalesOps_DM.dbo.StackRank_History
	where Period = 'FY' and Measure = 'M1' and FiscalYear in ('2018') 
),

#FY_M1_Attainment_2019 as (
	select Name, EmployeeID, Attainment [2019 M1 Attainment], Achievement [2019 M1 Achievement], Quota [2019 M1 Quota]
	from SalesOps_DM.dbo.StackRank_History
	where Period = 'FY' and Measure = 'M1' and FiscalYear in ('2019') 
),

#FY_M1_Attainment_2020 as (
	select Name, EmployeeID, Attainment [2020 M1 Attainment], Achievement [2020 M1 Achievement], Quota [2020 M1 Quota]
	from SalesOps_DM.dbo.StackRank_History
	where Period = 'FY' and Measure = 'M1' and FiscalYear in ('2020') 
),

#YtD_M1_Attainment_2021 as (
/*	select SR.Name, SR.EmployeeID, SR.CQ_YtD_Achievement [2021 YtD Achievement], Q.Quota [2021 FY Quota],
	case when (Q.Quota = 0 or Q.Quota is null) then null
		 else SR.CQ_YtD_Achievement / Q.Quota ----
	end as [2021 YtD Attainment]
	from SalesOps_DM.dbo.StackRank SR
	left join (select EmployeeID, Quota from SalesOps_DM.dbo.SE_Org_Quota
			   where Measure = 'M1' and Period = 'FY') Q on Q.EmployeeID = SR.EmployeeID
	where Period = 'CQ' and Measure = 'M1' and FiscalYear in ('2021')
*/
	select SR.Name, SR.EmployeeID, SR.CQ_YtD_Achievement [2021 YtD Achievement], SR.CQ_YtD_Quota [2021 FY Quota],
	case when (SR.CQ_YtD_Quota = 0 or SR.CQ_YtD_Quota is null) then null
		 else SR.CQ_YtD_Achievement / SR.CQ_YtD_Quota ----
	end as [2021 YtD Attainment]
	from SalesOps_DM.dbo.StackRank SR
	where Period = 'CQ' and Measure = 'M1' and FiscalYear in ('2021')
),

#M1_Attainment_Wide as (
		select Org.*,
			 case when [2017 M1 Attainment] = 0 then null else [2017 M1 Attainment] end [2017 M1 Attainment],
			 case when [2017 M1 Attainment] = 0 then null
			      when [2017 M1 Attainment] >= 1 then 1 else 0 end [2017_Pass_M1_Attaiment],
			 case when [2018 M1 Attainment] = 0 then null else [2018 M1 Attainment] end [2018 M1 Attainment],
			 case when [2018 M1 Attainment] = 0 then null
			 	  when [2018 M1 Attainment] >= 1 then 1 else 0 end [2018_Pass_M1_Attaiment],
			 [2019 M1 Achievement], [2019 M1 Quota], 
			 case when [2019 M1 Quota] = 0 then null else [2019 M1 Attainment] end [2019 M1 Attainment],
			 case when [2019 M1 Quota] = 0 then null else 
			 	  case when [2019 M1 Attainment] >= 1 then 1 else 0 end 
			 end [2019_Pass_M1_Attaiment],
			 
			 [2020 M1 Achievement], [2020 M1 Quota], 
			 case when [2020 M1 Quota] = 0 then null else [2020 M1 Attainment] end [2020 M1 Attainment],
			 case when [2020 M1 Quota] = 0 then null else
			 	  case when [2020 M1 Attainment] >= 1 then 1 else 0 end
			 end [2020_Pass_M1_Attaiment],
			 	 
			 [2021 YtD Attainment],  [2021 YtD Achievement], [2021 FY Quota]
		
		from #SE_Org Org
		left join #FY_M1_Attainment_2017 #17 on #17.EmployeeID = Org.EmployeeID
		left join #FY_M1_Attainment_2018 #18 on #18.EmployeeID = Org.EmployeeID
		left join #FY_M1_Attainment_2019 #19 on #19.EmployeeID = Org.EmployeeID
		left join #FY_M1_Attainment_2020 #20 on #20.EmployeeID = Org.EmployeeID
		left join #YtD_M1_Attainment_2021 #21 on #21.EmployeeID = Org.EmployeeID
)


/* Construct the report */
Select 
	   Org.Org_Gp, Org.Name, Org.EmployeeID, Org.Manager, Org.Manager_EmployeeID,
	   Org.Role, Org.Position_Date, Org.Hire_Date, Org.IC_TF,
	   Org.Level, Org.Days_of_Service,
	   Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name, Org.Level6_Name,
	   Org.FiscalYear, Org.Period, cast(M1.[FY_Date] as Date) [Fiscal_Period_Date] , M1.Rel_FY, M1.Rel_FQ,
	   M1.[M1 Quota], M1.[M1 Achievement], M1.[M1 Attainment], M1.M1_CompPlan_Flag,
	   M2.[M2 Quota], M2.[M2 Achievement], M2.[M2 Attainment], M2.M2_CompPlan_Flag,
	   case when Org.FiscalYear = '2021' then 
	   		case
	   			when M1.[M1 Quota] is null and M2.[M2 Quota] is null then null
	   			when M1.[M1 Quota] is null and M2.[M2 Quota] is not null then M2.[M2 Quota]
	   			when M1.[M1 Quota] is not null and M2.[M2 Quota] is null then M1.[M1 Quota]
	   			else M1.[M1 Quota] + M2.[M2 Quota]
	   			end
	   		end as Quota,
	   case when Org.FiscalYear = '2021' then
	   		case when M1.[M1 Achievement] is null and M2.[M2 Achievement] is null then null
	   		 	 when M1.[M1 Achievement] is null and M2.[M2 Achievement] is not null then M2.[M2 Achievement]
	   			 when M1.[M1 Achievement] is not null and M2.[M2 Achievement] is null then M1.[M1 Achievement]
	   			 else M1.[M1 Achievement] + M2.[M2 Achievement]
	   			 end
	   		end as Achievement,
	   		
	   case when Org.FiscalYear = '2021' then
	   		case when M1.[M1 Quota] is null and M2.[M2 Quota] is null then null
	   			 when M1.[M1 Quota] > 0 and M2.[M2 Quota] is null then M1.[M1 Achievement] / M1.[M1 Quota]
	   			 when M1.[M1 Quota] is null and M2.[M2 Quota] > 0 then M2.[M2 Achievement] / M2.[M2 Quota]
	   			 when M1.[M1 Quota] > 0 and M2.[M2 Quota] > 0 then (M1.[M1 Achievement] + M2.[M2 Achievement]) / (M1.[M1 Quota] + M2.[M2 Quota])
	   			 else null
	   			 end
	   end as Attainment,
		 		
	   W.[2017 M1 Attainment], W.[2017_Pass_M1_Attaiment],
	   W.[2018 M1 Attainment], W.[2018_Pass_M1_Attaiment],
	   W.[2019 M1 Attainment], W.[2019_Pass_M1_Attaiment],
	   W.[2020 M1 Attainment], W.[2020_Pass_M1_Attaiment],
	   W.[2021 YtD Attainment], W.[2021 YtD Achievement], W.[2021 FY Quota],
	   M2.Report_Date [Attainment_Report_Date]
	 from (
	 		/* setup the entries for each Employee in the Org, a Archievement row of the reporting period */
	 		select * from #SE_Org cross join (Select distinct FiscalYear, Period from #M1_Achievement) a
	 	  ) Org
left join #M1_Achievement M1 on M1.EmployeeID = Org.EmployeeID and M1.FiscalYear = Org.FiscalYear and M1.Period = Org.Period
left join #M2_Achievement M2 on M2.EmployeeID = Org.EmployeeID and M2.FiscalYear = Org.FiscalYear and M2.Period = Org.Period
left join #M1_Attainment_Wide W on W.EmployeeID = Org.EmployeeID
where Org.Name = 'Gregory Robinson'

