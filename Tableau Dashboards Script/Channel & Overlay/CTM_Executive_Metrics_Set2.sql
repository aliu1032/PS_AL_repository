				  select min(Date_ID) [FirstDay], Max(Date_ID) [LastDay]
				  from NetSuite.dbo.DM_Date_445_With_Past
				  where FiscalYear = '2021' and FiscalMonth = '10' --the N_th month


/**************************************/
/*                                    */
/* CTM/NPTM favorite > PTM_Assignment */
/*                                    */
/**************************************/
/*  select Name , Partner_Id
  from SalesOps_DM.dbo.CTM_Favorite
*/
  select CTM.Name [PTM], A.Id [Partner_Id]
  from PureDW_SFDC_staging.dbo.Account A
  left join PureDW_SFDC_Staging.dbo.[User] CTM on CTM.Id = A.Channel_Technical_Manager__c
  where A.Channel_Technical_Manager__c is not null


/**********************************************/
/* FA Foundation & Professional Certification */
/**********************************************/  
select P.Id [Partner Id], P.Name [Partner Name], P.Type, P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater]
	,  C.Name [Contact],Cert.Email_Corporate__c,  Cert.Exam_Code__c, Cert.Exam_Group__c, Cert.Exam_Name__c, Cert.Exam_Grade__c, cast(Cert.Exam_Date__c as Date) [Exam Date]
	, case when Cert.Exam_Code__c in ('FAP_001', 'FAP_002') then 'FA Professional'
		   when Cert.Exam_Code__c in ('PCA_001', 'PCA_Acc001', 'PCADA_001', 'PCARA_001') then 'FA Associate'
		   when Cert.Exam_Code__c in ('FAAE_001') then 'FA Expert'
		   when Cert.Exam_Code__c in ('FAIP_001', 'FAIP_002', 'PCIA_001') then 'FA Implementation'
		   when Cert.Exam_Code__c in ('FBAP_001') then 'FB Professional'
		   when Cert.Exam_Code__c in ('PCSA_001') then 'Support Assoicate' -- exclude in the report
		   else 'Other' end [Pure Certification]
from PureDW_SFDC_Staging.dbo.Pure_Certification__c Cert
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Cert.Contact__c
left join PureDW_SFDC_Staging.dbo.Account P on P.Id = C.AccountId
where Contact__c is not NULL
and P.[Type] in ('Reseller', 'Disti')
--, 'PCA_001', 'FAP_001', )

/* rolling 12 months, # of Partner SE completing the certifications */
-- FAP_001, FAP_002, PCARA_001
;

select C.Name, A.Name [Account], L.Litmos__Finished__c, LM.Litmos__Description__c, L.Litmos__LitmosID__c, LM.Litmos__ModuleTypeDesc__c
from PureDW_SFDC_Staging.dbo.Litmos__UserModuleResult__c L
left join PureDW_SFDC_Staging.dbo.Litmos__ModuleNew__c LM on LM.Id = L.Litmos__ModuleNewID__c
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = L.Litmos__ContactID__c
left join PureDW_SFDC_Staging.dbo.Account A on A.Id = C.AccountId
where A.[Type] in ('Reseller', 'Disti')
and LM.Litmos__Active__c = 'True'
and L.Litmos__Finished__c >= '2019-01-01'
order by L.Litmos__Finished__c desc


/* Users Learning Path Result */ 
Select C.Name [Contact], C.Id [Contact Id], A.Name [Partner], LP.Name [Path Name], LPR.Litmos__PercentageComplete__c, LPR.Litmos__StartDate__c, LPR.Litmos__FinishDate__c
from PureDW_SFDC_Staging.dbo.Litmos__UserLearningPathResult__c LPR
left join PureDW_SFDC_Staging.dbo.[Contact] C on C.Id = LPR.Litmos__ContactID__c
left join PureDW_SFDC_Staging.dbo.[Account] A on A.Id = C.AccountId
left join PureDW_SFDC_Staging.dbo.Litmos__LearningPath__c LP on LP.Id = LPR.Litmos__LearningPathID__c
where LPR.Litmos__ContactID__c is not null
and A.[Type] in ('Reseller', 'Disti')
and LP.Litmos__LitmosID__c in ('88650', '86123', '78513', '70972', '70973')
--and C.Id = '0030z00002XLzRbAAL'


