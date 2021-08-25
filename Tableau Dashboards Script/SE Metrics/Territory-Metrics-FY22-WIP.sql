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
/*   Territory Master & Quota            */
/*                                       */
/*****************************************/
With
#L1 AS (
	select ID, [Territory L5] [Hierarchy]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Hierarchy' and [Time] = 'FY22' and ID != ''
),

#L2 AS (
	select ID, [Territory L5] [Theater]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Theater' and [Time] = 'FY22' and ID != ''
),

#L3 AS (
	select ID, [Territory L5] [Area]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Area' and [Time] = 'FY22' and ID != ''
),

#L4 AS (
	select ID, [Territory L5] [Region]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'Region' and [Time] = 'FY22' and ID != ''
),

#L5 AS (
	select ID, [Territory L5] [District]
	from Anaplan_DM.dbo.[Territory Master SQL Export]
	where [Level] = 'District' and [Time] = 'FY22' and ID != ''
),

/* Union the Territory IDs */
#FY19_CFY_Territory as
(
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Territory' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'District' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Region' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Area' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Theater' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], [Time] as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Hierarchy' and [Time] = 'FY22'

		Union

		Select Hierarchy, Theater, Area, Region, District, Territory,
			   Territory_ID [ID], Short_Description, Level, Segment, Type, [Year]
		from SalesOps_DM.dbo.Territory_Quota_FY19_21
		where Period ='FY' and Measure = 'M1_Quota'
		
		Union
		----Assume the FY22 Territories are the same in FY23 ----
				SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Territory' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory], 
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'District' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Region' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Area' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Theater' and [Time] = 'FY22'

		UNION
					
		SELECT #L1.Hierarchy, #L2.Theater, #L3.Area, #L4.Region, #L5.District, null [Territory], -- CFY.[Territory L5] [Territory],
				   CFY.ID, CFY.[Territory L5] [Short_Description], CFY.[Level], CFY.[Territory Segment] [Segment], CFY.[Territory Role Type] [Type], 'FY23' as [Year]
			from Anaplan_DM.dbo.[Territory Master SQL Export] CFY
			left join #L1 on #L1.ID = left(CFY.ID,2)
			left join #L2 on #L2.ID = left(CFY.ID,6)
			left join #L3 on #L3.ID = left(CFY.ID,10)
			left join #L4 on #L4.ID = left(CFY.ID,14)
			left join #L5 on #L5.ID = left(CFY.ID,18)
		where CFY.[ID] != '' and CFY.[Level] = 'Hierarchy' and [Time] = 'FY22'
		-------------------------

),

/* M1 Quota */
#M1_Quota as (
	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		( 
		select ID, [Level], [Q1 FY22], [Q2 FY22], [Q1 FY22] + [Q2 FY22] as [Half_Quota], [FY22] [Annual_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([M1_Quota])
					for
					[Time] in ([Q1 FY22], [Q2 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q1 FY22], [Q2 FY22])
			) as unpvt
			
	UNION

	select ID, [Level], Right(Period_Yr, 4) [Year], Right(Period_Yr, 4) + ' ' + left(Period_Yr,2) [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota]
	from
		( 
		select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q3 FY22] as [Half_Quota], [FY22] [Annual_Quota]
		from
			(
					select ID, [Level], [Time], cast([Position Discrete Quota] as decimal(18,2)) [M1_Quota]
					from Anaplan_DM.dbo.[Territory Master SQL Export]
					where [Time] like '%FY22' and [Position Discrete Quota] not like '%[A-za-z$]%'
					  and ID != ''
					) as SRC
					Pivot
					(sum ([M1_Quota])
					for
					[Time] in ([Q3 FY22], [Q4 FY22], [FY22])
					) as pvt
			) as SRC2
			UNPIVOT
			( [Quota] for [Period_Yr] in ([Q3 FY22], [Q4 FY22])
			) as unpvt

		UNION 
		
		Select [Territory_ID] [ID], [Level], [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q1], [Q2], [Q1]+[Q2] [Half_Quota], [FY] [Annual_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'M1_Quota' and Period in ('Q1','Q2','FY')
--				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q1], [Q2], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q1],[Q2])
			) unpvt
			
		UNION 
		
		Select [Territory_ID] [ID], [Level],  [Year], [Year] + ' ' + [Period] as [Period], [Quota] [Qtrly_Quota], [Half_Quota], [Annual_Quota] from 
			(
			Select [Territory_ID], [Level], [Year], [Q3], [Q4], [Q3]+[Q4] [Half_Quota], [FY] [Annual_Quota] from 
				(
				Select Territory_ID, [Level], Year, Period, cast(Quota as decimal(18,2)) Quota
				from SalesOps_DM.dbo.[Territory_Quota_FY19_21]
				where Measure = 'M1_Quota' and Period in ('Q3','Q4','FY')
--				  and Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
			    ) SRC
			    PIVOT
			    (
			    sum([Quota]) for [Period] in ([Q3], [Q4], [FY])
			    ) as pvt
			) SRC2
			UNPIVOT
			( Quota for [Period] in ([Q3],[Q4])
			) unpvt			

		------------ Insert dummpy for FY23 ----------------------------------
		UNION
		Select ID, [Level], [Year], [Period], cast(Half_Quota as decimal(18,2)) [Half_Quota], cast(Annual_Quota as decimal(18,2)), cast(Qtrly_Quota as decimal(18,2))  from
			(
			Select ID, [Level], [Year], 0 [Half_Quota], 0 [Annual_Quota],
				   0 [FY23 Q1], 0 [FY23 Q2], 0 [FY23 Q3], 0 [FY23 Q4]
			from #FY19_CFY_Territory
			where [Year] = 'FY23' 
			--and ID = 'WW_AMS_COM_CEN_TEN_001'
			) as src
			UNPIVOT
			( [Qtrly_Quota] for [Period] in ([FY23 Q1], [FY23 Q2], [FY23 Q3], [FY23 Q4])
			) as unpvt		
),

