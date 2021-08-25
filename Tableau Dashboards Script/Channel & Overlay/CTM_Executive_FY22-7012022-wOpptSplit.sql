/***************************************************************************/
/***                                                                     ***/
/***    Root:                                                            ***/
/***                                                                     ***/
/***    Account                                                          ***/
/***                                                                     ***/
/***************************************************************************/

#Account

With
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
)

Select Acc.Id [Partner Id], Acc.Name [Partner Name], Acc.Theater__c [Partner Theater], 
       PTM.Name [Partner PTM],
       SE.Manager [PTM Manager],
       case when SE.Manager = 'Mark Hirst' then 'America'
       		when SE.Manager = 'Markus Wolf' then 'EMEA'
       		when SE.Manager = 'Shuichi Nanri' then 'JP'
       		when SE.Manager = 'Karen Hoong' then 'APJ'
       		else NULL
       end [PTM Theater],
      case when Partner_Tier__c is null or Partner_Tier__c = 'None' then 'None'
       else Partner_Tier__c end [Partner Tier],
       [Type] [Partner Type]
--       ,APSP__c

from PureDW_SFDC_Staging.dbo.Account Acc
left join PureDW_SFDC_Staging.dbo.[User] PTM on PTM.Id = Acc.Channel_Technical_Manager__c
left join [GPO_TSF_Dev ].dbo.vSE_Org SE on SE.EmployeeID = PTM.EmployeeNumber
where Acc.Id in (
			Select Id 
			from PureDW_SFDC_staging.dbo.Account
			where Type in ('Reseller','Distributor')
			
			Union
			
			Select O.Partner_Account__c
			from PureDW_SFDC_staging.dbo.[Opportunity] O
			where O.Id in (select * from #Select_Oppt)
)

/***************************************************************************/
/***                                                                     ***/
/***    Based                                                            ***/
/***                                                                     ***/
/***    Contact who is Partner SE Role                                   ***/
/***    or                                                               ***/
/***    Appeal in Partner SE field on                                    ***/
/***    Sales Opportunity & ES2, closed since FY20                       ***/
/***                                                                     ***/
/***************************************************************************/

With
/***** Contact who we are interested ****/
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
),


#Report_Contact as (
		Select C.Id 
		from PureDW_SFDC_Staging.dbo.[Contact] C
		left join PuredW_SFDC_staging.dbo.[Account] P on P.Id = C.AccountId
		where P.Type in ('Reseller','Distributor')
		and C.Role_Type__c in ('Partner SE') or C.Participate_in_Wavemaker_programme__c = 'Yes'
		
		Union
		
		Select distinct(O.Partner_SE__c) [Id]
		from PureDW_SFDC_staging.dbo.Opportunity O
		where O.Id in (select * from #Select_Oppt)
)


Select C.Id [Contact_Id], Owner.Name [Contact Owner], C.IsDeleted, C.Owner_Is_Active__c
  	 , C.Name [Contact], C.Role_Type__c [Assigned Role], C.Email [Contact Email]
  	 , case when C.Participate_in_Wavemaker_programme__c = 'Yes' then 'Yes' else null end [Wavemaker Participtant]
  	 , C.Wavemaker_level__c [Wavemaker level]
  	 , C.AccountId [Partner Id]
  	 --, C_Acct.Name [Partner Name], C_Acct.Theater__c [Partner Theater], P_CTM.Name [Partner PTM]
  	 --, case when C_Acct.Partner_Tier__c is null or C_Acct.Partner_Tier__c = 'None' then 'None'
  	 --  else C_Acct.Partner_Tier__c end [Partner Tier]
  	 --, C_Acct.Type [Partner Type] 
  	 , C_CTM.Name [Contact PTM]
     , C.MailingCity [Contact City]
     , coalesce(C.MailingState, ' ') as [Contact State], C.MailingPostalCode [Contact PostalCode]
     , coalesce(C.MailingCountry, ' ') as [Contact Country]
     , left(C_User.Id,15) [Contact_UserId]
     , ROW_NUMBER() over (partition by C.Email order by C.CreatedDate desc) RN
     , C.CreatedDate
from PureDW_SFDC_staging.dbo.[Contact] C
--left join PureDW_SFDC_Staging.dbo.[Account] C_Acct on C_Acct.Id = C.AccountId
--left join PureDW_SFDC_Staging.dbo.[User] P_CTM on P_CTM.Id = C_Acct.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] C_CTM on C_CTM.Id = C.Channel_Technical_Manager__c
left join PureDW_SFDC_Staging.dbo.[User] Owner on Owner.Id = C.OwnerId
left join PureDW_SFDC_Staging.dbo.[User] C_User on C_User.ContactId = C.Id
where C.Id in (Select * from #Report_Contact)
  and C.IsDeleted = 'False'
  and C.Email = 'jawad.butt@onx.com'
--and C_Acct.Name != 'HIDDEN'




/************************************/
/* Opportunity                      */
/************************************/
WITH
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
),

#Oppt_Split as (
			/* a copy of the original deals */
			/* cannot determine a SE opportunity owner using split. An AE may be supported by a pool of SEs */
			Select Oppt.Id
				, OpptSplit.Id [SplitRec_Id]
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, case when Oppt.OwnerId = OpptSplit.SplitOwnerId and OpptSplit.SplitPercentage = 100 then 'No Split'
					   when Oppt.OwnerId = OpptSplit.SplitOwnerId and OpptSplit.SplitPercentage < 100 then 'Split Orign'
					   else 'Split' end [Split_Way]
				, Split_Acct_Exec.Name Acct_Exec

				/* Use the Territory value from split */
				, case when OpptSplit.Override_Territory__c is null then OpptSplit.Territory_ID__c else OpptSplit.Override_Territory__c end Split_Territory_ID
				, case when OpptSplit.Override_Territory__c is null then left(OpptSplit.Territory_ID__c,18) else left(OpptSplit.Override_Territory__c,18) end Split_District_ID

				, cast(OpptSplit.SplitPercentage/100 as decimal(5,2)) as [SplitPercentage]
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is counted towards raw bookings for comp calculation
				, OpptSplit.Split_Commissionable_Amount_Net_USD__c [Commissionable_Amount_in_USD]

				, RecType.Name RecordType
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Split_Acct_Exec on  Split_Acct_Exec.Id = OpptSplit.SplitOwnerID				--left join #AE_Coverage AE_Coverage on AE_Coverage.EmployeeID = Acct_Exec.EmployeeNumber
				
			where Oppt.Id in (Select * from #Select_Oppt) 
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
),
--select * from #Oppt_Split
--where Id = '0064W00000yviRtQAI'

