/*
Select Close_Fiscal_Quarter__c, Fiscal_Year__c
from PureDW_SFDC_Staging.dbo.Opportunity
*/
/*

				select R.[Role], R.[Level], R.CertificationName , D.RequiredCompletionDays ,D.RecertificationInYears
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID

		*/
------------------ Certification and Training ----------------------

with
#SE_Org_T as (
	Select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
		cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate,
		cast(datediff(day, Org.HireDate, getDate())/365.25 as decimal(6,2)) [Length of Service in years],
		datediff(day, Org.HireDate, getDate()) [Length of Service],
		--datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
		/* New Hire to SE Org : Need to complete the training within X days from hire
		   Transfer from other Org into SE : Need to complete the training within X days
		   Transfer is the position date
		   Promotion is the position date */

		Org.coverage, Org.[Role],
		Org.[Level],
		Org.isManager, 
		Org.Manager, Org.[Leader], Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name
	from GPO_TSF_Dev.dbo.vSE_Org Org
	where Org.[Role] != 'FF'
),


#AWS_Certification as (
		Select EmployeeID [EmployeeId], Issuer, count(*) as Cloud_Cert_Count
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Amazon') 
			) t where t.rn = 1
		group by EmployeeID, Issuer
),

#Azure_Certification as (
		Select EmployeeID [EmployeeId], Issuer, count(*) as Cloud_Cert_Count
			from (
				/* Remove duplicate Certification */
				Select EmployeeID, Issuer, Certification, ROW_NUMBER() over (partition by EmployeeID, Issuer, Certification order by EmployeeID) as rn
				from GPO_TSF_Dev.dbo.SE_xCert
				where Issuer in ('Microsoft') 
			) t where t.rn = 1
		group by EmployeeID, Issuer
),


/* FA Architect Professional */
#FA_Professional as (
	select EmployeeNumber [EmployeeId], [Exam Date] [FA Architect Professional]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and (Exam_Code__c like 'FAP_%') and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1 
), 

/* FA Architect Expert */
#FA_Expert as (
	select EmployeeNumber [EmployeeId], [Exam Date] [FA Architect Expert]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and Exam_Code__c like 'FAAE_%' and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1
),


/* FB Architect Professional */
#FB_Professional as (
	select EmployeeNumber [EmployeeId], [Exam Date] [FB Professional]
	from (
		Select U.EmployeeNumber, C.User__c, C.Exam_Code__c, C.Exam_Name__c, cast(C.Exam_Date__c as Date) [Exam Date],
		ROW_NUmber() over (Partition by C.User__c order by C.Exam_Date__c desc) [Row]
		from PureDW_SFDC_Staging.dbo.Pure_Certification__c C
		left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = C.User__c
		where User__c is not null and Exam_Code__c like 'FBAP_%' and Exam_Date__c >= dateadd(year, -2, getdate())
	) a where a.[Row] = 1
), -- check if there is FB Expert Cert Code

/* FB Assessment Training */
#FB_Assessment as (
	Select * from (
		Select EmployeeNumber [EmployeeId], [FB Assessment],
			   ROW_NUMBER() over (Partition by EmployeeNumber order by [FB Assessment] desc) [Row]
		from (
			/** Litmos Record **/
			Select U.EmployeeNumber, cast(R.Litmos__Finished__c as Date) [FB Assessment], M.Name [Prg Name]
				from PureDW_SFDC_Staging.dbo.Litmos__UserModuleResult__c R
				left join PureDW_SFDC_Staging.dbo.Litmos__ModuleNew__c M on M.Id = R.Litmos__ModuleNewID__c
				left join PureDW_SFDC_Staging.dbo.[User] U on U.Id = R.Litmos__UserID__c
				where M.Id = 'aEj0z000000GmoPCAS'

			Union

			/** Leveljump Record **/
			select U.EmployeeNumber, cast(LRN_PE.LRN__Completion_Date__c as date) [FB Assessment], LRN_P.LRN__Name__c [Prg Name]
			from PureDW_SFDC_staging.dbo.LRN__Program_Enrollment__c LRN_PE
			left join PureDW_SFDC_staging.dbo.LRN__Program__c LRN_P on LRN_P.Id = LRN_PE.LRN__Program__c
			left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LRN_PE.LRN__User__c
			where LRN_P.LRN__Name__c = 'SE-FlashBlade SE Assessment'
			  and LRN_PE.LRN__Completion_Date__c is not null
		) combined
	) a where a.Row = 1