/**********************************************/
/* Pure Test Drive Partner Usage              */
/*                 Partner Adoption           */
/**********************************************/  
with
#SFDC_Contact as (
	select * from (
		select Id, Name, Email, AccountId,
			   ROW_NUMBER() over (partition by Email order by CreatedDate desc) RN
		  from PureDW_SFDC_staging.dbo.Contact
		  where Email is not null and IsDeleted = 'False'
	) a where RN = 1
),

#Partner_first_use as (
	select [Created by user name], cast([Created at] as Date) [First Use], [Created by company type],
		   [FiscalYear] [First Use FiscalYear], [FiscalQuarterName] [First Use FiscalQuarter], [FiscalMonth] [First Use Month],
		   rn, [Use Cnt]
	from (
		select [Created by], [Created by user name], [Created by company type], convert(date, [Created at], 20) [Created at],
--			   cast(convert(date, [Created at], 20) as datetime) + cast(convert(time, [Created at], 20) as datetime) [Created at],	
			   [FiscalYear], [FiscalQuarterName], [FiscalMonth],
			   ROW_NUMBER() over (PARTITION by [Created by user name] order by [Created at]) rn,
			   COUNT(*) over (PARTITION by [Created by user name]) [Use Cnt]
		from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
		where [Created by] = 'Carl NORMAN'
	) a where a.rn = 1  
),

#Report_Period as (
	select Date_ID, FiscalYear + ' Q' + FiscalQuarter [TestDrive_FiscalCreatedQuarter], cast([FiscalMonthKey] + '01' as date) [TestDrive_FiscalCreatedMonth] from (
		select Date_ID, FiscalYear, FiscalQuarter, [FiscalMonth], [FiscalMonthKey],
		ROW_NUMBER() over (partition by FiscalYear, FiscalQuarter, [FiscalMonthKey] order by Date_ID) rn
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= convert(varchar, dateadd(month, -23, getdate()), 112) and Date_ID <= convert(varchar, getdate(), 112)
	) a where rn = 1
)


select #Report_Period.[TestDrive_FiscalCreatedQuarter], #Report_Period.[TestDrive_FiscalCreatedMonth],
	   a.[Contact Id], a.[Created by user Name], a.[Created by company type], a.[Created at], a.[Lab name], a.[Product],
	   a.[Created By], a.[Contact Name], a.[Contact Email], a.[Partner Name], a.[Type],
/*	   case when a.[Partner Name] is null then null
	        else case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
	   end [Partner Tier],
*/
	   case when A.Type in ('Reseller','Distributor')
		 then
			case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
			else 'Is not a Channel Partner'
		end [Partner Tier],
	   a.[Partner Theater], a.[Partner Id],
	   a.[Use Cnt]
from #Report_Period
left join (
	select test_drive.*,
		   C.Id [Contact Id], 
		   COALESCE(C.Name, test_drive.[Created By]) [Contact Name], C.Email [Contact Email],
		   P.Name [Partner Name], P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater], P.Id [Partner Id], P.Type
			from (
					/* select the Test Drive run by Partner Users */
					select U.[Created by], U.[Created by user name],
						   case when U.[Created by user name] like '%.p3' then substring(U.[Created by user name], 1, len(U.[Created by user name])-3)
						   	    else U.[Created by user name]
						   end Created_By_User_Name,
						   U.[Created by company type], U.[Created at],
						   (cast([FiscalYear] as varchar(4)) + ' ' + [FiscalQuarterName]) [TestDrive_FiscalCreatedQuarter],
						   cast((cast([FiscalYear] as varchar(4)) + 
						   		 right('0000' + cast([FiscalMonth] as varchar(2)), 2)
						   		 + '01') as date) [TestDrive_FiscalCreatedMonth],
						   [Lab name], [Product], FU.[Use Cnt]
					from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values U
					left join #Partner_first_use FU on FU.[Created by user name] = U.[Created by user name]
					where U.[Created by company type] = 'Channel partner'
					and U.[Created by] not like 'Pure Storage%'
			) test_drive
	left join #SFDC_Contact C on C.Email = test_drive.Created_By_User_Name
	left join PureDW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
) a on a.TestDrive_FiscalCreatedQuarter = #Report_Period.[TestDrive_FiscalCreatedQuarter] and a.[TestDrive_FiscalCreatedMonth] = #Report_Period.[TestDrive_FiscalCreatedMonth]
where #Report_Period.[TestDrive_FiscalCreatedQuarter] like '2020%'
order by #Report_Period.[TestDrive_FiscalCreatedQuarter]