#Partner_Oppt_Count as (
		Select Partner_Account__c, count(Partner_Account__c) [Partner Oppt Count]
		from PureDW_SFDC_staging.dbo.Opportunity O
		where O.Id in (select * from #Select_Oppt)
		  and Converted_Amount_USD__c > 0
		group by Partner_Account__c
),


#Quote_Count (Oppt_Id, Quote_Created_Count, Partner_Quote_Created_Count)
as (
	Select [Oppt Id], count([Quote Id]) [Count Quotes Created], sum([Partner_Created_Quote]) [Count Partner Created Quote]
	from (
		Select Q.Id [Quote Id], Q.Name [Quote Name], Q.SBQQ__Opportunity2__c [Oppt Id], Q.CPQ_Opportunity_Name__c, Q.SBQQ__Primary__c, Q.Theater__c,
		Q.CPQ_Community_Quote__c, Case when Q.CPQ_Community_Quote__c = 'True' then 1 else 0 end [Partner_Created_Quote],
		case when CB.Email like '%purestorage.com' then 1 else 0 end [Created by PTSG doman],
		CB.Name [Quote CreatedBy], CB.Email [Quote Creator Email]
		
		from PureDW_SFDC_Staging.dbo.SBQQ__Quote__c Q
		left join PureDW_SFDC_Staging.dbo.[User] CB on CB.Id = Q.CreatedById
	) t
	group by [Oppt Id]
),

#Oppt_MDE_Solution_Translate as (
	/* group the rows by Id + MDE_Solution Use Case */
	select Id, MDE_Solution--, count(*) [count]-- ROW_NUMBER() over (partition by Id, MDE_Solution order by Id, MDE_Solution) [ROW]
	from (
		/* translate solution use case into MDE use case */
		select Oppt.Id, MDE.MDE_Solution, ROW_Number() over (PARTITION by Oppt.Id, MDE.MDE_Solution order by Oppt.Id, MDE.MDE_Solution) [Row]
			from (
				/* split up Solution Use Case into rows */
				select Id, Solution_Use_Case__c, value [Solution_Use_Case]
				from PureDW_SFDC_Staging.dbo.Opportunity
				CROSS APPLY STRING_SPLIT(cast(Solution_Use_Case__c as varchar(2000)), ';')
				where CreatedDate >= '2018-02-01'
			) Oppt
		left join SalesOps_DM.dbo.CTM_MDE_Solution_Map MDE on MDE.Solution_Use_Case = Oppt.Solution_Use_Case
	) a where [ROW] = 1
	group by Id, MDE_Solution
),

#Oppt_MDE_Solution as (
	select Id, 
		STUFF((select '; ' + MDE_Solution
			   from #Oppt_MDE_Solution_Translate
			   where Id = B.Id
			   order by Id, MDE_Solution
			   for XML PATH(''),Type).value('(./text())[1]','Varchar(Max)'), 1,2, '') as Solution
		from #Oppt_MDE_Solution_Translate B
	group by Id
),

#Multi_Oppt as (   /* number of Opportunity > $0 that this Partner has */
	select Partner_Account__c, AccountId, Multi_Oppt_on_Date, Partner_ToDate_Oppt_Count,
	case when RN = 1 then 'F' else 'T' end [Multi-Oppt_TF], -- equals T on the 2nd opportunity of a Partner + Account
	case when RN = 1 then 0 else 1 end [Multi-Oppt]
	from (
			select Id, Name, Partner_Account__c, AccountId, cast(CreatedDate as date) Multi_Oppt_on_Date,
				   row_number() over (partition by Partner_Account__c, AccountId order by CreatedDate) RN,
				   count(id) over (partition by Partner_Account__c, AccountId) Partner_ToDate_Oppt_Count
			from PureDW_SFDC_Staging.dbo.Opportunity
			where Partner_Account__c is not null
			and (Amount > 0)
	) a where (RN = 1 and Partner_ToDate_Oppt_Count = 1) or (RN=2) --get the 1st and the 2nd deals of a Partner + Account
),

#Multi_Won as (  /* number of Opportunity Won that this Partner has for a customer */
	Select Partner_Account__c, AccountId, Multi_Won_On_Date, Partner_ToDate_Won_Count, RN,
		   case when RN = 1 then 'F' else 'T' end [Multi-Won_TF],
		   case when RN = 1 then 0 else 1 end [Multi-Won]
	from (
			select Id, Name, Partner_Account__c, AccountId, cast(CloseDate as date) Multi_Won_On_Date, StageName,
				   row_number() over (partition by Partner_Account__c, AccountId order by CloseDate) RN,
				   count(id) over (partition by Partner_Account__c, AccountId) Partner_ToDate_Won_Count
			from PureDW_SFDC_Staging.dbo.Opportunity
		  where Partner_Account__c is not null
			and StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit')
			and Amount > 0
	) a where (RN = 1 and Partner_ToDate_Won_Count = 1) or (RN = 2)
),

#CSC_PoC as (
	select Opp_Id, [Number] [CSC PoC Number], State [CSC PoC State], created_at_date [CSC PoC CreatedDate], [SE First Name] + ' ' + [SE Last Name] [SE Requested CSC]
	from (
			select [SE First Name], [SE Last Name], [Email Address], Opp_ID, State, Number, created_at_Date,
				   ROW_NUMBER() over (partition by Opp_Id order by created_at_Date desc) rn
			from Datascience_Workbench_Views.dbo.v_csc_poc_clean
			where Opp_ID is not null
		  ) a where a.rn = 1
),

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
		select ID, [Level], [Q3 FY22], [Q4 FY22], [Q3 FY22] + [Q4 FY22] as [Half_Quota], [FY22] [Annual_Quota]
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