#Ter_Master_and_M1_Quota as (
				SELECT convert(varchar, getdate(), 112) Report_date,
					   cast(right(#M1_Quota.[Year],2) as int) - cast(right(Today_FD.FiscalYear,2) as int) as [Rel_Year_from_RptDate],
					   (cast(right(#M1_Quota.[Year],2) as int) * 4 + cast(right(#M1_Quota.[Period],1) as int))
					    - (cast(right(Today_FD.FiscalYear,2) as int) * 4 + cast(Today_FD.FiscalQuarter as int)) [Rel_Qtr_from_RptDate],
		
					   M.Hierarchy, M.Theater, M.Area, M.Region, M.District, M.Territory,
					   M.ID [Territory_ID], M.[Short_Description], M.[Level], M.[Segment], M.[Type],
					   #M1_Quota.[Year], #M1_Quota.[Period], #M1_Quota.[Qtrly_Quota], #M1_Quota.[Half_Quota], #M1_Quota.[Annual_Quota],
					   D.[District_Qtrly_Quota], D.[District_Half_Quota], D.[District_Annual_Quota],
					   R.[Region_Qtrly_Quota], R.[Region_Half_Quota], R.[Region_Annual_Quota],
					   A.[Area_Qtrly_Quota], A.[Area_Half_Quota], A.[Area_Annual_Quota],
					   T.[Theater_Qtrly_Quota], T.[Theater_Half_Quota], T.[Theater_Annual_Quota],
					   H.[Hierarchy_Qtrly_Quota], H.[Hierarchy_Half_Quota], H.[Hierarchy_Annual_Quota]
					   
				from #FY19_CFY_Territory M
				left join #M1_Quota on #M1_Quota.ID = M.ID and #M1_Quota.[Year] = M.[Year]
				left join 
					(select ID, [Year], [Period], Qtrly_Quota District_Qtrly_Quota, Half_Quota District_Half_Quota, Annual_Quota District_Annual_Quota from #M1_Quota where [Level] = 'District') D on D.Id = left(#M1_Quota.Id,18) and D.[Period] = #M1_Quota.[Period] and D.[Year] = #M1_Quota.[Year]
				left join 
					(select ID, [Year], [Period], Qtrly_Quota Region_Qtrly_Quota, Half_Quota Region_Half_Quota, Annual_Quota Region_Annual_Quota from #M1_Quota where [Level] = 'Region') R on R.Id = left(#M1_Quota.Id,14) and R.[Period] = #M1_Quota.[Period] and R.[Year] = #M1_Quota.[Year]
				left join 
					(select ID, [Year], [Period], Qtrly_Quota Area_Qtrly_Quota, Half_Quota Area_Half_Quota, Annual_Quota Area_Annual_Quota from #M1_Quota where [Level] = 'Area') A on A.Id = left(#M1_Quota.Id,10) and A.[Period] = #M1_Quota.[Period] and A.[Year] = #M1_Quota.[Year]
				left join 
					(select ID, [Year], [Period], Qtrly_Quota Theater_Qtrly_Quota, Half_Quota Theater_Half_Quota, Annual_Quota Theater_Annual_Quota from #M1_Quota where [Level] = 'Theater') T on T.Id = left(#M1_Quota.Id,6) and T.[Period] = #M1_Quota.[Period] and T.[Year] = #M1_Quota.[Year]
				left join 
					(select ID, [Year], [Period], Qtrly_Quota Hierarchy_Qtrly_Quota, Half_Quota Hierarchy_Half_Quota, Annual_Quota Hierarchy_Annual_Quota from #M1_Quota where [Level] = 'Hierarchy') H on H.Id = left(#M1_Quota.Id,2) and H.[Period] = #M1_Quota.[Period] and H.[Year] = #M1_Quota.[Year]
				left join NetSuite.dbo.DM_Date_445_With_Past Today_FD on Today_FD.Date_ID = convert(varchar, getdate(), 112)
)


Select *
from #Ter_Master_and_M1_Quota 
where Territory_ID = 'WW_AMS_COM_CEN_TEN_001'



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
					, A.Id [Oppt_Account_Id], A.Name [Oppt_Acct], UL_P.Name [Global Ultimate Parent Account], UL_P.Id [Global Ultimate Parent Acct_ID]
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
			left join PureDW_SFDC_staging.dbo.[Account] UL_P on left(UL_P.Id, 15) = cast(A.Ultimate_Parent_Id__c as varchar) COLLATE SQL_Latin1_General_CP1_CS_AS