/**************************************************/
/* FA Sizer Log in GPO                            */
/* report # of FA Sizer created by Partner Users  */ 
/**************************************************/  
with
#SFDC_Contact as (
	select * from (
		select Id, Name, Email, AccountId,
			   ROW_NUMBER() over (partition by Email order by CreatedDate desc) RN
		  from PureDW_SFDC_staging.dbo.Contact
		  where Email is not null and Email not like '%delete%' and IsDeleted = 'False'
	) a where RN = 1
),

#Report_Period as (
	select Date_ID, FiscalYear + ' Q' + FiscalQuarter [FASizer_FiscalCreatedQuarter], cast([FiscalMonthKey] + '01' as date) [FASizer_FiscalCreatedMonth] from (
		select Date_ID, FiscalYear, FiscalQuarter, [FiscalMonth], [FiscalMonthKey],
		ROW_NUMBER() over (partition by FiscalYear, FiscalQuarter, [FiscalMonthKey] order by Date_ID) rn
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >=  convert(varchar, dateadd(month, -23, getdate()), 112) and Date_ID <= convert(varchar, getdate(), 112)
	) a where rn = 1
)

select #Report_Period.[FASizer_FiscalCreatedQuarter], #Report_Period.[FASizer_FiscalCreatedMonth]
	   --, a.[Sizer_Session_Id], a.datemin, a.sizeraction
	   , a.[Contact Id], a.[Contact Name], a.[Contact Email]
	   , a.[Partner Id], a.[Partner Name]
	   , case when A.Type in ('Reseller','Distributor')
		 then
			case when a.[Partner Tier] is null then 'None' else a.[Partner Tier] end
			else 'Is not a Channel Partner'
		end [Partner Tier]
	   , a.[Partner Theater]
	   , a.[Type]
from #Report_Period
left join (
			select convert(char(8), datemin, 112) [SizerCreate_Date_ID]
				   , (FiscalYear + ' Q' + FiscalQuarter) [Sizer_FiscalCreatedQuarter]
				   , cast((cast([FiscalYear] as varchar(4)) + right('0000' + cast([FiscalMonth] as varchar(2)), 2) + '01') as date) [Sizer_FiscalCreated_Month]
				   --, Sizer.Id [Sizer_Session_Id], Sizer.datemin, Sizer.sizeraction
				   , C.Id [Contact Id], C.Name [Contact Name], Sizer.email [Contact Email]
				   , P.Id [Partner Id], P.Name [Partner Name], P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater], P.Type
				from [GPO_TSF_Dev ].dbo.v_fa_sizer_rs_action Sizer
				   --from [GPO_TSF_Dev].[dbo].[sizer_rs_action] Sizer
				left join #SFDC_Contact C on C.Email = Sizer.email
				left join PureDW_SFDC_Staging.dbo.[Account] P on P.Id = C.AccountId
				left join NetSuite.dbo.DM_Date_445_With_Past FiscalDate on FiscalDate.Date_ID = convert(char(8), datemin, 112)
				where Sizer.email not like '%purestorage.com' and Sizer.email != ''
				  and Sizer.sizeraction= 'Create Sizing'
--				  and Sizer.datemin >= '2020-11-30' and Sizer.datemin < '2020-12-27'
) a on a.[Sizer_FiscalCreatedQuarter] = #Report_Period.[FASizer_FiscalCreatedQuarter] and a.[Sizer_FiscalCreated_Month] = #Report_Period.[FASizer_FiscalCreatedMonth]