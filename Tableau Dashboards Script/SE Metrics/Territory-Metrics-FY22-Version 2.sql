/*** Script used in Territory Analysis Version 2 */
select *
from SalesOps_DM.dbo.TerritoryID_Master_FY22

/* Coverage by Name */
select EmployeeID, Name [Employee], Email, Title, [Hire Date], [Territory_ID]
	 , [GTM_Role], [Sales Group 4], [SEOrg_Role], [SEOrg_Level], [IC_Mgr]
from SalesOps_DM.dbo.Coverage_assignment_byName_FY22_ANA
where [GTM_Role] in ('Sales Mgmt','Sales AE', 'SE Mgmt', 'SE', 'PTM','PTS','DA Mgmt','DA','FSA Mgmt','FSA', 'FB AE', 'SE Specialist IC' )


select Territory_Id, Quota, Period, [Year], Measure
from SalesOps_DM.dbo.Territory_Quota_FY22_ANA


/*****************************************/
/*                                       */
/*   Account to Territory                */
/*                                       */
/*****************************************/
/* Sales Central : Account Plans
 * https://support.purestorage.com/Sales/Tools_Processes_and_Sales_Support/Sales_Planning_and_Sales_Comp/Account_Plans
 * 
 * need StrategicPursuits__c in database
 */

select A.Id [Account_Id], A.Name [Account], A.[Type] [Acc_Type]
	 , A.Dark_Site__c, A.Theater__c [SFDC_Theater], A.Division__c [SFDC_Division], A.Sub_Division__c [SFDC_Sub_Division]
	 , Ana.[Current Theater] [Theater], Ana.[Current Area] [Area], Ana.[Current Region] [Region], Ana.[Current District] [District], Ana.[Current Territory Assignment] [Territory], Ana.[Current Territory ID] [Territory_Id]
	 , A.Vertical__c [Vertical], A.Sub_vertical__c [Sub_vertical], Segment__c [Segment]
	 , A.EMEA_Segment__c [EMEA_Segment]
	 , A.MDM_Segment__c, A.MDM_Vertical__c, A.MDM_Sub_Vertical__c, A.MDM_Industry__c, A.data_com_Industry__c
	 , A.Global_Ultimate_Parent__c, A.Global_Ultimate_Parent_Name__c, A.Ultimate_Parent_Id__c
	 , AP.Id [AcctPlan_Id], AP.Account_Booking_Goal__c [Account_Booking_Goal], AP.CreatedDate [AcctPlan_CreatedDate]
	 , AP.Technical_AP_Owner__c
	 , count(AP.Id) over (partition by AP.Account__c order by AP.CreatedDate) [No. of Acct Plan]
	, A.ES2SubscriptionCustomer__c, A.Opportunity_Count__c, A.Closed_Won_Business__c, A.Amount_of_Open_Opps__c, A.Closed_Won_Business_excl_Renewals__c
from PureDW_SFDC_staging.dbo.[Account] A
left join Anaplan_DM.dbo.Account_to_Territory Ana on Ana.[Account ID] = A.Id
left join 
		( Select Id, Account__c, Account_Booking_Goal__c, CreatedDate, Master_Account_Plan__c
			   , count(Id) over (partition by Account__c order by CreatedDate) [No. of Account Plan]
		  from PureDW_SFDC_staging.dbo.[Account_Plans__c]
		  where Master_Account_Plan__c = 'true'
		) AP on AP.Account__c = A.Id
where A.IsDeleted = 'false'



/*****************************************/
/*                                       */
/*   Opportunity Splits                  */
/*                                       */
/*****************************************/
With