----------------------------
Select
	Ter_Master.Hierarchy, Ter_Master.Theater, Ter_Master.Area, Ter_Master.Region, Ter_Master.District, Ter_Master.Territory,
	Ter_Master.Theater_Qtrly_Quota, Ter_Master.Theater_Annual_Quota,
	Ter_Master.Area_Qtrly_Quota, Ter_Master.Area_Annual_Quota,
	Ter_Master.Region_Qtrly_Quota, Ter_Master.Region_Annual_Quota,
	Ter_Master.District_Qtrly_Quota, Ter_Master.District_Annual_Quota,
	
	Oppt.*,
	
	datediff(year, [Current Fiscal Month], [Fiscal Close Month])  [Relative_CloseYear],
	datediff(quarter, [Current Fiscal Month], [Fiscal Close Month]) [Relative_CloseQtr],
	datediff(month, [Current Fiscal Month], [Fiscal Close Month]) [Relative_CloseMonth]
	
	from #Ter_Master_and_M1_Quota Ter_Master
	left join ( /*List of Opportunity Split */
				Select	OS.SplitRec_Id,				
					O.Id [Oppt Id], O.Name [Opportunity], EU_Acct.Name [Account], EU_Acct.Id [Oppt_AccountId],
					O.Product_Type__c [Product], O.Manufacturer__c [Mfg], O.[Type], Rec.Name [Oppt RecType],
					
				    case
						when (O.Manufacturer__c = '' or O.Manufacturer__c is null) then 'Product not reported'
						when (O.Manufacturer__c = 'Pure Storage') then 
							 case when (O.Product_Type__c = 'FlashBlade') then 
							 case when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
								  when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
								  when O.Environment_detail__c in ('Analytics & AI', 'HPC & Technical Computing', 'Media & Entertainment', 'DB', 'Health Care') then 'Activate Real-Time Analytics and AI'
									   else 'Use case not reported'
								  end
								  when (O.Product_Type__c = 'FlashArray') then
									   case when O.Environment_detail__c in ('DB', 'Healthcare') then 'Accelerate Core Applications'
											when O.Environment_detail__c in ('Hybrid Cloud') then 'Hybrid Cloud'
											when O.Environment_detail__c in ('Data Protection') then 'Modernization Data Protection'
											when O.Environment_detail__c in ('Analytics & AI', 'HPC & Technical Computing', 'Media & Entertainment') then 'Activate Real-Time Analytics and AI'
											else 'Use case not reported'
								  end
					    	else 'Product Not reported'
							end
						 else O.Manufacturer__c
					end [Solution],
					
					--O.Theater__c [Theater], O.Sub_Division__c [Sub_Division], O.Division__c [Division],
					O.StageName,
					O.Stage_Prior_to_Close__c [Stage Prior to Close],
					
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 then O.Id else null end Won_Deal,
					case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then O.Id else null end Loss_Deal,
					case when cast(substring(O.StageName,7,1) as int) < 8  then O.Id else null end Open_Deal,
					case when cast(substring(O.StageName,7,1) as int) = 8 then O.Id else null end Close_Deal,
					
					case 
					 	 when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
					 	 when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then 'Loss'
						 else 'Open'
					end [StageGroup],
					
					
					case
						when cast(substring(O.StageName,7,1) as int) <= 2 then '0-2 Qualify'
						when cast(substring(O.StageName,7,1) as int) <= 5 then '3-5 Assess'
						when cast(substring(o.StageName,7,1) as int) <= 7 then '6-7 Commit'
						when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then '8 Won'
						when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then '8 Loss'
					end [StageGroup2],
									
					--O.CurrencyIsoCode, O.Amount, O.Converted_Amount_USD__c [Amount_in_USD],
					OS.Currency, OS.Amount, OS.SplitPercentage,
					O.Converted_Amount_USD__c [Full_Oppt_Amount_in_USD],
					cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(18,2)) [Amount_in_USD],
					OS.Split_way,
					OS.[Commissionable_Amount_in_USD],
					
					OS.Split_Territory_ID,
					OS.Split_District_ID,
					
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) else 0 end as Booking$,
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then OS.[Commissionable_Amount_in_USD] else 0 end as [Commissionable_Booking$],
					case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') then cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) else 0 end as Loss$,
		
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and 
							  O.Partner_Sourced__c = 'true' then cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) else 0 end as [PSourced Booking$],
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and 
							  O.Partner_Sourced__c = 'true' then OS.[Commissionable_Amount_in_USD] else 0 end as [PSourced Commissionable Booking$],
							  
					case when O.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision', 'Stage 8 - Closed/ Low Capacity') and
							  O.Partner_Sourced__c = 'true' then cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) else 0 end as [PSourced Loss$],
					
					O.Partner_Sourced__c [Partner Sourced], O.Channel_Led_Deal__c [CLed],
		--			case when O.Channel_Led_Deal__c = 'true' then 1 else 0 end [CLed Deal 1/0],
		--			case when O.Partner_Sourced__c = 'true' then 1 else 0 end [Partner Sourced 1/0], --when CAM convert a Partner registrated oppt to a SFDC oppt, the checkbox is checked
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_Account__c is not null then O.Partner_Account__c else null end [Won Partner],
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_AE__c != O.Partner_SE__c and O.Partner_SE__c is not null then O.Partner_SE__c else null end [Won Partner SE],
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Converted_Amount_USD__c > 0 and O.Partner_Sourced__c = 'true' then O.Partner_Account__c else null end [Won P-Sourced Partner],
					case when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') and O.Partner_Sourced__c = 'true' then O.Id else null end [Won P-Sourced Opportunity],
					
					O.Partner_SE_Contribution__c [Partner SE Contribution],
					O.Partner_SE_Engagement_Level__c [Partner SE Engagement],
					case when O.Technical_Win_State__c = 'Losing' then 'Disadvantaged' 
						 when O.Technical_Win_State__c = 'Neutral' then 'No Differentiation'
						 when O.Technical_Win_State__c = 'Strong' then 'Differentiated'
						 else O.Technical_Win_State__c
					end [Technical Win State],
					O.Environment_detail__c [Use Case],
					
					POC.Id [POC Id],
					POC.Eval_Stage__c [Eval Stage],
					--case when POC.Eval_Stage__c is null then 'false' else 'true' end [Customer_Site_POC_Used T/F],
					case when POC.Ship_Date__c is null then 'false' else 'true' end [Customer_Site_POC_Used T/F],
					POC.Customer_Site_PoC__c,
					CSC.[CSC PoC Number],
					case when CSC.[CSC PoC Number] is null then 'false' else 'true' end [CSC_POC_Used T/F],
			
					QC.Quote_Created_Count, 
					QC.Partner_Quote_Created_Count,
					Case when QC.Partner_Quote_Created_Count > 0 then 1 else 0 end [Partner created quote 1/0],
						
					O.Partner_AE__c [Partner AE], O.Partner_SE__c [Partner SE Id],
					Partner_SE.Name [Partner SE], Partner_SE.Wavemaker_level__c [Wavemaker level],
			  	    case when Partner_SE.Participate_in_Wavemaker_programme__c = 'Yes' then 'Yes' else null end [Wavemaker Participtant],
			  	    
					-- the Partner listed on an Opportunity
					case when O.Partner_Account__c is null then 0 else 1 end [Oppt has Partner],
					O.Partner_Account__c [Partner Id], P.Name [Partner Name],
					case when P_Oppt_Cnt.[Partner Oppt Count] = 1 then O.Partner_Account__c else null end [Partner 1st oppt],
					
					case when P.Partner_Tier__c is null or P.Partner_Tier__c = 'None' then 'None'
					else P.Partner_Tier__c end [Partner Tier],
					P.Type [Partner Type],  /* User Oppt.Partner Account. Impact the Partner SE may be grouped into a different account, the Partner SE count could impacted */
