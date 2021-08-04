/*	select etl.preferredname [Name], CAST(Org.[Employee ID] AS varchar) [EmployeeID], etl.mgr [Manager], cast(etl.mgrid as varchar) [Manager_EmployeeID], R.Resource_Group [Role],
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
*/

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
	
	

/* SE Team Metrics */
select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
       cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate,
       cast(datediff(day, Org.HireDate, getDate())/365.25 as decimal(6,2)) [Length of Service in years],
       --datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
       Org.coverage [Coverage], Org.[Role], Org.[Level], Org.isManager, Org.IC_MGR,
       Org.Manager, Org.[Leader], Org.Level1_Name,
	   case when Org.Level2_Name = '' and Org.[Employee Level] = 1 then Org.Name else Org.Level2_Name end [Level2_Name],
	   case when Org.Level3_Name = '' and Org.[Employee Level] = 2 then Org.Name else Org.Level3_Name end [Level3_Name],
	   case when Org.Level4_Name = '' and Org.[Employee Level] = 3 then Org.Name else Org.Level4_Name end [Level4_Name],
--	   Org.[Level2_Name], Org.[Level3_Name], Org.[Level4_Name],
	   case when Org.Level5_Name = '' and Org.[Employee Level] = 4 then Org.Name else Org.Level5_Name end [Level5_Name]
from GPO_TSF_Dev.dbo.vSE_Org Org
where Org.[Role] not in ( 'FF', 'HQ')
  and Level2_Name in ('Nathan Hall' ,'Carl McQuillan', 'Shawn Rosemarin')
--[Org].Manager != 'Alex McMullan' and [Org].Name != 'Alex McMullan'
  
  
  
 with
SE_Org_T as (
	select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
		cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate, datediff(day, Org.HireDate, getDate()) [Length of Service],
		-- datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
		Org.coverage, Org.[Role],
		Org.[Level],
		Org.isManager, 
		Org.Manager, Org.[Leader], Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name
	from GPO_TSF_Dev.dbo.vSE_Org Org
	where Org.[Role] != 'FF'
)
Select * into #SE_Org_T from SE_Org_T;