/*		select a.EmployeeNumber [EmployeeId], [Limmos Finished Date] [FB Assessment]
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
*/
),

#Brocade_Learning_Path as (
		Select a.EmployeeNumber [EmployeeId], [Litmos Finished Date] [Brocade & SAN]
		from (
				Select U.EmployeeNumber, U.Name, LP.Litmos__Completed__c [Learning Completed], LP.Litmos__PercentageComplete__c [Learning Percentage Complete]
				, cast(LP.Litmos__StartDate__c as date) [Litmos Start Date],  cast(LP.Litmos__FinishDate__c as Date) [Litmos Finished Date]
				--, LP.Litmos__LearningPathID__c
				, ROW_NUMBER() over (Partition by LP.Litmos__UserID__c, LP.Litmos__LearningPathID__c order by LP.Litmos__StartDate__c) [Row]
				from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LP
				left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LP.Litmos__UserID__c
				where 
				LP.Litmos__LearningPathID__c = 'aEf0z000000XZC8CAO'
		) a where a.[Row] = 1
),

#MDS_Learning_Path as (
		Select a.EmployeeNumber [EmployeeId], a.[Litmos Finished Date] [Intro to MDS]
		from (
				Select U.EmployeeNumber, U.Name, LP.Litmos__Completed__c [Learning Completed], LP.Litmos__PercentageComplete__c [Learning Percentage Complete]
				, cast(LP.Litmos__StartDate__c as date) [Litmos Start Date],  cast(LP.Litmos__FinishDate__c as Date) [Litmos Finished Date]
				--, LP.Litmos__LearningPathID__c
				, ROW_NUMBER() over (Partition by LP.Litmos__UserID__c, LP.Litmos__LearningPathID__c order by LP.Litmos__StartDate__c) [Row]
				from PureDW_SFDC_staging.dbo.Litmos__UserLearningPathResult__c LP
				left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LP.Litmos__UserID__c
				where
				LP.Litmos__LearningPathID__c = 'aEf0z000000XZBKCA4'
			) a
),

#AWS_Requirement as (
		select R.[Role], R.[Level], R.CertificationName [Required AWS],
		case when D.RequiredCompletionDays is null then 0 else D.RequiredCompletionDays end [AWS_RequiredCompletionDays]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName in ('AWS Cloud Certification')
), /* do not have completion date to check expiration. question: any grace period to complete */

#Azure_Requirement as (
		select R.[Role], R.[Level], R.CertificationName [Required Azure] , 
		case when D.RequiredCompletionDays is null then 0 else D.RequiredCompletionDays end [Azure_RequiredCompleteionDays]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName in ('Azure Cloud Certification')
),

#FA_Requirement as (
		select R.[Role], R.[Level], R.CertificationName [Required_FA],
			   case when D.RequiredCompletionDays is null then 0 else D.RequiredCompletionDays end [FA_RequiredCompletionDays],
			   case when D.RecertificationInYears is null then 99999 else D.RecertificationInYears end [FA_ExpirationInYears]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName in ('FlashArray Professional Architect')
), /* why Expert does not have an expiration date */