--					P.Theater__c [Partner Theater], P.Sub_Division__c [Partner SubDivision],
/*---					PTM.Name [Partner PTM],
			        case when SE.Manager = 'Mark Hirst' then 'America'
			       		 when SE.Manager = 'Markus Wolf' then 'EMEA'
			       		 when SE.Manager = 'Shuichi Nanri' then 'JP'
			       		 when SE.Manager = 'Karen Hoong' then 'APJ'
			       		 else NULL
			        end [PTM Theater],
*/					
					-- the Distributor listed on an Opportunity			
					case when O.Partner_Account__c is null then 0 else 1 end [Oppt has Disti],
					O.Distributor_Account__c, Dist.Name [Disti],
					--Dist.Ultimate_Parent_Id__c [UL Id],  /* use the mapping provided by Scott Dedmen */
			
					case when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is null) then 'Other'
						 when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is not null) then Dist_UL.[Disti]
				 		 else null
					end as [Parent Disti],
					
					case when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is null) then 'Other'
						 when (O.Distributor_Account__c is not null and Dist_UL.[Disti] is not null) then Dist_UL.[Theater]
						 else null
					end as [Parent Disti Theater],
					
					cast(O.CreatedDate as Date) CreatedDate,
					DateFromParts(cast(substring(CreateDate_445.FiscalMonthKey,1,4) as int), cast(substring(CreateDate_445.FiscalMonthKey,5,2) as int),1) [Fiscal Created Month],
					'FY' + right(CreateDate_445.FiscalYear,2) [Fiscal Create Year],
					'FY' + right(CreateDate_445.FiscalYear,2) + ' ' + CreateDate_445.FiscalQuarterName [Fiscal Created Quarter], 
			
					cast(O.CloseDate as Date) CloseDate,
					DateFromParts(CloseDate_445.FiscalYear, CloseDate_445.FiscalMonth, 1) [Fiscal Close Month],
					dateadd(month, 1, DateFromParts(CloseDate_445.FiscalYear, CloseDate_445.FiscalMonth, 1)) [Fiscal Close Month Label],
					'FY' + right(CloseDate_445.FiscalYear,2) [Fiscal Close Year],
					'FY' + right(CloseDate_445.FiscalYear,2) + ' '+ CloseDate_445.FiscalQuarterName [Fiscal Close Quarter],
					--'FY' + right(cast(O.Fiscal_Year__c as varchar),2) [Fiscal Close Year], /* SFDC Fiscal values are not 445 value */
					--'FY'+ right(cast(O.Fiscal_Year__c as varchar),2) + ' ' + left(O.Close_Fiscal_Quarter__c,2) [Fiscal Close Quarter],
					
					DateFromParts(Year(DateAdd(month, 11, GetDate())), Month(DateAdd(month, 11, GetDate())), 1) as [Current Fiscal Month]
								
					, MO.Multi_Oppt_on_Date
					, Case when MO.Partner_ToDate_Oppt_Count is null then 0 else MO.Partner_ToDate_Oppt_Count end Partner_ToDate_Oppt_Count
					, Case when MO.[Multi-Oppt_TF] is null then 'F' else MO.[Multi-Oppt_TF] end [Multi-Oppt_TF]
					, Case when MO.[Multi-Oppt] is null then 0 else MO.[Multi-Oppt] end [Multi-Oppt]
			
					, MW.Multi_Won_On_Date
					, Case when MW.Partner_ToDate_Won_Count is null then 0 else MW.Partner_ToDate_Won_Count end Partner_ToDate_Won_Count
					, Case when MW.[Multi-Won_TF] is null then 'F' else MW.[Multi-Won_TF] end [Multi-Won_TF]
					, Case when MW.[Multi-Won] is null then 0 else MW.[Multi-Won] end [Multi-Won]
				
		--			from PureDW_SFDC_Staging.dbo.Opportunity O
					from #Oppt_Split OS
					left join PureDW_SFDC_staging.dbo.[Opportunity] O on O.Id = OS.Id
					left join PureDW_SFDC_Staging.dbo.RecordType Rec on Rec.Id = O.RecordTypeId
					
					left join PureDW_SFDC_Staging.dbo.Account P on P.Id = O.Partner_Account__c
					left join #Partner_Oppt_Count P_Oppt_Cnt on P_Oppt_Cnt.Partner_Account__c = O.Partner_Account__c
--					left join PureDW_SFDC_staging.dbo.[User] PTM on PTM.Id = P.Channel_Technical_Manager__c
--					left join [GPO_TSF_Dev ].dbo.vSE_Org SE on SE.EmployeeID = PTM.EmployeeNumber
					
					left join PureDW_SFDC_Staging.dbo.[Contact] Partner_SE on Partner_SE.Id = O.Partner_SE__c
					left join PureDW_SFDC_Staging.dbo.Account Dist on Dist.Id = O.Distributor_Account__c
					left join SalesOps_DM.dbo.CTM_Disti_Map Dist_UL on Dist_UL.Child_Account_Id = O.Distributor_Account__c
								
					left join PureDW_SFDC_Staging.dbo.Account EU_Acct on EU_Acct.Id = O.AccountId
					
					left join PureDW_SFDC_Staging.dbo.POC__c POC on POC.Opportunity__c = O.Id
					left join #CSC_POC CSC on CSC.Opp_Id = O.Id
			
					left join #Quote_Count QC on QC.Oppt_Id = O.Id
					left join #Oppt_MDE_Solution Sol on Sol.Id = O.Id
					
					left join #Multi_Oppt MO on MO.Partner_Account__c = O.Partner_Account__c and MO.AccountId = O.AccountId
					left join #Multi_Won MW on MW.Partner_Account__c = O.Partner_Account__c and MW.AccountId = O.AccountId
			
					left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, O.CloseDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, O.CreatedDate, 112)
					left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, GetDate(), 112)
								
					where O.Id in (Select * from #Select_Oppt)
					--and O.Partner_Account__c is not null  --- Selecting Capax and PaaS Oppt where Partner Account is stamped
		) Oppt on Ter_Master.[Territory_ID] = Oppt.Split_Territory_ID and Ter_Master.[Year] = Oppt.[Fiscal Close Year] and Ter_Master.[Period] = Oppt.[Fiscal Close Quarter]
		where Oppt.[Fiscal Close Year] = 'FY23' and Oppt.Split_Territory_ID = 'WW_AMS_COM_NEA_CPK_001' 
		--where Oppt.[Oppt Id] = '0064W00000xfiiaQAA'-- '0064W00000yviRtQAI'

