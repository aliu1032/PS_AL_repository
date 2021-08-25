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

/* Geo Quota */
#Geo_M1_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Area,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota_FY22_ANA
	where Measure = 'M1_Quota'
	),
#Geo_FB_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Area,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota_FY22_ANA
	where Measure = 'FB_Quota'
	),

#Geo_Quota as (
	Select #Geo_M1_Quota.[Year], #Geo_M1_Quota.Period, #Geo_M1_Quota.Half_Period, #Geo_M1_Quota.Geo, #Geo_M1_Quota.Area, #Geo_M1_Quota.Region, #Geo_M1_Quota.District,
	#Geo_M1_Quota.Level, #Geo_M1_Quota.Territory_ID, #Geo_M1_Quota.Quota [M1_Quota], #Geo_FB_Quota.Quota [FB_Quota]
	from #Geo_M1_Quota
	left join #Geo_FB_Quota on #Geo_M1_Quota.Territory_ID = #Geo_FB_Quota.Territory_ID and #Geo_M1_Quota.Period = #Geo_FB_Quota.Period
),

/* Per Territory, Territory Qtr Quota, + District + Region + Theater Quota */
#Geo_Quota_Wide as (
		Select R.Territory_ID, DQ.[Year], DQ.Period, DQ.Geo, DQ.Area, DQ.Region, DQ.District
					, TQ.Terr_Qtrly_Quota, TQ.Terr_Qtrly_FB_Quota, TH.Terr_Half_Quota, TH.Terr_Half_FB_Quota, TA.Terr_Annual_Quota, TA.Terr_Annual_FB_Quota
					, DQ.District_Qtrly_Quota, DQ.District_Qtrly_FB_Quota, DH.District_Half_Quota, DH.District_Half_FB_Quota, DA.District_Annual_Quota, DA.District_Annual_FB_Quota
					, RQ.Region_Qtrly_Quota, RQ.Region_Qtrly_FB_Quota, RH.Region_Half_Quota, RH.Region_Half_FB_Quota, RA.Region_Annual_Quota, RA.Region_Annual_FB_Quota
					, SRQ.Area_Qtrly_Quota, SRQ.Area_Qtrly_FB_Quota, SRH.Area_Half_Quota, SRH.Area_Half_FB_Quota, SRA.Area_Annual_Quota, SRA.Area_Annual_FB_Quota
					, GQ.Geo_Qtrly_Quota, GQ.Geo_Qtrly_FB_Quota, GH.Geo_Half_Quota, GH.Geo_Half_FB_Quota, GA.Geo_Annual_Quota, GA.Geo_Annual_FB_Quota

		from (Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota_FY22_ANA where Level = 'Territory' and Period = 'FY'
			  UNION
			  Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota_FY22 where Level = 'District' and Period = 'FY'
			 ) R

		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Area, Region, District,
					      M1_Quota [District_Qtrly_Quota], FB_Quota [District_Qtrly_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('Q1','Q2','Q3','Q4'))
				   DQ on DQ.Territory_ID = substring(R.Territory_ID, 1, 18)
		left join (Select Territory_ID, Period, M1_Quota [District_Half_Quota], FB_Quota [District_Half_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('1H','2H'))
				   DH on DH.Territory_ID = substring(R.Territory_ID, 1, 18) and DH.Period = DQ.Half_Period
		left join (Select Territory_ID, M1_Quota [District_Annual_Quota], FB_Quota [District_Annual_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('FY'))
				   DA on DA.Territory_ID = substring(R.Territory_ID, 1, 18)

   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Area, Region, District,
			      M1_Quota [Terr_Qtrly_Quota], FB_Quota [Terr_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('Q1','Q2','Q3','Q4'))
				  TQ on TQ.Territory_ID = R.Territory_ID and TQ.Period = DQ.Period
   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Area, Region, District,
			      M1_Quota [Terr_Half_Quota], FB_Quota [Terr_Half_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('1H', '2H'))
				  TH on TH.Territory_ID = R.Territory_ID and TH.Period = DQ.Half_Period
   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Area, Region, District,
			      M1_Quota [Terr_Annual_Quota], FB_Quota [Terr_Annual_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('FY'))
				  TA on TA.Territory_ID = R.Territory_ID

		left join (Select Territory_ID, Period, M1_Quota [Region_Qtrly_Quota], FB_Quota [Region_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('Q1','Q2','Q3','Q4'))
				   RQ on RQ.Territory_ID = left(R.Territory_ID, 14) and RQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Half_Quota], FB_Quota [Region_Half_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('1H','2H'))
				   RH on RH.Territory_ID = left(R.Territory_ID, 14) and RH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Annual_Quota], FB_Quota [Region_Annual_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('FY'))
				   RA on RA.Territory_ID = left(R.Territory_ID, 14)

		left join (Select Territory_ID, Period, M1_Quota [Area_Qtrly_Quota], FB_Quota [Area_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Area' and Period in ('Q1','Q2','Q3','Q4'))
				   SRQ on SRQ.Territory_ID = left(R.Territory_ID, 10) and SRQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Area_Half_Quota], FB_Quota [Area_Half_FB_Quota] from #Geo_Quota where Level = 'Area' and Period in ('1H','2H'))
				   SRH on SRH.Territory_ID = left(R.Territory_ID, 10) and SRH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Area_Annual_Quota], FB_Quota [Area_Annual_FB_Quota] from #Geo_Quota where Level = 'Area' and Period in ('FY'))
				   SRA on SRA.Territory_ID = left(R.Territory_ID, 10)

		left join (Select Territory_ID, Period, M1_Quota [Geo_Qtrly_Quota], FB_Quota [Geo_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('Q1','Q2','Q3','Q4'))
				   GQ on GQ.Territory_ID = left(R.Territory_ID, 6) and GQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Half_Quota], FB_Quota [Geo_Half_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('1H','2H')) --WW_EMA_ENC
				   GH on GH.Territory_ID = left(R.Territory_ID, 6) and GH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Annual_Quota], FB_Quota [Geo_Annual_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('FY'))
				   GA on GA.Territory_ID = left(R.Territory_ID, 6)
),

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


	/* Add Quota and RelDate inforamtion */
	Select Oppt.*
	
		/* append the Quota of the Opportunity (split) Territory & Close Date */
	
		, Q.Terr_Qtrly_Quota
		, Q.Terr_Half_Quota
		, Q.Terr_Annual_Quota
	
		--, Q.District
		, Q.District_Qtrly_Quota
		, Q.District_Half_Quota
		, Q.District_Annual_Quota
	
		--, Q.Region
		, Q.Region_Qtrly_Quota
		, Q.Region_Half_Quota
		, Q.Region_Annual_Quota

		--, Q.Area
		, Q.Area_Qtrly_Quota
		, Q.Area_Half_Quota
		, Q.Area_Annual_Quota
	
		--, Q.Geo Theater
		, Q.Geo_Qtrly_Quota Theater_Qtrly_Quota
		, Q.Geo_Half_Quota Theater_Half_Quota
		, Q.Geo_Annual_Quota Theater_Annual_Quota


		/* calculate the relative period */
		, case when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) = 0 then 'This quarter'
			   when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' quarter'
			   when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) as varchar(2)) + ' quarter'
		  end as [Relative_closeqtr]
	  
		, case when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) = 0 then 'This year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) < 0 then 'Last ' + cast(datediff(year, [Fiscal Close Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' year'
			when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) > 0 then 'Next ' + cast(datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Close Month]) as varchar(2)) + ' year'
	  	end as [Relative_closeyear]

		/* calculate the relative period */
		, case when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) = 0 then 'This quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Create Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' quarter'
			when datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) > 0 then 'Next ' + cast(datediff(quarter, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) as varchar(2)) + ' quarter'
		  end as [Relative_createqtr]
	  
		, case when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) = 0 then 'This year'
				when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) < 0 then 'Last ' + cast(datediff(year, [Fiscal Create Month], DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)) as varchar(2)) + ' year'
				when datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) > 0 then 'Next ' + cast(datediff(year, DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1), [Fiscal Create Month]) as varchar(2)) + ' year'
		  end as [Relative_createyear]
	
	from (
			/* add the opportunity data to the split opportunity row */
			SELECT	
					Oppt.Id [Oppt Id], Oppt.Name [Opportunity]
					, Split.Acct_Exec
					, Split.SE_Oppt_Owner_SFDC_UserID
					, Oppt.StageName [Stage]
					, Split.Split_Territory_ID

					, case
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 3 then 'Early Stage'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 5 then 'Adv. Stage'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 then 'Commit'
 						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Won'
						when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then 'Loss'
					end as StageGroup
							
					, case when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 
					  then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
					  else 0 
					  end as [Open$]
			
					, case 
						when cast(substring(Oppt.StageName, 7, 1) as int) < 4
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
						else 0
					end as [Early Stage$]
					
					, case 
						when cast(substring(Oppt.StageName, 7, 1) as int) >= 4 and cast(substring(Oppt.StageName, 7, 1) as int) <= 5
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
						else 0
					end as [Adv. Stage$]
						
					,case 
						when cast(substring(Oppt.StageName, 7, 1) as int) >= 6 and cast(substring(Oppt.StageName, 7, 1) as int) <= 7
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) end
						else 0
					end as [Commit$]
			
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
					
					, Split.SplitPercentage
					, Split.Currency
					, Split.Amount
					
					/* Because an Opportunity is split into multiple rows based on number of split. Split the 'total' amount so this is not duplicated count */
					, cast(Oppt.Converted_Amount_USD__c * Split.SplitPercentage / 100 as decimal(15,2)) Amount_in_USD
					, cast(Oppt.Total_FlashArray_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_FlashArray_Amount
					, cast(Oppt.Total_FlashBlade_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_FlashBlade_Amount
					, cast(Oppt.Total_C_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_C_Amount
					, cast(Oppt.Total_X_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_X_Amount
					, cast(Oppt.Total_Professional_Services_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Professional_Services_Amount
					, cast(Oppt.Total_Brocade_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Brocade_Amount
					, cast(Oppt.Total_Cisco_MDS_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Cisco_MDS_Amount
					, cast(Oppt.Total_Cohesity_Amount__c * Split.SplitPercentage / 100 as decimal(15,2)) Total_Cohesity_Amount					
					
					, Oppt.[Type]
					, Oppt.Transaction_Type__c Transaction_Type
					, Split.RecordType
		
					, Oppt.Manufacturer__c Manufacturer
					, Oppt.Product_Type__c
					, Case when Oppt.Manufacturer__c = 'Pure Storage' then Oppt.Product_Type__c else Oppt.Manufacturer__c end Product

					, cast(Oppt.CreatedDate as Date) CreatedDate
					, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
					
					, cast(Oppt.CloseDate as Date) [Close Date]
					, [Fiscal Close Month] = DateFromParts(cast(CloseDate_445.FiscalYear as int), cast(CloseDate_445.FiscalMonth as int), 1)
					, [Fiscal Close Quarter] = left(Oppt.Close_Fiscal_Quarter__c, 2) 
					, [Fiscal Close Year] = 'FY' + right(Oppt.Close_Fiscal_Quarter__c, 2) 
					, [Close Semi Year] = case when cast(CloseDate_445.FiscalMonth as int) <= 6 then  '1H' else '2H' end
														 ----
					, [TodayKey] = convert(varchar, getDate(), 112)					

			from  #Oppt_Split Split
			left join PureDW_SFDC_Staging.dbo.[Opportunity] Oppt on Oppt.Id = Split.Id
			left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
			left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, Oppt.CreatedDate, 112)

			
	) Oppt
	left join #Geo_Quota_Wide Q on Q.Period = Oppt.[Fiscal Close Quarter] and Q.[Year] = Oppt.[Fiscal Close Year] and Q.Territory_ID = Oppt.Split_Territory_Id
	left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)

