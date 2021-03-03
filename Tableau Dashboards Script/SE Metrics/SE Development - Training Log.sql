
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
		Select EmployeeID [EmployeeId], Issuer, Certification [Training & Certification], null [Start Date],  null [Complete Date], [Report Date]
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn,
					   cast(Workday_Report_Date as date) [Report Date]
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Amazon') 
			) t where t.rn = 1
),

#Azure_Certification_Detail as (
		Select EmployeeID [EmployeeId], Issuer, Certification [Training & Certification], null [Start Date],  null [Complete Date], [Report Date]
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn,
						cast(Workday_Report_Date as date) [Report Date]
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Microsoft') 
			) t where t.rn = 1
),

/* FA Architect Professional */
#FA_Professional as (
	select EmployeeNumber [EmployeeId], 'Pure Storage' Issuer, Exam_Name__c [Training & Certification], null [Start Date],  [Exam Date] [Complete Date],
		   cast(getdate() as date) [Report Date]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and (Exam_Code__c = 'FAP_001' or Exam_Code__c = 'FAP_002') and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1 
), 

/* FA Architect Expert */
#FA_Expert as (
	select EmployeeNumber [EmployeeId],'Pure Storage' Issuer,  Exam_Name__c [Training & Certification], null [Start Date], [Exam Date] [Complete Date],
	       cast(getdate() as date) [Report Date]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and Exam_Code__c = 'FAAE_001' and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1
),


/* FB Architect Professional */
#FB_Professional as (
	select EmployeeNumber [EmployeeId], 'Pure Storage' Issuer, Exam_Name__c [Training & Certification], null [Start Date], [Exam Date] [Complete Date],
		   cast(getdate() as date) [Report Date]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and Exam_Code__c = 'FBAP_001' and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1
), -- check if there is FB Expert Cert Code

/* FB Assessment Training */
#FB_Assessment as (
		select a.EmployeeNumber [EmployeeId], 'Pure Storage' Issuer, [Litmos Name] [Training & Certification], null [Start Date], [Limmos Finished Date] [Complete Date],
			   cast(getdate() as date) [Report Date]
		from (
			select M.Name [Litmos Name], M.Litmos__ModuleTypeDesc__c [Litmos Type], M.Litmos__Passmark__c Passmark,
				   U.EmployeeNumber,
				   R.Litmos__Score__c Score, R.Litmos__AttemptNumber__c AttemptNumber, R.Litmos__Completed__c Completed,
				   R.Id [Result Id], R.Litmos__Started__c [Litmos Start Date], cast(R.Litmos__Finished__c as Date) [Limmos Finished Date], R.Litmos__Active__c [Result_isActive],
				   Row_Number() over (Partition by R.Litmos__UserID__c, R.Litmos__ModuleNewID__c order by R.Litmos__Finished__c desc) [Row]
			from PureDW_SFDC_Staging.dbo.Litmos__UserModuleResult__c R
			left join PureDW_SFDC_Staging.dbo.Litmos__ModuleNew__c M on M.Id = R.Litmos__ModuleNewID__c
			left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = R.Litmos__UserID__c
			where M.Id = 'aEj0z000000GmoPCAS'
		) a where a.[Row] = 1 
),

#Brocade_Learning_Path as (
		Select a.EmployeeNumber [EmployeeId], 'Pure Storage' Issuer, [Litmos Name] [Training & Certification],[Litmos Start Date] [Start Date], [Litmos Finished Date] [Complete Date],
			   cast(getdate() as date) [Report Date]
		from (
				Select U.EmployeeNumber, U.Name, LR.Litmos__Completed__c [Learning Completed], LR.Litmos__PercentageComplete__c [Learning Percentage Complete]
				, cast(LR.Litmos__StartDate__c as date) [Litmos Start Date],  cast(LR.Litmos__FinishDate__c as Date) [Litmos Finished Date]
				, LP.Name [Litmos Name]
				, LR.Litmos__LearningPathID__c
				, ROW_NUMBER() over (Partition by LR.Litmos__UserID__c, LR.Litmos__LearningPathID__c order by LR.Litmos__StartDate__c) [Row]
				from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LR
				left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LR.Litmos__UserID__c
				left join PureDW_SFDC_staging.dbo.Litmos__LearningPath__c LP on LP.Id = LR.Litmos__LearningPathID__c
				where LR.Litmos__LearningPathID__c = 'aEf0z000000XZC8CAO'
		) a where a.[Row] = 1
),

#MDS_Learning_Path as (
		Select a.EmployeeNumber [EmployeeId],'Pure Storage' Issuer,  [Litmos Name] [Training & Certification], [Litmos Start Date] [Start Date], [Litmos Finished Date] [Complete Date],
			   cast(getdate() as date) [Report Date]
		from (
				Select U.EmployeeNumber, U.Name, LR.Litmos__Completed__c [Learning Completed], LR.Litmos__PercentageComplete__c [Learning Percentage Complete]
				, cast(LR.Litmos__StartDate__c as date) [Litmos Start Date],  cast(LR.Litmos__FinishDate__c as Date) [Litmos Finished Date]
				, LP.Name [Litmos Name]
				, ROW_NUMBER() over (Partition by LR.Litmos__UserID__c, LR.Litmos__LearningPathID__c order by LR.Litmos__StartDate__c) [Row]
				from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LR
				left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LR.Litmos__UserID__c
				left join PureDW_SFDC_staging.dbo.Litmos__LearningPath__c LP on LP.Id = LR.Litmos__LearningPathID__c
				where LR.Litmos__LearningPathID__c = 'aEf0z000000XZBKCA4'
			) a
)

/*
Select cast(Org.EmployeeID as varchar) EmployeeID, Org.Name,
	   T.Issuer, T.[Training & Certification], T.[Start Date], T.[Complete Date], [Report Date]
from GPO_TSF_Dev.dbo.vSE_Org Org
left join (
			Select * from #AWS_Certification_Detail
			union
			Select * from #Azure_Certification_Detail
			union
			Select * from #FA_Expert
			union 
			Select * from #FA_Professional
			union
			Select * from #FB_Assessment
			union
			Select * from #FB_Professional
			union
			Select * from #Brocade_Learning_Path
			union
			Select * from #MDS_Learning_Path
		) T on T.EmployeeId = cast(Org.EmployeeID as varchar)
--where [Training & Certification] = 'Introduction to MDS'
--where Name = 'Rob Frase'

*/

Select cast(Org.EmployeeID as varchar) EmployeeID, Org.Name,
	   T.Issuer, T.[Training & Certification], [Report Date]
from GPO_TSF_Dev.dbo.vSE_Org Org
left join (
			Select * from #AWS_Certification_Detail
			union
			Select * from #Azure_Certification_Detail
		) T on T.EmployeeId = cast(Org.EmployeeID as varchar)
--where [Training & Certification] = 'Introduction to MDS'