#Oppt_Split as (
			/* a copy of the original deals */
			/* cannot determine a SE opportunity owner using split. An AE may be supported by a pool of SEs */
			Select Oppt.Id
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, Split_Acct_Exec.Name Acct_Exec

				/* Use the Territory value from split */
				, case when OpptSplit.Override_Territory__c is null then OpptSplit.Territory_ID__c else OpptSplit.Override_Territory__c end Split_Territory_ID
				, case when OpptSplit.Override_Territory__c is null then left(OpptSplit.Territory_ID__c,18) else left(OpptSplit.Override_Territory__c,18) end Split_District_ID

				, OpptSplit.SplitPercentage
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is counted towards raw bookings for comp calculation
--- need to pull commisonable amount
				, RecType.Name RecordType
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Split_Acct_Exec on  Split_Acct_Exec.Id = OpptSplit.SplitOwnerID				--left join #AE_Coverage AE_Coverage on AE_Coverage.EmployeeID = Acct_Exec.EmployeeNumber
				
			where (Oppt.CreatedDate >= '2018-02-01' OR Oppt.CloseDate >= '2018-02-01') --and Oppt.CloseDate < '2021-05-15'
			and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
			and cast(Oppt.Theater__c as nvarchar(50)) != 'Renewals'
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
)

		
/* add the opportunity data to the split opportunity row */
			SELECT	
					Oppt.Id [Oppt Id], Oppt.Name [Opportunity]
					, A.Id [Oppt_Account_Id], A.Name [Oppt_Acct]
					, Split.Acct_Exec
					, Split.SE_Oppt_Owner_SFDC_UserID
					, Oppt.StageName [Stage]
					, Split.Split_Territory_ID

					, case
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 then 'Open'
 						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Won'
						when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then 'Loss'
					end as Oppt_Stage
					
					, case
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 2 then '0-2 Qualify'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 5 then '3-5 Assess'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 then '6-7 Commit'
 						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then '8 Won'
						when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then '8 Loss'
					end as Stage_grp2
					
					, case when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 
					  then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
					  else 0 
					  end as [Open$]
						
					,case 
						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit')
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
						else 0
					end as [Bookings$]		
			
					, case when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then Oppt.Id else '' end as [Won Deal]
					, case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
											 'Stage 8 - Closed/Lost',
											 'Stage 8 - Closed/No Decision', 
											 'Stage 8 - Closed/ Low Capacity')
					  then Oppt.Id else ''
					  end as [Loss Deal]
						
					, case when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 1 else 0
					  end as [Won_Count]
		
					, case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
										 'Stage 8 - Closed/Lost',
										 'Stage 8 - Closed/No Decision', 
										 'Stage 8 - Closed/ Low Capacity')
					  then 1 else 0
					  end as [Loss_Count]
					  
					, Oppt.Stage_Prior_to_Close__c
					, datediff(day, Oppt.CreatedDate, Oppt.CloseDate) [# of days to closed]
					, case when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then datediff(day, Oppt.CreatedDate, Oppt.CloseDate) else null end [# of days to closed won]
					, case when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
											 'Stage 8 - Closed/Lost',
											 'Stage 8 - Closed/No Decision', 
											 'Stage 8 - Closed/ Low Capacity') then datediff(day, Oppt.CreatedDate, Oppt.CloseDate) else null end [# of days to closed loss]
					
					
					, case when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) < 0 then 'Closed b4 Create'
						 when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) = 0 then 'Same day closed'
						 when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) <= 90 then '1 qtr'
						 when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) <= 180 then '2 qtr'
						 when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) <= 270 then '3 qtr'
						 when datediff(day, Oppt.CreatedDate, Oppt.CloseDate) <= 365 then '4 qtr'
						 else 'Over a year'
					end [# of qtr to closed]
					
					, Oppt.Times_Pushed_Out_of_Quarter__c
					, Split.SplitPercentage
					, Split.Currency
					, Split.Amount
					
					/* Because an Opportunity is split into multiple rows based on number of split. Split the 'total' amount so this is not duplicated count */
					, cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) Amount_in_USD
					, cast(Oppt.Total_FlashArray_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_FlashArray_Amount
					, cast(Oppt.Total_FlashBlade_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_FlashBlade_Amount
					, cast(Oppt.Total_Professional_Services_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Professional_Services_Amount
					, cast(Oppt.Total_Training_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Training_Amount
					, cast(Oppt.Total_Credit_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Credit_Amount
					, cast(Oppt.Total_Brocade_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Brocade_Amount
					, cast(Oppt.Total_Cisco_MDS_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Cisco_MDS_Amount
					, cast(Oppt.Total_Cohesity_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Cohesity_Amount					

					, cast((Oppt.Converted_Amount_USD__c - Oppt.Total_FlashArray_Amount__c - Oppt.Total_FlashBlade_Amount__c -
						    Oppt.Total_Professional_Services_Amount__c - Oppt.Total_Training_Amount__c - Oppt.Total_Credit_Amount__c -
						    Oppt.Total_Brocade_Amount__c - Oppt.Total_Cisco_MDS_Amount__c - Oppt.Total_Cohesity_Amount__c)
						    * Split.SplitPercentage / 100 as decimal(15,2)) Total_Misc_Amount
					
					, cast(Oppt.Total_C_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_C_Amount
					, cast(Oppt.Total_X_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_X_Amount
					
					, Oppt.[Type]
					, Oppt.Transaction_Type__c Transaction_Type
					, Split.RecordType
		
					, Oppt.Manufacturer__c Manufacturer
					, Oppt.Product_Type__c
					, Case when Oppt.Manufacturer__c = 'Pure Storage' then Oppt.Product_Type__c else Oppt.Manufacturer__c end Product

					, Oppt.Technical_Win_State__c
					, cast(Oppt.CreatedDate as Date) CreatedDate
					, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
					
					, cast(Oppt.CloseDate as Date) [Close Date]
					, [Fiscal Close Month] = DateFromParts(cast(CloseDate_445.FiscalYear as int), cast(CloseDate_445.FiscalMonth as int), 1)
					, [Fiscal Close Quarter] = 'FY' + right(CloseDate_445.FiscalYear,2)  + ' ' + CloseDate_445.FiscalQuarterName
					, [Fiscal Close Year] = 'FY' + right(CloseDate_445.FiscalYear,2)
					
					, P.Name [Partner]
					, P_AE.Id [Partner_AE_Id], P_AE.Name [Partner_AE]
					, P_SE.Id [Partner_SE_Id], P_SE.Name [Partner_SE]
					, Oppt.Partner_SE_Engagement_Level__c [Partner SE Engagement]
														 ----
					, [TodayKey] = convert(varchar, getDate(), 112)					

			from  #Oppt_Split Split
			left join PureDW_SFDC_Staging.dbo.[Opportunity] Oppt on Oppt.Id = Split.Id
			left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, Oppt.CreatedDate, 112)
			LEFT JOIN PureDW_SFDC_Staging.dbo.[Account] P ON P.Id = Oppt.Partner_Account__c
			left join PureDW_SFDC_staging.dbo.[Contact] P_AE on P_AE.Id = cast(Oppt.Partner_AE_ID__c as varchar)
			left join PureDW_SFDC_staging.dbo.[Contact] P_SE on P_SE.Id = cast(Oppt.Partner_SE_ID__c as varchar)
			left join PureDW_SFDC_staging.dbo.[Account] A on A.Id = Oppt.AccountId