/****************************************************/
/* Opportunity Portfolio breakdown using Oppt Split */
/****************************************************/ 
WITH
#Select_Oppt as (
	Select O.Id
	from PureDW_SFDC_staging.dbo.Opportunity O
	left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
	where RecT.Name in ('Sales Opportunity','ES2 Opportunity')
	  and cast(O.Theater__c as varchar) != 'Renewals'
	  and O.CloseDate >= '2018-02-01' 
),

#Oppt_Split as (
			/* a copy of the original deals */
			/* cannot determine a SE opportunity owner using split. An AE may be supported by a pool of SEs */
			Select Oppt.Id
				, OpptSplit.Id [SplitRec_Id]
				, OpptSplit.SplitOwnerId Acct_Exec_SFDC_UserID
				, Oppt.SE_Opportunity_Owner__c SE_Oppt_Owner_SFDC_UserID
				, case when Oppt.OwnerId = OpptSplit.SplitOwnerId and OpptSplit.SplitPercentage = 100 then 'No Split'
					   when Oppt.OwnerId = OpptSplit.SplitOwnerId and OpptSplit.SplitPercentage < 100 then 'Split Orign'
					   else 'Split' end [Split_Way]
				, Split_Acct_Exec.Name Acct_Exec

				/* Use the Territory value from split */
				, case when OpptSplit.Override_Territory__c is null then OpptSplit.Territory_ID__c else OpptSplit.Override_Territory__c end Split_Territory_ID
				, case when OpptSplit.Override_Territory__c is null then left(OpptSplit.Territory_ID__c,18) else left(OpptSplit.Override_Territory__c,18) end Split_District_ID

				, cast(OpptSplit.SplitPercentage/100 as decimal(5,2)) SplitPercentage
				, OpptSplit.CurrencyIsoCode Currency
				, OpptSplit.SplitAmount Amount  -- Split amount is counted towards raw bookings for comp calculation

				, RecType.Name RecordType
				
			from PureDW_SFDC_Staging.dbo.Opportunity Oppt
				left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
				left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
				left join [PureDW_SFDC_staging].[dbo].[User] Split_Acct_Exec on  Split_Acct_Exec.Id = OpptSplit.SplitOwnerID				--left join #AE_Coverage AE_Coverage on AE_Coverage.EmployeeID = Acct_Exec.EmployeeNumber
				
			where Oppt.Id in (Select * from #Select_Oppt) 
			and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
			and OpptSplit.IsDeleted = 'False'
)


/** Product Category mimic Clari  
 *  Portfolio is how PTM/PTD wants to look at */
select * from (
-- OpEX Opportunity
Select OS.SplitRec_Id, 
	   O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName,
	   
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Amount_in_USD],
	   Case when (CBS_Category__c is not null and CBS_Category__c != 'NO CBS') then 'CBS'
	   		when O.Transaction_Type__c in ('Debook','ES2 Initial Deal','ES2 Reserve Expansion','ES2 Billing','ES2', 'ES2 Renewal') then 'PaaS'
	   		else 'Misc.' end [Portfolio],
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Portfolio_Amount_in_USD], 
	   
	   Case when O.Transaction_Type__c in ('Debook','ES2 Initial Deal','ES2 Reserve Expansion','ES2 Billing', 'ES2 Renewal') then 'PaaS' else 'Misc.' end [Product],
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Product_Amount_in_USD]
	   
from #Oppt_Split OS
Left join PureDW_SFDC_staging.dbo.Opportunity O on O.Id = OS.Id
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('ES2 Opportunity')

UNION

-- Capex
/* if Opportunity do not have product detail, then use the Manufacturer and Product value to classify the amount */  
Select  OS.SplitRec_Id,
		O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName, 
		
		cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Amount_in_USD],
	    Case when O.Manufacturer__c != 'Pure Storage' and O.Manufacturer__c is not null then O.Manufacturer__c
	   	     when O.Manufacturer__c = 'Pure Storage' and O.Product_Type__c = 'FlashArray' then NULL
	   	     when O.Manufacturer__c = 'Pure Storage' and O.Product_Type__c = 'FlashBlade' then O.Product_Type__c
	   	    else 'Unknown'
	   end [Portfolio],

	   0 [Portfolio_Amount_in_USD],
	   Case when O.Manufacturer__c != 'Pure Storage' and O.Manufacturer__c is not null then O.Manufacturer__c
	   	    When O.Manufacturer__c = 'Pure Storage' then O.Product_Type__c
	   	    else 'Unknown'
	   end [Product],
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Product_Amount_in_USD]
	   
from #Oppt_Split OS
Left join PureDW_SFDC_staging.dbo.Opportunity O on O.Id = OS.Id
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('Sales Opportunity') and (O.Count_of_Products__c is null or O.Count_of_Products__c = 0)

UNION

/* insert another FA line for Portfolio amount */
Select OS.SplitRec_Id,
	   O.Id [Oppt_Id], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName,
	   
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Amount_in_USD],

	   Case when O.Product_Type__c = 'FlashArray' then 'FA-Other' end [Portfolio],
	   cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Portfolio_Amount_in_USD], 
	   null as [Product], 0 [Product_Amount_in_USD]

from #Oppt_Split OS
Left join PureDW_SFDC_staging.dbo.Opportunity O on O.Id = OS.Id
Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
where RecT.Name in ('Sales Opportunity') and (O.Count_of_Products__c is null or O.Count_of_Products__c = 0)

/* FlashArray Amount = FA-X + FA-C + FA-Other. Don't double count the amount */
UNION