#FB_Assessment_Requirement as (
		select R.[Role], R.[Level], R.CertificationName [Required_FB], D.RequiredCompletionDays [FB_RequiredCompletionDays],
			   case when D.RecertificationInYears is null then 99999 else D.RecertificationInYears end [FB_ExpirationInYears]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName in ('FlashBlade Foundational Assessment')
),

#FB_ProCert_Requirement as (
		select R.[Role], R.[Level], R.CertificationName [Required_FB_ProCert], D.RequiredCompletionDays [FB_ProCert_RequiredCompletionDays],
			   case when D.RecertificationInYears is null then 99999 else D.RecertificationInYears end [FB_ProCert_ExpirationInYears]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName in ('FlashBlade Professional Architect')
),

#Brocade_Requirement as (
		Select R.[Role], R.[Level], R.[CertificationName] [Required_Brocade], 
			   case when D.RequiredCompletionDays is null then 0 else D.RequiredCompletionDays end [Brocade_RequiredCompletationDays],
			   case when D.RecertificationInYears is null then 99999 else D.RecertificationInYears end [Brocade_ExpirationInYears]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName = 'Cisco Brocade'
),

#MDS_Requirement as (
		Select R.[Role], R.[Level], R.[CertificationName] [Required_MDS],
			   case when D.RequiredCompletionDays is null then 0 else D.RequiredCompletionDays end [MDS_RequiredCompletationDays],
			   case when D.RecertificationInYears is null then 99999 else D.RecertificationInYears end [MDS_ExpirationInYears]
		from GPO_TSF_Dev.dbo.vSE_CertificationRequirements R
		left join GPO_TSF_Dev.dbo.SE_Certification_Detail D on D.CertificationID = R.CertificationID
		where D.CertificationName = 'MDS'
),

#Portworx_Training as (
	select U.Name [Name], U.EmployeeNumber [EmployeeID], LRN_P.LRN__Name__c [LRN Program Name], LRN_PE.LRN__Status__c
		 , LRN_PE.LRN__Percent_Complete__c
		 , cast(LRN_PE.LRN__Start_Date__c as Date) Start_Date, cast(LRN_PE.LRN__Target_Date__c as Date) Target_Date
		 , cast(LRN__Completion_Date__c as Date) Complete_Date
	from PureDW_SFDC_staging.dbo.LRN__Program_Enrollment__c LRN_PE
	left join PureDW_SFDC_staging.dbo.LRN__Program__c LRN_P on LRN_P.Id = LRN_PE.LRN__Program__c
	left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LRN_PE.LRN__User__c
	where LRN_P.Name = 'P-0025' --SE-Portworx On-Boarding Technical Training
),

#LvlJump_Assignment as (
	select U.EmployeeNumber [EmployeeID]
		 , count(LRN_P.LRN__Name__c) [Assigned LvlJump Programs]
		 , count(LRN__Completion_Date__c) [Completed LvlJump Programs]
	from PureDW_SFDC_staging.dbo.LRN__Program_Enrollment__c LRN_PE
	left join PureDW_SFDC_staging.dbo.LRN__Program__c LRN_P on LRN_P.Id = LRN_PE.LRN__Program__c
	left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LRN_PE.LRN__User__c
	group by U.EmployeeNumber
)

/***************************************
 Training completed: (Completion date is less than the expiration date) or (completion count > 0) then it is completed
 Training Required Flag: Drive from the Training requirement setup by role and level. variation:
	                     for users in the grace period, if one have not take the training, count as not required
						                                if one have completed the training, count as requried
 Training status: optional, onboarding, completed, expire soon, expired
****************************************/

