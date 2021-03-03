/* Resource Leverage */

-- Mitrend - to Oppt - SE Owner
-- FA Sizer
-- Test Drive - to User
-- CSC PoC - to Oppt - SE Owner
-- Dell page -- user
-- PVR
-- SE Specialist


--v_csc_poc_clean is the data from Service Now that has been parsed for extracting Opp ID from the Opportunity Links
--v_CSC_POC_Global_View is the table that contains valid SFDC Opp IDs from CSC POC and On-Prem POCs

select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
       cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate, datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
       Org.coverage, Org.[Role], Org.[Level], Org.isManager, 
       Org.Manager, Org.[Leader], Org.Level1_Name, Org.Level2_Name, Org.Level3_Name, Org.Level4_Name, Org.Level5_Name,
	   P.[User]
from GPO_TSF_Dev.dbo.vSE_Org Org
left join (
		select Subordinate_EmployeeID, Email [User]
		from SalesOps_DM.dbo.SE_Subordinate_Permission
) P on P.Subordinate_EmployeeID = Org.EmployeeID
where Org.[Role] not in ( 'FF', 'HQ')

select cast(Org.[EmployeeID] as varchar) EmployeeID, Org.Name, Org.Email, Org.Title,
       cast(Org.HireDate as Date) HireDate, Org.PositionEffectDate, datediff(day, Org.PositionEffectDate, getDate()) [Length of Service],
       Org.coverage, Org.[Role], Org.[Level], Org.isManager, 
       Org.Manager, Org.[Leader], Org.Level1_Name,
--	   case when Org.Level2_Name = '' and Org.[Employee Level] = 1 then Org.Name else Org.Level2_Name end [Level2_Name],
--	   case when Org.Level3_Name = '' and Org.[Employee Level] = 2 then Org.Name else Org.Level3_Name end [Level3_Name],
--	   case when Org.Level4_Name = '' and Org.[Employee Level] = 3 then Org.Name else Org.Level4_Name end [Level4_Name],
	   Org.[Level2_Name], Org.[Level3_Name], Org.[Level4_Name],
	   case when Org.Level5_Name = '' and Org.[Employee Level] = 4 then Org.Name else Org.Level5_Name end [Level5_Name]
from GPO_TSF_Dev.dbo.vSE_Org Org
where Org.[Role] not in ( 'FF', 'HQ')
/************************************************/

With
/* Test Drive :: # of times a user created test drive per fiscal month */
#Test_Drive as (
		select [Created by user name], Test_Drive_Created_Cnt
		from (
			Select [Created by user name],
				   count(*) over (partition by [Created by user name]) Test_Drive_Created_Cnt,
				   ROW_Number() over (partition by [Created by user name] order by [Created at] desc) rn
			from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
			where [created_at_date] >= getdate()-90
		) a where rn = 1
),


/* Mitrend Assessment :: # of Mitrend assessment created by a User per Fiscal Month */
#Mitrend as (
	Select Submitted_By, Mitrend_Assessment_Cnt
	from (
			Select M.Submitter__c [Submitted_By], M.Submitted__c,
				   count(*) over (partition by M.Submitter__c) Mitrend_Assessment_Cnt,
				   ROW_NUMBER() over (partition by M.Submitter__c order by M.Submitted__c desc) RN
			from PureDW_SFDC_Staging.dbo.MitrendAssessment__c M
			where Submitted__c >= getdate()-90
			) a
	where RN = 1
),

/* CSC PoC :: assume the SE Oppt owner is the requestor of CSC PoC, accumulative # of CSC PoC request raised by a User */
#CSC_POC as (
		Select SE_EmployeeID, CSC_POC_CNT
		from (
				Select SE.EmployeeNumber [SE_EmployeeID],
					   count(*) over (partition by SE.EmployeeNumber) CSC_PoC_Cnt,
					   ROW_Number() over (partition by SE.EmployeeNumber order by CSC.created_at_date) RN
				from Datascience_Workbench_Views.dbo.v_csc_poc_clean CSC
				left join PureDW_SFDC_Staging.dbo.Opportunity O on O.Id = CSC.Opp_ID
				left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
				where SE.EmployeeNumber is not null
				  and CSC.created_at_date >= getdate() - 90
		) a where RN = 1 and SE_EmployeeID is not null
),

#SE_Specialist as (
	select SNOW.Requestor_EmployeeNumber, Count(*) [SE_Specialist_Ticket_Cnt]
	from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets SNOW
	where SNOW.Created >= getdate() - 90
	group by SNOW.Requestor_EmployeeNumber
),


#FA_Sizer as (
	select Email, Count(*) [Create_FA_Sizer_Cnt]
	from [GPO_TSF_Dev].[dbo].[sizer_rs_action] Sizer
	where Sizer.email like '%purestorage.com' and Sizer.email != '' and Sizer.sizeraction = 'Create Sizing'
	  and datemin >= getdate() - 90
	group by Email
),


#Rpt_Period as (
	select FiscalYear, FiscalQuarterName, FiscalMonth
	from (
		select FiscalYear, FiscalQuarterName, FiscalMonth,
			   Row_Number() over (partition by FiscalYear, FiscalMonth order by Date_ID) rn
		from NetSuite.dbo.DM_Date_445_With_Past
		where convert(date, Date_ID) >= getdate()-90 and convert(date, Date_ID) <= getdate()
	) a where rn = 1
)

/* PVR :: accumulative # of time a user used the PVR report */
-- moved to BI server to pull PVR data
/*#PVR as (
	Select [Username], [Timed Viewed], [Last Viewed]
	from TableauMonitoring.guest.CDF_CustomerFacing
)
*/



/** Summary Table */
Select cast(Org.EmployeeID as varchar) EmployeeID,
	   #Test_Drive.Test_Drive_Created_Cnt [Test Drive created],
	   #Mitrend.Mitrend_Assessment_Cnt [Mitrend assessment],
	   #CSC_POC.CSC_PoC_Cnt [CSC POC Ticket raised],
	   #SE_Specialist.[SE_Specialist_Ticket_Cnt] [SE Specialist Ticket raised],
	   #FA_Sizer.[Create_FA_Sizer_Cnt]
--	   #PVR.[Timed Viewed] [PVR]
from GPO_TSF_Dev.dbo.vSE_Org Org
left join #Test_Drive on #Test_Drive.[Created by user name] = Org.Email 
left join #Mitrend on #Mitrend.[Submitted_By] = Org.Email 
left join #CSC_POC on #CSC_POC.SE_EmployeeID = Org.EmployeeID
left join #SE_Specialist on #SE_Specialist.Requestor_EmployeeNumber = Org.EmployeeID
left join #FA_Sizer on #FA_Sizer.Email = Org.Email
--left join #PVR on #PVR.[Username] = Org.Email