-- CapEx Opportunity which has product details
Select SplitRec_Id,
	   Oppt_Id, [Oppt RecType], [CBS_Category__c], Manufacturer__c, Product_Type__c, StageName,
	   [Amount_in_USD],

	   case when [upvt_Portfolio_Col] = 'Total_C_Amount__c' then 'FA-C'
			when [upvt_Portfolio_Col] = 'Total_X_Amount__c' then 'FA-X'
			when [upvt_Portfolio_Col] = 'Total_FA_Other_Amount' then 'FA-Other'
			--when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 'FlashArray'
			when [upvt_Portfolio_Col] = 'Total_FlashBlade_Amount__c' then 'FlashBlade'
			when [upvt_Portfolio_Col] = 'Total_Cisco_MDS_Amount__c' then 'Cisco MDS'
			when [upvt_Portfolio_Col] = 'Total_Cohesity_Amount__c' then 'Cohesity'
			when [upvt_Portfolio_Col] = 'Total_Brocade_Amount__c' then 'Brocade'
			when [upvt_Portfolio_Col] = 'Total_Professional_Services_Amount__c' then 'Professional Services'
		 	when [upvt_Portfolio_Col] = 'Total_Training_Amount__c' then 'Training'
		 	when [upvt_Portfolio_Col] = 'Total_Credit_Amount__c' then 'Credit'
		 	when [upvt_Portfolio_Col] = 'Total_Misc_Amount' then 'Misc.'
		end [Portfolio],

		case when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 0
			 else upvt_Amt_USD
		end [Portfolio_Amt_USD],

		case --when [upvt_Portfolio_Col] = 'Total_C_Amount__c' then 'FA-C'
			--when [upvt_Portfolio_Col] = 'Total_X_Amount__c' then 'FA-X'
			--when [upvt_Portfolio_Col] = 'Total_FA_Other_Amount' then 'FA-Other'
			when [upvt_Portfolio_Col] = 'Total_FlashArray_Amount__c' then 'FlashArray'
			when [upvt_Portfolio_Col] = 'Total_FlashBlade_Amount__c' then 'FlashBlade'
			when [upvt_Portfolio_Col] = 'Total_Cisco_MDS_Amount__c' then 'Cisco MDS'
			when [upvt_Portfolio_Col] = 'Total_Cohesity_Amount__c' then 'Cohesity'
			when [upvt_Portfolio_Col] = 'Total_Brocade_Amount__c' then 'Brocade'
			when [upvt_Portfolio_Col] = 'Total_Professional_Services_Amount__c' then 'Professional Services'
		 	when [upvt_Portfolio_Col] = 'Total_Training_Amount__c' then 'Training'
		 	when [upvt_Portfolio_Col] = 'Total_Credit_Amount__c' then 'Credit'
		 	when [upvt_Portfolio_Col] = 'Total_Misc_Amount' then 'Misc.'
		end [Product],
		
		case when [upvt_Portfolio_Col] in ('Total_C_Amount__c','Total_X_Amount__c','Total_FA_Other_Amount') then 0
			 else upvt_Amt_USD
		end [Product_Amt_USD]
from 
	(
		Select OS.SplitRec_Id,
				O.Id [Oppt_Id], O.Name [Oppt], RecT.Name [Oppt RecType], O.CBS_Category__c, O.Manufacturer__c, O.Product_Type__c, O.StageName,
				
		    	cast(O.Converted_Amount_USD__c * OS.SplitPercentage as decimal(15,2)) [Amount_in_USD],

		    	cast(OS.SplitPercentage * O.Total_Cisco_MDS_Amount__c as decimal(15,2)) as Total_Cisco_MDS_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_Cohesity_Amount__c as decimal(15,2)) as Total_Cohesity_Amount__c,
       			cast(OS.SplitPercentage * O.Total_Brocade_Amount__c as decimal(15,2)) as Total_Brocade_Amount__c,
       			cast(OS.SplitPercentage * O.Total_FlashArray_Amount__c as decimal(15,2)) as Total_FlashArray_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_FlashBlade_Amount__c as decimal(15,2)) as Total_FlashBlade_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_X_Amount__c as decimal(15,2)) as Total_X_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_C_Amount__c as decimal(15,2)) as Total_C_Amount__c,
       			cast(OS.SplitPercentage * O.Total_Professional_Services_Amount__c as decimal(15,2)) as Total_Professional_Services_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_Training_Amount__c as decimal(15,2)) as Total_Training_Amount__c, 
       			cast(OS.SplitPercentage * O.Total_Credit_Amount__c as decimal(15,2)) as Total_Credit_Amount__c,
       			cast(OS.SplitPercentage * (O.Total_FlashArray_Amount__c - O.Total_X_Amount__c - O.Total_C_Amount__c) as decimal(15,2)) as Total_FA_Other_Amount,

       			cast(OS.SplitPercentage * 
       				 (O.Converted_Amount_USD__c - 
       				  O.Total_Cisco_MDS_Amount__c - O.Total_Cohesity_Amount__c - O.Total_Brocade_Amount__c -
       				  O.Total_FlashArray_Amount__c - O.Total_FlashBlade_Amount__c -
       				  O.Total_Professional_Services_Amount__c - O.Total_Training_Amount__c - O.Total_Credit_Amount__c)
       				 as decimal(15,2))
       			as Total_Misc_Amount
       			
		from #Oppt_Split OS
		Left join PureDW_SFDC_staging.dbo.Opportunity O on O.Id = OS.Id
		Left join PureDW_SFDC_staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
		where RecT.Name in ('Sales Opportunity')
		  and Count_of_Products__c > 0
--		  and O.Id = '0060z00001s5bHZAAY' --'0060z00001zqDnvAAE'
	) src
	unpivot (upvt_Amt_USD for [upvt_Portfolio_Col] in (Total_Cisco_MDS_Amount__c, Total_Cohesity_Amount__c, Total_Brocade_Amount__c,
		       Total_FlashArray_Amount__c, Total_FlashBlade_Amount__c, Total_X_Amount__c, Total_C_Amount__c, 
		       Total_Professional_Services_Amount__c, Total_Training_Amount__c, Total_Credit_Amount__c,
		       Total_FA_Other_Amount, Total_Misc_Amount)
	) pvt
) a where a.[Oppt_Id] = '0064W00000xfiiaQAA'
/**********************************************/
/* FA Foundation & Professional Certification */
/**********************************************/  
select Cert.Contact__c [Contact_Id]
--	P.Id [Partner Id], P.Name [Partner Name], P.Type, P.Partner_Tier__c [Partner Tier], P.Theater__c [Partner Theater]
	,  C.Name [Contact],Cert.Email_Corporate__c
	,  Cert.Exam_Code__c, Cert.Exam_Group__c, Cert.Exam_Name__c, Cert.Exam_Grade__c, cast(Cert.Exam_Date__c as Date) [Exam Date]
	, case when Cert.Exam_Code__c in ('FAP_001', 'FAP_002') then 'FA Professional'
		   when Cert.Exam_Code__c in ('PCA_001', 'PCA_Acc001', 'PCADA_001', 'PCARA_001') then 'FA Associate'
		   when Cert.Exam_Code__c in ('FAAE_001') then 'FA Expert'
		   when Cert.Exam_Code__c in ('FAIP_001', 'FAIP_002', 'PCIA_001') then 'FA Implementation'
		   when Cert.Exam_Code__c in ('FBAP_001') then 'FB Professional'
		   when Cert.Exam_Code__c in ('PCSA_001') then 'Support Assoicate' -- exclude in the report
		   else 'Other' end [Pure Certification]