Select
		cast(Org.EmployeeId as  varchar) EmployeeID,
		--Org.Name, Org.[Role], Org.[Level],

		/* FA Certification */
		/* Expert is higher level than Professional. Expired training is incompleted training */
		Case when #FA_Requirement.[Required_FA] is not null then
			 case when Org.[Length of Service] > #FA_Requirement.FA_RequiredCompletionDays then Org.EmployeeId
				  when Org.[Length of Service] <= #FA_Requirement.FA_RequiredCompletionDays and (#FA_Expert.[FA Architect Expert] is not null or #FA_Professional.[FA Architect Professional] is not null)
				  then Org.EmployeeId 
			 else null
			 end
		end [Required FA],

		[FA Architect Expert] = coalesce(convert(varchar, #FA_Expert.[FA Architect Expert], 107),''),
		[FA Architect Professional] = coalesce( convert(varchar,#FA_Professional.[FA Architect Professional],107), ''),
		Org.[Role], Org.[Name], Org.[Level],

		Case when #FA_Expert.[FA Architect Expert] is null and #FA_Professional.[FA Architect Professional] is null then 0
			 when #FA_Professional.[FA Architect Professional] is null and datediff(month, #FA_Expert.[FA Architect Expert], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 1
			 when #FA_Expert.[FA Architect Expert] is null and datediff(month, #FA_Professional.[FA Architect Professional], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 1
			 when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 1
			 when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 1
			 else 0 end
		[FA Architect Completed],

		case when #FA_Requirement.[Required_FA] is null then 'Optional' else
			Case when #FA_Expert.[FA Architect Expert] is null and #FA_Professional.[FA Architect Professional] is null then
					 Case when Org.[Length of Service] <= #FA_Requirement.FA_RequiredCompletionDays then 'Onboarding'
						  when #FA_Requirement.[Required_FA] is not null then 'Incompleted' end
				 else
					 Case
					 when #FA_Expert.[FA Architect Expert] is null and #FA_Professional.[FA Architect Professional] is not null then
						  Case when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) < #FA_Requirement.FA_ExpirationInYears*12-3 then 'Completed'
							   when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 'Expire soon'
							   when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) > #FA_Requirement.FA_ExpirationInYears*12 then 'Expired'
						  end
					 when #FA_Expert.[FA Architect Expert] is not null and #FA_Professional.[FA Architect Professional] is null then
						  Case when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) < #FA_Requirement.FA_ExpirationInYears*12-3 then 'Completed'
							   when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 'Expire soon'
							   when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) > #FA_Requirement.FA_ExpirationInYears*12 then 'Expired'
						  end
					 when #FA_Expert.[FA Architect Expert] is not null and #FA_Professional.[FA Architect Professional] is not null then
						  case when #FA_Expert.[FA Architect Expert] >= #FA_Professional.[FA Architect Professional] then 
							   Case when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) < #FA_Requirement.FA_ExpirationInYears*12-3 then 'Completed'
								    when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 'Expire soon'
								    when datediff(month, #FA_Professional.[FA Architect Professional], getdate()) > #FA_Requirement.FA_ExpirationInYears*12 then 'Expired'
							   end
						   else
							   Case when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) < #FA_Requirement.FA_ExpirationInYears*12-3 then 'Completed'
							 	    when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) <= #FA_Requirement.FA_ExpirationInYears*12 then 'Expire soon'
							 	    when datediff(month, #FA_Expert.[FA Architect Expert], getdate()) > #FA_Requirement.FA_ExpirationInYears*12 then 'Expired'
							   end
						   end
					end
				 end
		end [FA Cert Status],
		

		[FB Assessment] = coalesce(convert(varchar, #FB_Assessment.[FB Assessment], 107), ''),

		Case when #FB_Assessment_Requirement.[Required_FB] is null then 'Optional' else
			case when #FB_Assessment.[FB Assessment] is null and #FB_Professional.[FB Professional] is null then
					  case when Org.[Length of Service] <= #FB_Assessment_Requirement.FB_RequiredCompletionDays then 'Onboarding'
						   else 'Incompleted'
					  end
				when #FB_Assessment.[FB Assessment] is not null and #FB_Professional.[FB Professional] is null then 
					 case when datediff(month, #FB_Assessment.[FB Assessment], getdate()) < #FB_Assessment_Requirement.FB_ExpirationInYears*12-3 then 'Completed' -- not expired
						  when datediff(month, #FB_Assessment.[FB Assessment], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expire soon' -- not expired
						  when datediff(month, #FB_Assessment.[FB Assessment], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expired' -- not expired
					 end
				when #FB_Assessment.[FB Assessment] is null and #FB_Professional.[FB Professional] is not null then
					 case when datediff(month, #FB_Professional.[FB Professional], getdate()) < #FB_Assessment_Requirement.FB_ExpirationInYears*12-3 then 'Completed'
						  when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expire soon'
						  when datediff(month, #FB_Professional.[FB Professional], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expired'
					 end 
				when #FB_Assessment.[FB Assessment] is not null and #FB_Professional.[FB Professional] is not null then
					  case
						  when #FB_Assessment.[FB Assessment] >= #FB_Professional.[FB Professional] then
								case when datediff(month, #FB_Assessment.[FB Assessment], getdate()) < #FB_Assessment_Requirement.FB_ExpirationInYears*12-3 then 'Completed'
									 when datediff(month, #FB_Assessment.[FB Assessment], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expired soon'
									 when datediff(month, #FB_Assessment.[FB Assessment], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expired'
								end
						  when #FB_Assessment.[FB Assessment] < #FB_Professional.[FB Professional] then
								case when datediff(month, #FB_Professional.[FB Professional], getdate()) < #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Completed'
								     when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expire soon'
								     when datediff(month, #FB_Professional.[FB Professional], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 'Expired'
								end
					  end
			end
		end [FB Assessment Status],

		/* FB Assessment */
		Case when #FB_Assessment_Requirement.[Required_FB] is not null and Org.[Length of Service] > #FB_Assessment_Requirement.FB_RequiredCompletionDays then Org.EmployeeID
			 when #FB_Assessment_Requirement.[Required_FB] is not null and Org.[Length of Service] <= #FB_Assessment_Requirement.FB_RequiredCompletionDays 
				  and (#FB_Assessment.[FB Assessment] is not null or #FB_Professional.[FB Professional] is not null) then Org.EmployeeID 
			 when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null and Org.[Length of Service] > #FB_ProCert_Requirement.FB_ProCert_RequiredCompletionDays then Org.EmployeeID
			 when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null and Org.[Length of Service] <= #FB_ProCert_Requirement.FB_ProCert_RequiredCompletionDays
				  and #FB_Professional.[FB Professional] is not null then Org.EmployeeID
			 else null
		end [Required FB],
				 
		/* FB Professional Cert */
/*		Case when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null then 
			 case when Org.[Length of Service] > #FB_ProCert_Requirement.FB_ProCert_RequiredCompletionDays then Org.EmployeeID
				  when Org.[Length of Service] <= #FB_ProCert_Requirement.FB_ProCert_RequiredCompletionDays and #FB_Professional.[FB Professional] is not null then Org.EmployeeID
			 end
	    else null
		end [Required FB ProCert],*/
		
		[FB Professional] = coalesce(convert(varchar, #FB_Professional.[FB Professional], 107), ''),

		Case when #FB_Assessment_Requirement.[Required_FB] is not null then 
				Case 
					 when #FB_Assessment.[FB Assessment] is null and #FB_Professional.[FB Professional] is null then 0
					 when #FB_Assessment.[FB Assessment] is not null and #FB_Professional.[FB Professional] is null then
						 case 
							  when datediff(month, #FB_Assessment.[FB Assessment], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 1 -- not expired
							  when datediff(month, #FB_Assessment.[FB Assessment], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 0  -- expired
						 end
					 when #FB_Assessment.[FB Assessment] is null and #FB_Professional.[FB Professional] is not null then
						 case
							  when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 1
							  when datediff(month, #FB_Professional.[FB Professional], getdate()) > #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 0
						  end
					 when #FB_Assessment.[FB Assessment] is not null and #FB_Professional.[FB Professional] is not null then
						  case
							  when #FB_Assessment.[FB Assessment] >= #FB_Professional.[FB Professional] then
									case when datediff(month, #FB_Assessment.[FB Assessment], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 1 end
							  when #FB_Assessment.[FB Assessment] < #FB_Professional.[FB Professional] then
									case when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_Assessment_Requirement.FB_ExpirationInYears*12 then 1 end
						  end
					 else 0
				end --[FB Assessment Completed],
			when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null then 
				Case when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null then
					Case when #FB_Professional.[FB Professional] is null then 0
						 when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_ProCert_Requirement.[FB_ProCert_ExpirationInYears]*12 then 1
						 else 0 end
				end --[FB ProCert Completed],
		end [FB Completed],

		Case when #FB_ProCert_Requirement.[Required_FB_ProCert] is null then 'Optional' else
			 Case when #FB_Professional.[FB Professional] is null
				 then
					Case when Org.[Length of Service] < #FB_ProCert_Requirement.FB_ProCert_RequiredCompletionDays then 'Onboarding'
						 when #FB_ProCert_Requirement.[Required_FB_ProCert] is not null then 'Incompleted'
					end
				 else
					Case when datediff(month, #FB_Professional.[FB Professional], getdate()) < #FB_ProCert_Requirement.FB_ProCert_ExpirationInYears * 12-3 then 'Completed'
						 when datediff(month, #FB_Professional.[FB Professional], getdate()) <= #FB_ProCert_Requirement.FB_ProCert_ExpirationInYears * 12 then 'Expire soon'
						 when datediff(month, #FB_Professional.[FB Professional], getdate()) > #FB_ProCert_Requirement.FB_ProCert_ExpirationInYears * 12 then 'Expired'
					end
			 end
		end [FB Professional Status],	

		[Brocade and SAN for Pre-Sales] = coalesce(convert(varchar, #Brocade_Learning_Path.[Brocade & SAN], 107), ''),
		case when #Brocade_Requirement.[Required_Brocade] is not null and Org.[Length of Service] > #Brocade_Requirement.Brocade_RequiredCompletationDays then Org.EmployeeID
			 when #Brocade_Requirement.[Required_Brocade] is not null and Org.[Length of Service] <= #Brocade_Requirement.Brocade_RequiredCompletationDays 
				  and #Brocade_Learning_Path.[Brocade & SAN] is not null then Org.EmployeeID 
			 else null
		end [Required Brocade],
		
		Case when #Brocade_Learning_Path.[Brocade & SAN] is not null then 
		     case when datediff(month, #Brocade_Learning_Path.[Brocade & SAN], getdate()) <= #Brocade_Requirement.Brocade_ExpirationInYears*12 then 1 else 0 end
			 else 0
		end [Brocade and SAN for Pre-Sales Completed],

		case when #Brocade_Requirement.[Required_Brocade] is null then 'Optional' else
			 case when #Brocade_Learning_Path.[Brocade & SAN] is null then 
				  case when Org.[Length of Service] <= #Brocade_Requirement.Brocade_RequiredCompletationDays then 'Onboarding' else 'Incompleted' end
			 else
				  case
				  when datediff(month, #Brocade_Learning_Path.[Brocade & SAN], getdate()) < #Brocade_Requirement.Brocade_ExpirationInYears*12-3 then 'Completed'
				  when datediff(month, #Brocade_Learning_Path.[Brocade & SAN], getdate()) <= #Brocade_Requirement.Brocade_ExpirationInYears*12 then 'Expire soon'
				  when datediff(month, #Brocade_Learning_Path.[Brocade & SAN], getdate()) > #Brocade_Requirement.Brocade_ExpirationInYears*12 then 'Expired'
				  end
			 end
		end [Brocade Training Status],
	
		[Intro to MDS] = coalesce( convert(varchar, #MDS_Learning_Path.[Intro to MDS] , 107), ''),
		Case when #MDS_Requirement.[Required_MDS] is not null and Org.[Length of Service] > #Brocade_Requirement.Brocade_RequiredCompletationDays then Org.EmployeeID
			 when #MDS_Requirement.[Required_MDS] is not null and Org.[Length of Service] > #Brocade_Requirement.Brocade_RequiredCompletationDays
				  and #MDS_Learning_Path.[Intro to MDS] is not null then Org.EmployeeID
			 else null
		end [Required MDS], 

		Case when #MDS_Learning_Path.[Intro to MDS] is not null then
			 case when datediff(month, #MDS_Learning_Path.[Intro to MDS], getdate()) <= #MDS_Requirement.MDS_ExpirationInYears*12 then 1 else 0 end
			 else 0
		end [Intro to MDS Completed],

		Case when #MDS_Requirement.[Required_MDS] is null then 'Optional' else
			 case when #MDS_Learning_Path.[Intro to MDS] is null then
				  case when Org.[Length of Service] <= #MDS_Requirement.MDS_RequiredCompletationDays then 'Onboarding' else 'Incompleted' end
			 else
				  case
				  when datediff(month, #MDS_Learning_Path.[Intro to MDS], getdate()) < #MDS_Requirement.MDS_ExpirationInYears*12-3 then 'Completed'
				  when datediff(month, #MDS_Learning_Path.[Intro to MDS], getdate()) <= #MDS_Requirement.MDS_ExpirationInYears*12 then 'Expire soon'
				  when datediff(month, #MDS_Learning_Path.[Intro to MDS], getdate()) > #MDS_Requirement.MDS_ExpirationInYears*12 then 'Expired'
				  end
			 end
		end [MDS Training Status],
		
		/* AWS Certification */
		Case when #AWS_Requirement.[Required AWS] is not null and Org.[Length of Service] > #AWS_Requirement.AWS_RequiredCompletionDays then Org.EmployeeID
			 when #AWS_Requirement.[Required AWS] is not null and Org.[Length of Service] <= #AWS_Requirement.AWS_RequiredCompletionDays
				  and #AWS_Certification.Cloud_Cert_Count > 0 then Org.EmployeeID 
			 else null
		end [Required AWS],

		case
			when #AWS_Requirement.[Required AWS] is null then 
				 case when (#AWS_Certification.Cloud_Cert_Count is null or #AWS_Certification.Cloud_Cert_Count = 0) then null else #AWS_Certification.Cloud_Cert_Count end
			else coalesce(#AWS_Certification.Cloud_Cert_Count, '')
		end [# of AWS Certification],

		case when #AWS_Certification.Cloud_Cert_Count is null or #AWS_Certification.Cloud_Cert_Count = 0 then 0 else 1
		end [AWS Certification Completed],

		Case when #AWS_Requirement.[Required AWS] is null then 'Optional' else 
			 case when #AWS_Certification.Cloud_Cert_Count is null or #AWS_Certification.Cloud_Cert_Count = 0 then
				  case when Org.[Length of Service] <= #AWS_Requirement.AWS_RequiredCompletionDays then 'Onboarding' else 'Incompleted' end
			 else 'Completed'
			 end
		end [AWS Cert Status],

		/* Azure */

		Case when #Azure_Requirement.[Required Azure] is not null and Org.[Length of Service] > #Azure_Requirement.Azure_RequiredCompleteionDays then Org.EmployeeID
			 when #Azure_Requirement.[Required Azure] is not null and Org.[Length of Service] <= #Azure_Requirement.Azure_RequiredCompleteionDays 
				  and #Azure_Certification.Cloud_Cert_Count > 0 then Org.EmployeeID
			 else null
		end [Required Azure],

		Case	
			 when #Azure_Requirement.[Required Azure] is null then
				  case when #Azure_Certification.Cloud_Cert_Count is null or #Azure_Certification.Cloud_Cert_Count = 0 then null else #Azure_Certification.Cloud_Cert_Count end
			 else coalesce(#Azure_Certification.Cloud_Cert_Count,'')
		end [# of Azure Certification],
		
		Case when #Azure_Certification.Cloud_Cert_Count is null or #Azure_Certification.Cloud_Cert_Count = 0 then 0 else 1
		end [Azure Certification Completed],

		Case when #Azure_Requirement.[Required Azure] is null then 'Optional' else 
			 Case when #Azure_Certification.Cloud_Cert_Count is null or #Azure_Certification.Cloud_Cert_Count = 0 then
				  Case when Org.[Length of Service] <= #Azure_Requirement.Azure_RequiredCompleteionDays then 'Onboarding' else 'Incompleted' end
			 else 'Completed'
			 end
		end [Azure Cert Status],

		[Portworx] = coalesce(convert(varchar, #Portworx_Training.Complete_Date, 107), convert(varchar, #Portworx_Training.LRN__Percent_Complete__c)+'%', ''),
		case when #Portworx_Training.LRN__Status__c is null then 'Optional' else #Portworx_Training.LRN__Status__c end [Portworx Status],
		case when #Portworx_Training.Complete_Date is null then 0 else 1 end [Portworx Completed],

		cast(#LvlJump_Assignment.[Completed LvlJump Programs] as varchar) + ' of ' 
			+ cast(#LvlJump_Assignment.[Assigned LvlJump Programs] as varchar) [LvlJump Programs Completed]

		from #SE_Org_T Org

		left join #FA_Expert on #FA_Expert.EmployeeId = Org.EmployeeID
		left join #FA_Professional on #FA_Professional.EmployeeId = Org.EmployeeId
		left join #FA_Requirement on #FA_Requirement.[Role] = Org.[Role] and #FA_Requirement.[Level] = Org.[Level]
		left join #FB_Assessment on #FB_Assessment.EmployeeId = Org.EmployeeId
		left join #FB_Assessment_Requirement on #FB_Assessment_Requirement.[Role] = Org.[Role] and #FB_Assessment_Requirement.[Level] = Org.[Level]
		left join #FB_Professional on #FB_Professional.EmployeeId = Org.EmployeeID
		left join #FB_ProCert_Requirement on #FB_ProCert_Requirement.[Role] = Org.[Role] and #FB_ProCert_Requirement.[Level] = Org.[Level]
		left join #AWS_Certification on #AWS_Certification.EmployeeId = Org.EmployeeId
		left join #AWS_Requirement on #AWS_Requirement.[Role] = Org.[Role] and #AWS_Requirement.[Level] = Org.[Level]
		left join #Azure_Certification on #Azure_Certification.EmployeeId = Org.EmployeeID
		left join #Azure_Requirement on #Azure_Requirement.[Role] = Org.[Role] and #Azure_Requirement.[Level] = Org.[Level]
		left join #Brocade_Learning_Path on #Brocade_Learning_Path.EmployeeId = Org.EmployeeId
		left join #Brocade_Requirement on #Brocade_Requirement.[Role] = Org.[Role] and #Brocade_Requirement.[Level] = Org.[Level]
		left join #MDS_Learning_Path on #MDS_Learning_Path.EmployeeId = Org.EmployeeId
		left join #MDS_Requirement on #MDS_Requirement.[Role] = Org.[Role] and #MDS_Requirement.[Level] = Org.[Level]
		left join #Portworx_Training on #Portworx_Training.EmployeeID = Org.EmployeeID
		left join #LvlJump_Assignment on #LvlJump_Assignment.EmployeeID = Org.EmployeeID

--		where Org.[Role] = 'SE'
--where Org.EmployeeId in ('106845')
--	Dan Van Roekel


;
