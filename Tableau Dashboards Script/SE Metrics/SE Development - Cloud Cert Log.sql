
------------------ Certification and Training ----------------------

with
#SE_Org as (
	select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
		cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate, datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
		Org.coverage, Org.[Role],
		Org.[Level],
		Org.isManager, 
		Org.Manager, Org.[Leader], Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name
	from GPO_TSF_Dev.dbo.vSE_Org Org
	where Org.[Role] != 'FF'
),


#AWS_Certification_Detail as (
		Select EmployeeID [EmployeeId], Issuer, Certification [Cloud Certification], [Report Date]
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn,
					   cast(Workday_Report_Date as date) [Report Date]
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Amazon') 
			) t where t.rn = 1
),

#Azure_Certification_Detail as (
		Select EmployeeID [EmployeeId], Issuer, Certification [Cloud Certification], [Report Date]
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn,
						cast(Workday_Report_Date as date) [Report Date]
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Microsoft') 
			) t where t.rn = 1
)


select cast(Org.EmployeeID as varchar) EmployeeID, Org.Issuer, Org.Certification,
	   Case when Cert_Log.[Cloud Certification] is not null then 1 else 0 end [Certification Completed],
	   Org.[Workday_Report_Date]
from 
	(
		select * from 
			(Select distinct(EmployeeID) from GPO_TSF_Dev.dbo.vSE_Org) Emp
			cross join
			(Select distinct(Certification), Issuer, Workday_Report_Date from GPO_TSF_Dev.dbo.SE_xCert where Issuer in ('Amazon', 'Microsoft')) cert
		
	) Org
left join 
	(
			Select * from #AWS_Certification_Detail
			union
			Select * from #Azure_Certification_Detail
	) Cert_Log
on Cert_Log.EmployeeID = Org.EmployeeID and Cert_Log.[Cloud Certification] = Org.[Certification]