from PureDW_SFDC_Staging.dbo.Pure_Certification__c Cert
left join PureDW_SFDC_Staging.dbo.Contact C on C.Id = Cert.Contact__c
--left join PureDW_SFDC_Staging.dbo.Account P on P.Id = C.AccountId
where Contact__c is not NULL
--and P.[Type] in ('Reseller', 'Disti')
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
With
#Contact_first_TD_and_UseCnt as (
	select [Created by user name], [Created by company type], [Contact 1st TD Created at],
		   [Contact 1st TD session FY], [Contact 1st TD session FQ],
		   [Contact TD Use Cnt], rn 
	from (
		select [Created by], [Created by user name], [Created by company type], convert(date, [Created at], 20) [Contact 1st TD Created at],
			   'FY' + right(cast([FiscalYear] as varchar),2) [Contact 1st TD session FY],
			   'FY' + right(cast([FiscalYear] as varchar),2) + ' ' + [FiscalQuarterName] [Contact 1st TD session FQ],
			   ROW_NUMBER() over (PARTITION by [Created by user name] order by [Created at]) rn,
			   COUNT(*) over (PARTITION by [Created by user name]) [Contact TD Use Cnt]
		from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values
	) a where a.rn = 1  
),

#TD_Report_Period as (
		select Date_ID,
		   datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1) [TestDrive_FiscalCreatedMonth],
		   dateadd(month, 1, datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1)) [TestDrive_FiscalCreatedMonth_Label],
		   'FY' + substring(FiscalYear,3,2) + ' ' + FiscalQuarterName [TestDrive_FiscalCreatedQuarter],
		   'FY' + substring(FiscalYear,3,2) [TestDrive_FiscalCreatedYear]
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= (
				/* first day of 23 fiscal month ago */
				select min(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					SELECT left(convert(varchar, dateadd(month, -23, datefromparts(FiscalYear, FiscalMonth,1)), 112),6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112)
					)
			   )
			   and 
			   Date_Id <= (			   
				/* last day of the fiscal momth of the current date */
				select max(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					Select left(FiscalMonthKey, 6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112)
					)
				)
)

select #TD_Report_Period.[TestDrive_FiscalCreatedMonth], #TD_Report_Period.[TestDrive_FiscalCreatedMonth_Label],
	   #TD_Report_Period.[TestDrive_FiscalCreatedYear], #TD_Report_Period.[TestDrive_FiscalCreatedQuarter],
	   a.[Created By], a.[TestDrive Created_By_User_Email], a.[Created by company type], a.[Created at],
	   a.[Lab name], a.[Product], a.[Contact TD Use Cnt],
	   a.[Contact 1st TD Created at], a.[Contact 1st TD Session FY], a.[Contact 1st TD session FQ]
from #TD_Report_Period
left join (
					/* select the Test Drive run by Partner Users */
					select U.[Created by], U.[Created by user name],
						   case when U.[Created by user name] like '%.p3' then substring(U.[Created by user name], 1, len(U.[Created by user name])-3)
						   	    else U.[Created by user name]
						   end [TestDrive Created_By_User_Email],
						   U.[Created by company type],U.[Created at], convert(varchar, cast(U.[Created at] as date), 112) [TestDrive_CreatedDate_ID],
						   [Lab name], [Product],
						   FTD.[Contact TD Use Cnt], FTD.[Contact 1st TD Created at], FTD.[Contact 1st TD session FY], FTD.[Contact 1st TD session FQ]
					from Datascience_Workbench_Views.dbo.v_csc_ptd_with_fiscal_values U
					left join #Contact_first_TD_and_UseCnt FTD on FTD.[Created by user name] = U.[Created by user name]
					where U.[Created by company type] = 'Channel partner'
					and U.[Created by] not like 'Pure Storage%'
) a on a.[TestDrive_CreatedDate_ID] = #TD_Report_Period.Date_ID

/**************************************************/
/* FA Sizer Log in GPO                            */
/* report # of FA Sizer created by Partner Users  */ 
/**************************************************/  
With
#FA_Report_Period as (
		select Date_ID,
		   datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1) [FASizer_FiscalCreatedMonth],
		   dateadd(month, 1, datefromparts(cast(FiscalYear as int), cast(FiscalMonth as int), 1)) [FASizer_FiscalCreatedMonth_Label],
		   'FY' + substring(FiscalYear,3,2) + ' ' + FiscalQuarterName [FASizer_FiscalCreatedQuarter],
		   'FY' + substring(FiscalYear,3,2) [FASizer_FiscalCreatedYear]
		from NetSuite.dbo.DM_Date_445_With_Past
		where Date_ID >= (
				/* first day of 23 fiscal month ago */
				select min(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					SELECT left(convert(varchar, dateadd(month, -23, datefromparts(FiscalYear, FiscalMonth,1)), 112),6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112))
			   )
			   and 
			   Date_Id <= (			   
				/* last day of the fiscal momth of the current date */
				select max(Date_ID) from NetSuite.dbo.DM_Date_445_With_Past
				where FiscalMonthKey in (
					Select left(FiscalMonthKey, 6)
					from NetSuite.dbo.DM_Date_445_With_Past
					where Date_ID = convert(varchar, getdate(), 112))
				)
),

#FA_Contact_FirstCreate as (
	Select Sizer.Email, Sizer.[Contact 1st Sizer created Date],
	'FY' + right(D.FiscalYear,2) [Contact 1st Sizer created FY],
	'FY' + Right(D.FiscalYear,2) + ' ' + D.FiscalQuarterName [Contact 1st Sizer created FQ]
	from (
			Select email, cast(min(datemin) as Date) [Contact 1st Sizer created Date]
				from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action
				where email not like '%purestorage.com' and email != ''
				  and sizeraction = 'Create Sizing'
				group by email
		 ) Sizer
		 left join NetSuite.dbo.DM_Date_445_With_Past D on D.Date_ID = convert(char(8), [Contact 1st Sizer created Date], 112)				
)

SELECT a.[Sizer_CreatedDate], #FA_Report_Period.[FASizer_FiscalCreatedMonth], #FA_Report_Period.[FASizer_FiscalCreatedMonth_Label],
	   #FA_Report_Period.[FASizer_FiscalCreatedQuarter], #FA_Report_Period.[FASizer_FiscalCreatedYear],
	   a.[Contact Email], a.sizeraction, a.request_id,
	   FC.[Contact 1st Sizer created Date], FC.[Contact 1st Sizer created FY], FC.[Contact 1st Sizer created FQ]
FROM #FA_Report_Period
LEFT JOIN (
		Select datemin [Sizer_CreatedDate], convert(char(8), datemin, 112) [SizerCreate_Date_ID]
			   , Sizer.email [Contact Email], Sizer.sizeraction, request_id
		from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action Sizer
		where Sizer.email not like '%purestorage.com' and Sizer.email != ''
		  and Sizer.sizeraction = 'Create Sizing'
) a on a.[SizerCreate_Date_ID] = #FA_Report_Period.[Date_ID]
LEFT JOIN #FA_Contact_FirstCreate FC on FC.email = a.[Contact Email]


Select max(datemin)
from [GPO_TSF_Dev].[dbo].v_fa_sizer_rs_action Sizer
where Sizer.email not like '%purestorage.com' and Sizer.email != ''
		  and Sizer.sizeraction = 'Create Sizing'

		  
		  
/****** CSC       ***/
		  
		  
/****** Certification ******/
--Pure_Certification_Log
Select b.*
		, case when [Contact_Cert_Seq] = 1 then Contact_Id else null end [Certification New Contact]
		, case when [Exam Seq] = 1 then Contact_Id else null end [Contact-s New Certification]
		, 'FY' + right(ED.FiscalYear,2) [Exam Fiscal Year]
		, 'FY' + right(ED.FiscalYear,2) + ' ' + ED.FiscalQuarterName [Exam Fiscal Quarter]
	from (
		Select CreatedDate, Contact__c Contact_Id, Exam_Code__c, Exam_Category_Code
				   , case when (Exam_Code__c like 'PCARA_%') then 'Architect Associate Certificate' --
						  when (Exam_Code__c like 'FAP_%') then 'FA Architect Professional Certificate' --
						  when (Exam_Code__c like 'FAAE_%') then 'FA Architect Expert Certificate'
						  when (Exam_Code__c like 'FBAP_%') then 'FB Architect Professional Certificate' --
						  when (Exam_Code__c like 'FAIP_%') then 'FA Implementation Professional Certificate'
						  when (Exam_Code__c like 'PCIA_%') then 'Implementation Associate Certificate'
						   				   
						  when (Exam_Code__c like 'PCA_%') then 'Pure Storage Foundation Certificate' --
						  when (Exam_Code__c like 'PCADA_%') then 'Adminstration Associate Certificate'
						  when (Exam_Code__c like 'PCSA_%') then 'Support Associate Certificate'
					  end [Pure Certification]
			
				   , Exam_Grade__c, cast(Exam_Date__c as date) [Exam Date], cast(Cert_Expiration_Date__c as date) [Cert Expiration Date] 
				   , case when Cert_Expiration_Date__c > getdate() then 1 else 0 end [Cert_Expired 1/0]
				   , ROW_NUMBER() over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [Exam Seq]
				   , count(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [# of times taken exam]
				   , min(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_date__c) [1st time taken exam]
				   , max(Exam_Date__c) over (partition by Contact__c, Exam_Category_Code order by Exam_Date__c) [Most recent taken exam]
	
				   , ROW_NUMBER() over (partition by Contact__c order by Exam_Date__c) [Contact_Cert_Seq]
				   , min(Exam_Date__c) over (partition by Contact__c order by Exam_date__c) [Contact 1st Cert]
				   , max(Exam_Date__c) over (partition by Contact__c order by Exam_Date__c) [Contact most recent Cert]
	
			from ( /* Create a standardize the Exam Category Code */
			 		Select CreatedDate, Contact__c
						   , Exam_Grade__c, Exam_Date__c, Cert_Expiration_Date__c
						   , case when Cert_Expiration_Date__c >= getdate() then 1 else 0 end [Cert_Expired 1/0] 
						   , Exam_Code__c, left(Exam_Code__c, charindex('_', Exam_Code__c)-1) Exam_Category_Code
					from PureDW_SFDC_staging.dbo.Pure_Certification__c
					where Contact__c is not null	  
				 ) a
			
	) b
	left join NetSuite.dbo.DM_Date_445_With_Past ED on ED.Date_ID = convert(varchar, b.[Exam Date], 112)


/****************************/
/*          Quote           */
/****************************/

select a.*,
	'FY' + right(F.FiscalYear, 2) [First Quote Fiscal Year],
	'FY' + right(F.FiscalYear, 2) + ' ' + F.FiscalQuarterName [First Quote Fiscal Quarter]
from 
(
	Select Q.Id [Quote Id], Q.Name [Quote Name], Q.SBQQ__Opportunity2__c [Oppt Id], Q.CPQ_Opportunity_Name__c, Q.SBQQ__Primary__c,
		 Q.CreatedDate, min(Q.CreatedDate) over (partition by Q.CreatedById order by Q.CreatedDate) [First Quote Date],
		'FY' + right(Create_FY.FiscalYear,2) [Quote Created Fiscal Year],
		'FY' + right(Create_FY.FiscalYear,2) + ' ' + Create_FY.FiscalQuarterName [Quote Created Fiscal Quarter],
		Q.CPQ_Community_Quote__c, 
		Case when Q.CPQ_Community_Quote__c = 'True' then 1 else 0 end [Partner_Created_Quote],
		case when CB.Email like '%purestorage.com' then 1 else 0 end [Created by PTSG doman],

		Q.CreatedById [Quote CreatedBy_UserId], Contact.Id [Quote CreatedBy Contact_Id],
		CB.Name [Quote CreatedBy], CB.Email [Quote Creator Email], CB_Acc.Name [Quote CreatedBy Account], CB_Acc.Id [Quote CreatedBy AccountId]
		
	from PureDW_SFDC_Staging.dbo.SBQQ__Quote__c Q
		left join PureDW_SFDC_Staging.dbo.[User] CB on CB.Id = Q.CreatedById
		left join PureDW_SFDC_Staging.dbo.[Account] CB_Acc on CB_Acc.Id = CB.AccountId
		left join PureDW_SFDC_Staging.dbo.[Contact] Contact on Contact.Id = CB.ContactId
		left join NetSuite.dbo.DM_Date_445_With_Past Create_FY on Create_FY.Date_ID = convert(varchar, Q.CreatedDate, 112)
	where CB.Email not like '%purestorage.com'
) a 
left join NetSuite.dbo.DM_Date_445_With_Past F on F.Date_ID = convert(varchar, [First Quote Date], 112)

