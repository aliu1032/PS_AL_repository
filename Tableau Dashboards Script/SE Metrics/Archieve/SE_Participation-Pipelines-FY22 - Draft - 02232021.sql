WITH

/* Geo Quota */
#Geo_M1_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota
	where Measure = 'M1_Quota'
	),
#Geo_FB_Quota as (
	select Territory_ID, [Year], [Period], Level, cast(Quota as decimal(18,2)) Quota, District, Region, Theater Geo, Super_Region,
	case when Period in ('Q1','Q2') then '1H' 
	     when Period in ('Q3','Q4') then '2H'
	end [Half_Period]
	from SalesOps_DM.dbo.Territory_Quota
	where Measure = 'FB_Quota'
	),

#Geo_Quota as (
	Select #Geo_M1_Quota.[Year], #Geo_M1_Quota.Period, #Geo_M1_Quota.Half_Period, #Geo_M1_Quota.Geo, #Geo_M1_Quota.Super_Region, #Geo_M1_Quota.Region, #Geo_M1_Quota.District,
	#Geo_M1_Quota.Level, #Geo_M1_Quota.Territory_ID, #Geo_M1_Quota.Quota [M1_Quota], #Geo_FB_Quota.Quota [FB_Quota]
	from #Geo_M1_Quota
	left join #Geo_FB_Quota on #Geo_M1_Quota.Territory_ID = #Geo_FB_Quota.Territory_ID and #Geo_M1_Quota.Period = #Geo_FB_Quota.Period
),

/* Per Territory, Territory Qtr Quota, + District + Region + Theater Quota */
#Geo_Quota_Wide as (
		Select R.Territory_ID, DQ.[Year], DQ.Period, DQ.Geo, DQ.Super_Region, DQ.Region, DQ.District
					, TQ.Terr_Qtrly_Quota, TQ.Terr_Qtrly_FB_Quota, TH.Terr_Half_Quota, TH.Terr_Half_FB_Quota, TA.Terr_Annual_Quota, TA.Terr_Annual_FB_Quota
					, DQ.District_Qtrly_Quota, DQ.District_Qtrly_FB_Quota, DH.District_Half_Quota, DH.District_Half_FB_Quota, DA.District_Annual_Quota, DA.District_Annual_FB_Quota
					, RQ.Region_Qtrly_Quota, RQ.Region_Qtrly_FB_Quota, RH.Region_Half_Quota, RH.Region_Half_FB_Quota, RA.Region_Annual_Quota, RA.Region_Annual_FB_Quota
					, SRQ.SuperRegion_Qtrly_Quota, SRQ.SuperRegion_Qtrly_FB_Quota, SRH.SuperRegion_Half_Quota, SRH.SuperRegion_Half_FB_Quota, SRA.SuperRegion_Annual_Quota, SRA.SuperRegion_Annual_FB_Quota
					, GQ.Geo_Qtrly_Quota, GQ.Geo_Qtrly_FB_Quota, GH.Geo_Half_Quota, GH.Geo_Half_FB_Quota, GA.Geo_Annual_Quota, GA.Geo_Annual_FB_Quota

--		from (Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota where Level = 'Territory' and Period = 'FY') R
		from (Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota where Level = 'Territory' and Period = 'FY'
			  UNION
			  Select distinct(Territory_ID) from SalesOps_DM.dbo.Territory_Quota where Level = 'District' and Period = 'FY'
			 ) R

		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Super_Region, Region, District,
					      M1_Quota [District_Qtrly_Quota], FB_Quota [District_Qtrly_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('Q1','Q2','Q3','Q4'))
				   DQ on DQ.Territory_ID = substring(R.Territory_ID, 1, 18)
		left join (Select Territory_ID, Period, M1_Quota [District_Half_Quota], FB_Quota [District_Half_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('1H','2H'))
				   DH on DH.Territory_ID = substring(R.Territory_ID, 1, 18) and DH.Period = DQ.Half_Period
		left join (Select Territory_ID, M1_Quota [District_Annual_Quota], FB_Quota [District_Annual_FB_Quota] from #Geo_Quota where Level = 'District' and Period in ('FY'))
				   DA on DA.Territory_ID = substring(R.Territory_ID, 1, 18)

   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Super_Region, Region, District,
			      M1_Quota [Terr_Qtrly_Quota], FB_Quota [Terr_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('Q1','Q2','Q3','Q4'))
				  TQ on TQ.Territory_ID = R.Territory_ID and TQ.Period = DQ.Period
   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Super_Region, Region, District,
			      M1_Quota [Terr_Half_Quota], FB_Quota [Terr_Half_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('1H', '2H'))
				  TH on TH.Territory_ID = R.Territory_ID and TH.Period = DQ.Half_Period
   		left join (Select Territory_ID, [Year], Period, Half_Period, Geo, Super_Region, Region, District,
			      M1_Quota [Terr_Annual_Quota], FB_Quota [Terr_Annual_FB_Quota] from #Geo_Quota where Level = 'Territory' and Period in ('FY'))
				  TA on TA.Territory_ID = R.Territory_ID

		left join (Select Territory_ID, Period, M1_Quota [Region_Qtrly_Quota], FB_Quota [Region_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('Q1','Q2','Q3','Q4'))
				   RQ on RQ.Territory_ID = left(R.Territory_ID, 14) and RQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Half_Quota], FB_Quota [Region_Half_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('1H','2H'))
				   RH on RH.Territory_ID = left(R.Territory_ID, 14) and RH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Region_Annual_Quota], FB_Quota [Region_Annual_FB_Quota] from #Geo_Quota where Level = 'Region' and Period in ('FY'))
				   RA on RA.Territory_ID = left(R.Territory_ID, 14)

		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Qtrly_Quota], FB_Quota [SuperRegion_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('Q1','Q2','Q3','Q4'))
				   SRQ on SRQ.Territory_ID = left(R.Territory_ID, 10) and SRQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Half_Quota], FB_Quota [SuperRegion_Half_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('1H','2H'))
				   SRH on SRH.Territory_ID = left(R.Territory_ID, 10) and SRH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [SuperRegion_Annual_Quota], FB_Quota [SuperRegion_Annual_FB_Quota] from #Geo_Quota where Level = 'Super-Region' and Period in ('FY'))
				   SRA on SRA.Territory_ID = left(R.Territory_ID, 10)

		left join (Select Territory_ID, Period, M1_Quota [Geo_Qtrly_Quota], FB_Quota [Geo_Qtrly_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('Q1','Q2','Q3','Q4'))
				   GQ on GQ.Territory_ID = left(R.Territory_ID, 6) and GQ.Period = DQ.Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Half_Quota], FB_Quota [Geo_Half_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('1H','2H')) --WW_EMA_ENC
				   GH on GH.Territory_ID = left(R.Territory_ID, 6) and GH.Period = DQ.Half_Period
		left join (Select Territory_ID, Period, M1_Quota [Geo_Annual_Quota], FB_Quota [Geo_Annual_FB_Quota] from #Geo_Quota where Level = 'Theater' and Period in ('FY'))
				   GA on GA.Territory_ID = left(R.Territory_ID, 6)
),
/*
select *
from #Geo_Quota_Wide
	where Geo = 'EMEA' and Super_Region = 'EMEA Near-Core Markets'
--	and Period in ('1H','2H')
*/

/* SE Quota */
#SE_M1_Quota as (
	select Q.Name, Q.EmployeeID, Q.Resource_Group, Q.[Year], Q.[Period], cast(Q.Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.SE_Org_Quota Q
	where Measure = 'M1'
	),
	
#SE_M2_Quota as (
	select Name, EmployeeID, [Year], [Period], cast(Quota as decimal(18,2)) Quota
	from SalesOps_DM.dbo.SE_Org_Quota
	where Measure = 'M2'
	),

#SE_t_Quota as (
	select #SE_M1_Quota.Name, #SE_M1_Quota.EmployeeID, #SE_M1_Quota.Resource_Group, -- #SE_M1_Quota.SE_District_ID, 
	#SE_M1_Quota.[Year], #SE_M1_Quota.Period, #SE_M1_Quota.Quota [SE_Quota], #SE_M2_Quota.Quota [FB_Quota]
	from #SE_M1_Quota
	left join #SE_M2_Quota on #SE_M1_Quota.EmployeeID = #SE_M2_Quota.EmployeeID and #SE_M1_Quota.Period = #SE_M2_Quota.Period
),

/*	select *,
	case when Period in ('Q1','Q2') then '1H' else '2H' end [Half_Period]
					from #SE_t_Quota where Period in ('Q1','Q2','Q3','Q4')
	and EmployeeID = '105598' --(Demetri Diakakis)
	-- EmployeeID = '102944' --(Dean Brady)
	--Name = 'Bogusz Blaszkiewicz'
*/
#SE_Quota as (
	Select Q.Name SE_Name, Q.EmployeeID, Q.Resource_Group,
		   Q.[Year] [Year], Q.Period, Q.Half_Period,
		   Q.SE_Quota, HQ.SE_Quota [SE_Half_Quota], AQ.SE_Quota [SE_Annual_Quota],
		   Q.FB_Quota, HQ.FB_Quota [SE_Half_FB_Quota], AQ.FB_Quota [SE_Annual_FB_Quota]

	from ( /* select SE users carry a Quota */ 
		select *,
		case when Period in ('Q1','Q2') then '1H' else '2H' end [Half_Period]
					from #SE_t_Quota where Period in ('Q1','Q2','Q3','Q4')
		) Q
	left join #SE_t_Quota HQ on HQ.EmployeeID = Q.EmployeeID and HQ.Period = Q.Half_Period
	left join #SE_t_Quota AQ on AQ.EmployeeID = Q.EmployeeID and AQ.Period = 'FY'
),

/*
select *
from #SE_Quota
where SE_Name = 'Andrew Miller'
--where EmployeeID = '102944' --Dean Brady
--EmployeeID = '105598' --(Demetri Diakakis)
--EmployeeID = '103153' --(Bogusz Blaszkiewicz)
*/ 

/* District id for AE assigned to Geo/Region - Created District_Pemission
 * District id for Retired Territory Id
 */

#Oppt_Require_SE_Detail as (
	select b.Id Oppt_Id, b.[Require SE Detail]
		 , case when b.[Require SE Detail] = 0 then NULL
		        else
		        	case when b.Technical_Win_State__c is NULL then 0 else 1 end 
		   end [Completed Technical Win Status]
		 , case when b.[Require SE Detail] = 0 then NULL
		        else
		        	case when (b.Technical_Win_State__c is NULL or b.Partner_SE_Engagement_Level__c is NULL or b.SE_Next_Steps_Last_Modified__c is NULL)
		        	then 0 else 1 end 
		   end [Completed SE Detail]
	from (
			select a.Id
				  , a.Technical_Win_State__c, a.Partner_SE_Engagement_Level__c, a.SE_Next_Steps_Last_Modified__c
				  , case when (a.Converted_Amount_USD__c >= 250000)
				    --     or (a.Converted_Amount_USD__c < 250000 and a.[Rank_byAmt_forSE_CQ] <= 10)
					then 1 else 0 end [Require SE Detail]
			from (
					select Oppt.Id, Oppt.Converted_Amount_USD__c
						 , Oppt.Technical_Win_State__c, Oppt.Partner_SE_Engagement_Level__c, Oppt.SE_Next_Steps_Last_Modified__c
						 , Oppt.StageName , Oppt.Stage_Prior_to_Close__c
/*						 , Oppt.Name, Close_Quarter__c, StageName
						 , SE.Name [SE Oppt Owner]
*/--						 , RANK() over (partition by Oppt.SE_Opportunity_Owner__c, cast(Close_Quarter__c as varchar(20)) order by Oppt.Converted_Amount_USD__c desc)
						 , RANK() over (partition by Oppt.SE_Opportunity_Owner__c, cast(Close_Fiscal_Quarter__c as varchar(20)) order by Oppt.Converted_Amount_USD__c desc)
				   		   Rank_byAmt_forSE_CQ
				   		   
				    from ( /* Include Opportunities Stage 3 and above; Closed Opportunities which are not closed from 0-2) */
				           /* when exclude the Close 8 from 0-2, then PubSec/Enterprise could have the top 10 less than $250K */
				    	  Select O.Id, O.Converted_Amount_USD__c, O.Technical_Win_State__c, O.Partner_SE_Engagement_Level__c, O.SE_Next_Steps_Last_Modified__c,
				    	         O.StageName, O.Stage_Prior_to_Close__c, O.SE_Opportunity_Owner__c, O.Close_Fiscal_Quarter__c
				    	  from PureDW_SFDC_Staging.dbo.Opportunity O
				    	  left join PureDW_SFDC_Staging.dbo.RecordType R on R.Id = O.RecordTypeId
				    	  where R.Name in ('Sales Opportunity', 'ES2 Opportunity') and CloseDate >= '2020-02-03'
				    	        and cast(substring(StageName, 7,1) as int) >= 3 and cast(substring(StageName, 7,1) as int) <= 7
				    	        
				    	  Union
				    	  
				    	  Select O.Id, O.Converted_Amount_USD__c, O.Technical_Win_State__c, O.Partner_SE_Engagement_Level__c, O.SE_Next_Steps_Last_Modified__c,
				    	         O.StageName, O.Stage_Prior_to_Close__c, O.SE_Opportunity_Owner__c, O.Close_Fiscal_Quarter__c
						  --     , Stage_Prior_to_Close__c
				    	  from PureDW_SFDC_Staging.dbo.Opportunity O
				    	  left join PureDW_SFDC_Staging.dbo.RecordType R on R.Id = O.RecordTypeId
				    	  where R.Name in ('Sales Opportunity', 'ES2 Opportunity') and CloseDate >= '2020-02-03'
				    	        and cast(substring(StageName, 7,1) as int) = 8 
								and Stage_Prior_to_Close__c is not null
								and Stage_Prior_to_Close__c not like 'Stage 0%'
								and Stage_Prior_to_Close__c not like 'Stage 1%'
								and Stage_Prior_to_Close__c not like 'Stage 2%'
						  ) Oppt
					left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id= Oppt.SE_Opportunity_Owner__c
				) a
	) b
)


-- SQL extract dataset	


Select A.*

	/* calculate the relative period */
	, Case
		when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) = 0 then 'This quarter'
		when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) > 0 then 'Next ' + cast(datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) as varchar) + ' quarter'
		when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Today_FiscalMonth]) as varchar) + ' quarter'
	  end
	  as [Relative_closeqtr]
	  
		from (	  
			select
				  [Final].Id, [Final].Opportunity, [Final].Acct_Name, [Final].[RecordType], [Final].[Type], [Final].[Transaction_Type]
				, [Final].Theater, [Final].Division, [Final].Sub_Division, [Final].Manufacturer, [Final].Product_Type__c, [Final].[Product]
				, case when [Final].[Technical Win Status] is null then 'Incompleted' else [Final].[Technical Win Status] end [Technical Win Status]
				, [Final].[SE_Next_Steps_Last_Modified__c]
				, case when [Final].[Require SE Detail] is null then 0 else [Final].[Require SE Detail] end [Require SE Detail]
				, [Final].[Completed Technical Win Status], [Final].[Completed SE Detail]
				, [Final].Oppt_Owner, [Final].Acct_Exec, [Final].Acct_Exec_Territory_ID --, [Final].[Direct_ISO]
			--	, [Final].[District_Permission]
				, [Final].SE_Oppt_Owner
				, [Final].SE_Oppt_Owner_EmployeeID
				
			--	, [Final].Partner, [Final].[Partner SE], [Final].[Partner SE Engagement Level]
				
				, [Final].Split, [Final].Currency, [Final].Amount, [Final].Amount_in_USD, [Final].Oppt_Amount
				, [Final].Stage , [Final].StageGroup 
				--, [Final].POC_Stage, [Final].POC_Status
				
				, [Final].Open$, [Final].[Early Stage$], [Final].[Adv. Stage$], [Final].[Commit$], [Final].[Bookings$]
				, [Final].[Won Deal], [Final].[Loss Deal], [Final].[Closed Deal]
				, [Final].[Oppt in Stage 2-6], [Final]. [FB Oppt in Stage 2-6]
				
				, [Final].CreatedDate, [Final].[Fiscal Create Month]
				, [Final].[Close Date]
				, [Fiscal Close Month] = COALESCE([Final].[Fiscal Close Month],
										 DateFromParts(cast(right([Final].[Quota Year],2) as int)+2000, cast(right([Final].[Quota Quarter],1) as int) * 3,1)
										 )
				, [Close Year] = COALESCE([Final].[Oppt Close Year], [Final].[Quota Year])
				, [Close Quarter] = COALESCE([Final].[Oppt Close Quarter], [Final].[Quota Quarter])
			
				, [Final].[TodayKey]
				, [Today_FiscalMonth] = DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)
				
				, [Final].SE_Quota, [Final].SE_Half_Quota, [Final].SE_Annual_Quota
				, [Final].FB_Quota, [Final].SE_Half_FB_Quota, [Final].SE_Annual_FB_Quota
				  	  
			from (

--################	
with 

	#Oppt_Require_SE_Detail as (
	select b.Id Oppt_Id, b.[Require SE Detail]
		 , case when b.[Require SE Detail] = 0 then NULL
		        else
		        	case when b.Technical_Win_State__c is NULL then 0 else 1 end 
		   end [Completed Technical Win Status]
		 , case when b.[Require SE Detail] = 0 then NULL
		        else
		        	case when (b.Technical_Win_State__c is NULL or b.Partner_SE_Engagement_Level__c is NULL or b.SE_Next_Steps_Last_Modified__c is NULL)
		        	then 0 else 1 end 
		   end [Completed SE Detail]
	from (
			select a.Id
				  , a.Technical_Win_State__c, a.Partner_SE_Engagement_Level__c, a.SE_Next_Steps_Last_Modified__c
				  , case when (a.Converted_Amount_USD__c >= 250000)
				    --     or (a.Converted_Amount_USD__c < 250000 and a.[Rank_byAmt_forSE_CQ] <= 10)
					then 1 else 0 end [Require SE Detail]
			from (
					select Oppt.Id, Oppt.Converted_Amount_USD__c
						 , Oppt.Technical_Win_State__c, Oppt.Partner_SE_Engagement_Level__c, Oppt.SE_Next_Steps_Last_Modified__c
						 , Oppt.StageName , Oppt.Stage_Prior_to_Close__c
/*						 , Oppt.Name, Close_Quarter__c, StageName
						 , SE.Name [SE Oppt Owner]
*/--						 , RANK() over (partition by Oppt.SE_Opportunity_Owner__c, cast(Close_Quarter__c as varchar(20)) order by Oppt.Converted_Amount_USD__c desc)
						 , RANK() over (partition by Oppt.SE_Opportunity_Owner__c, cast(Close_Fiscal_Quarter__c as varchar(20)) order by Oppt.Converted_Amount_USD__c desc)
				   		   Rank_byAmt_forSE_CQ
				   		   
				    from ( /* Include Opportunities Stage 3 and above; Closed Opportunities which are not closed from 0-2) */
				           /* when exclude the Close 8 from 0-2, then PubSec/Enterprise could have the top 10 less than $250K */
				    	  Select O.Id, O.Converted_Amount_USD__c, O.Technical_Win_State__c, O.Partner_SE_Engagement_Level__c, O.SE_Next_Steps_Last_Modified__c,
				    	         O.StageName, O.Stage_Prior_to_Close__c, O.SE_Opportunity_Owner__c, O.Close_Fiscal_Quarter__c
				    	  from PureDW_SFDC_Staging.dbo.Opportunity O
				    	  left join PureDW_SFDC_Staging.dbo.RecordType R on R.Id = O.RecordTypeId
				    	  where R.Name in ('Sales Opportunity', 'ES2 Opportunity') and CloseDate >= '2020-02-03'
				    	        and cast(substring(StageName, 7,1) as int) >= 3 and cast(substring(StageName, 7,1) as int) <= 7
				    	        
				    	  Union
				   	  
				    	  Select O.Id, O.Converted_Amount_USD__c, O.Technical_Win_State__c, O.Partner_SE_Engagement_Level__c, O.SE_Next_Steps_Last_Modified__c,
				    	         O.StageName, O.Stage_Prior_to_Close__c, O.SE_Opportunity_Owner__c, O.Close_Fiscal_Quarter__c
						  --     , Stage_Prior_to_Close__c
				    	  from PureDW_SFDC_Staging.dbo.Opportunity O
				    	  left join PureDW_SFDC_Staging.dbo.RecordType R on R.Id = O.RecordTypeId
				    	  where R.Name in ('Sales Opportunity', 'ES2 Opportunity') and CloseDate >= '2020-02-03'
				    	        and cast(substring(StageName, 7,1) as int) = 8 
								and Stage_Prior_to_Close__c is not null
								and Stage_Prior_to_Close__c not like 'Stage 0%'
								and Stage_Prior_to_Close__c not like 'Stage 1%'
								and Stage_Prior_to_Close__c not like 'Stage 2%'
						  ) Oppt
					left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id= Oppt.SE_Opportunity_Owner__c
				) a
	) b
)
-----------------------------
Select A.*
		, Case
			when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) = 0 then 'This quarter'
			when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) > 0 then 'Next ' + cast(datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) as varchar) + ' quarter'
			when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Today_FiscalMonth]) as varchar) + ' quarter'
		  end
		  as [Relative_closeqtr]
	  
		from (	  
			
				select Deals.Id
					, Oppt.Name Opportunity
					, Oppt.Opportunity_Account_Name__c Account
--					, Oppt.[Type]
--					, Oppt.Transaction_Type__c Transaction_Type
					
--					, Oppt.Theater__c Theater
--					, Oppt.Division__c Division
--					, Oppt.Sub_Division__c Sub_Division
					--, Oppt.Territory2Id
					
										
					/* Account Exec on an Opportunity */
					, Oppt_Owner.Name Oppt_Owner
					
					/* Acct_Exec compensated on the booking */
					, Deals.Acct_Exec
					, Deals.Split_Territory_ID
					, Deals.Split_District_ID
			
					/* SE Opportunity Owner */
					, Deals.SE_Oppt_Owner
					, Deals.SE_Oppt_Owner_EmployeeID
					, Deals.Assigned_SE
					, Deals.Assigned_SE_EmployeeID
					, Deals.Temp_Coverage
----					, case when Deals.Acct_Exec is null then coalesce(SE_Oppt_Owner.Name, SE_Quota.SE_Name) else SE_Oppt_Owner.Name end SE_Oppt_Owner
----					, case when Deals.Acct_Exec is null then coalesce(SE_Oppt_Owner.EmployeeNumber, SE_Quota.EmployeeID) else SE_Oppt_Owner.EmployeeNumber end SE_Oppt_Owner_EmployeeID

					, Deals.RecordType
					, Oppt.Manufacturer__c Manufacturer
					, Case
					  when Deals.RecordType = 'ES2 Opportunity' and Oppt.[CBS_Category__c] != '' and Oppt.[CBS_Category__c] != 'NO CBS' then 'CBS'
					  when Deals.RecordType = 'ES2 Opportunity' then 'PaaS'
					  when Oppt.Manufacturer__c = 'Pure Storage' then Oppt.Product_Type__c else Oppt.Manufacturer__c
					  end Product
					, Oppt.[CBS_Category__c] [CBS_Category]
					
					, Deals.Split
					, Deals.Currency
					, Deals.Amount
					, cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) Amount_in_USD
					, Oppt.Amount Oppt_Amount
				    , Oppt.[Total_Contract_Value__c] [Contract_Value] -- is this PaaS value??
				    , Oppt.[Total_FlashArray_Amount__c] [FlashArray Amount]
				    , Oppt.[Total_FlashBlade_Amount__c] [FlashBlade Amount]
				    , Oppt.[Total_Professional_Services_Amount__c] [Pro-Service Amount]
				    , Oppt.[Total_Training_Amount__c] [Training Amount]

				    , Oppt.[Total_Brocade_Amount__c] [Brocade Amount]
				    , Oppt.[Total_Cisco_MDS_Amount__c] [Cisco MDS Amount]
				    , Oppt.[Total_Cohesity_Amount__c] [Cohesity Amount]

				    , Oppt.[Total_X_Amount__c] [FA-X Amount]
				    , Oppt.[Total_C_Amount__c] [FA-C Amount]
					
					/* skipped oppt original amount */
					
					, Oppt.StageName Stage
			
					, case
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 3 then 'Early Stage'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 5 then 'Adv. Stage'
						when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 then 'Commit'
						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Won'
						when Oppt.StageName in ('Stage 8 - Closed/ Disqualified','Stage 8 - Closed/Lost','Stage 8 - Closed/No Decision','Stage 8 - Closed/ Low Capacity') then 'Loss'
					end as StageGroup

					, case when cast(substring(Oppt.StageName, 7, 1) as int) <= 7 
					  then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
					  else 0 
					  end as [Open$]
			
					, case 
						when cast(substring(Oppt.StageName, 7, 1) as int) < 4
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
						else 0
					end as [Early Stage$]
					
					, case 
						when cast(substring(Oppt.StageName, 7, 1) as int) >= 4 and cast(substring(Oppt.StageName, 7, 1) as int) <= 5
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
						else 0
					end as [Adv. Stage$]
						
					, case 
						when cast(substring(Oppt.StageName, 7, 1) as int) >= 6 and cast(substring(Oppt.StageName, 7, 1) as int) <= 7
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
						else 0
					end as [Commit$]
			
					, case 
						when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit')
						then case when Oppt.Converted_Amount_USD__c is null then 0 else cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) end
						else 0
					end as [Bookings$]
			
					, case when Oppt.StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then Deals.Id else null end as [Won Deal]
					, case 
						when Oppt.StageName in ('Stage 8 - Closed/ Disqualified',
											 'Stage 8 - Closed/Lost',
											 'Stage 8 - Closed/No Decision', 
											 'Stage 8 - Closed/ Low Capacity')
						then Deals.Id else null end as [Loss Deal]	
					, case when cast(substring(Oppt.StageName,7,1) as int) > 7 then Deals.Id else null end as [Closed Deal]
					
					, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 then Deals.Id else null end [Oppt in Stage 2-6]
					, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 and Oppt.Product_Type__c = 'FlashBlade'
						   then Deals.Id else null end [FB Oppt in Stage 2-6]
					
					, convert(date, oppt.CreatedDate) CreatedDate
					, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
					
					, cast(Oppt.CloseDate as Date) [Close Date]
--					, Oppt.Fiscal_Year__c, Oppt.Close_Fiscal_Quarter__c, Oppt.Close_Month__c
					, [Fiscal Close Month] = DateFromParts(cast(CloseDate_445.FiscalYear as int), cast(CloseDate_445.FiscalMonth as int), 1)
					, [Fiscal Close Year] = 'FY' + right(Oppt.Close_Fiscal_Quarter__c, 2)
					, [Fiscal Close Quarter] = 'FY' + right(Oppt.Close_Fiscal_Quarter__c, 2) + ' '+ left(Oppt.Close_Fiscal_Quarter__c,2)
												 
					, [TodayKey] = convert(varchar, getDate(), 112)
					, [Today_FiscalMonth] = DateFromParts(TodayDate_445.FiscalYear,TodayDate_445.FiscalMonth,1)

					, Case when (Oppt.Technical_Win_State__c is Null) then 'Incompleted'
						   when Oppt.Technical_Win_State__c = 'Strong' then 'Differentiated'
						   when Oppt.Technical_Win_State__c = 'Neutral' then 'No Differentiation'
						   when Oppt.Technical_Win_State__c = 'Losing' then 'Disadvantaged'
						   else Oppt.Technical_Win_State__c end [Technical Win Status]
			
					, Oppt.SE_Next_Steps_Last_Modified__c
					, SE_Detail_Check.[Require SE Detail]
					, SE_Detail_Check.[Completed Technical Win Status]
					, SE_Detail_Check.[Completed SE Detail]

/*****					  
					, SE_Quota.[Year] [Quota Year]
					, SE_Quota.[Year] + ' ' + SE_Quota.Period [Quota Quarter] 
					, SE_Quota = coalesce(SE_Quota.SE_Quota, AE_Quota.Terr_Qtrly_Quota)
					, SE_Half_Quota = coalesce(SE_Quota.SE_Half_Quota , AE_Quota.Terr_Half_Quota)
					, SE_Annual_Quota = coalesce(SE_Quota.SE_Annual_Quota, AE_Quota.Terr_Annual_Quota)
			
					, FB_Quota = coalesce(SE_Quota.FB_Quota, AE_Quota.Terr_Qtrly_FB_Quota)
					, SE_Half_FB_Quota = coalesce(SE_Quota.SE_Half_FB_Quota, AE_Quota.Terr_Half_FB_Quota)
					, SE_Annual_FB_Quota = coalesce(SE_Quota.SE_Annual_FB_Quota, AE_Quota.Terr_Annual_FB_Quota)
					
					, SE_Quota.Resource_Group
*****/					
				from (
						/* a copy of the original deals and get the split information */
						Select Oppt.Id
							, Acct_Exec.Territory_ID__c Split_Territory_ID /* Split Owner Territory Id in User Profile */
							, left(Acct_Exec.Territory_ID__c, 18) as Split_District_ID

							, Acct_Exec.Name Acct_Exec
							, Acct_Exec.Id Acct_Exec_SFDC_UserID
							
							, SE_Oppt_Owner.Name [SE_Oppt_Owner]
							, SE_Oppt_Owner.EmployeeNumber [SE_Oppt_Owner_EmployeeID]
							, Assign_SE.SE [Assigned_SE]
							, Assign_SE.SE_EmployeeID [Assigned_SE_EmployeeID]

							/* check if SE Oppt Owner is tempoary covering this Opportunity*/
							, case when Assign_SE.SE_EmployeeID like concat('%', SE_Oppt_Owner.EmployeeNumber, '%') then 'F' else 'T' end [Temp_Coverage]
							, OpptSplit.SplitPercentage Split
							, OpptSplit.CurrencyIsoCode Currency
							, OpptSplit.SplitAmount Amount  -- Split amount is count towards raw bookings for comp calculation
			
							, RecType.Name RecordType
							
						from PureDW_SFDC_Staging.dbo.Opportunity Oppt
							left join PureDW_SFDC_Staging.dbo.RecordType RecType on RecType.Id = Oppt.RecordTypeId
							left join [PureDW_SFDC_staging].[dbo].[OpportunitySplit] OpptSplit on Oppt.Id = OpptSplit.OpportunityId
							left join [PureDW_SFDC_staging].[dbo].[OpportunitySplitType] SplitType on OpptSplit.SplitTypeId = SplitType.Id
							left join [PureDW_SFDC_staging].[dbo].[User] Acct_Exec on Acct_Exec.Id = OpptSplit.SplitOwnerID
							left join PureDW_SFDC_Staging.dbo.[User] SE_Oppt_Owner on SE_Oppt_Owner.Id = Oppt.SE_Opportunity_Owner__c					
							left join SalesOps_DM.dbo.Coverage_assignment_byTerritory_FY22 Assign_SE on Assign_SE.Territory_ID = Acct_Exec.Territory_ID__c
			
						where Oppt.CloseDate >= '2021-01-01' and Oppt.CloseDate < '2021-04-15'--and Oppt.CloseDate < '2022-02-07'
						and RecType.Name in ('Sales Opportunity', 'ES2 Opportunity') --, 'CSAT Opportunity', 'Renewal', 'Internal System Request Opportunity')
						and (Oppt.Transaction_Type__c is null or Oppt.Transaction_Type__c != 'ES2 Renewal')
						and cast(Oppt.Theater__c as nvarchar(50)) != 'Renewals'
						and SplitType.MasterLabel = 'Revenue'  --'Temp Coverage','Overlay'
						and OpptSplit.IsDeleted = 'False'
				) Deals
				left join PureDW_SFDC_Staging.dbo.Opportunity Oppt on Oppt.Id = Deals.Id
				left join PureDW_SFDC_Staging.dbo.[User] Oppt_Owner on Oppt_Owner.Id = Oppt.OwnerId
				left join PureDW_SFDC_Staging.dbo.[User] SE_Oppt_Owner on SE_Oppt_Owner.Id = Oppt.SE_Opportunity_Owner__c					
				
				left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, Oppt.CloseDate, 112)
				left join NetSuite.dbo.DM_Date_445_With_Past CreateDate_445 on CreateDate_445.Date_ID = convert(varchar, Oppt.CreatedDate, 112)
				left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
			
				left join #Oppt_Require_SE_Detail SE_Detail_Check on SE_Detail_Check.Oppt_Id = Oppt.Id
) A
---------------------

				left join #Geo_Quota_Wide AE_Quota on (AE_Quota.Territory_ID = Acct_Exec_Territory_ID and AE_Quota.Period = CloseDate_445.FiscalQuarterName and AE_Quota.[Year] = 'FY' + substring(CloseDate_445.FiscalYear, 3,2))
				full join #SE_Quota SE_Quota on SE_Quota.EmployeeID = SE_Oppt_Owner.EmployeeNumber and SE_Quota.Period = CloseDate_445.FiscalQuarterName and
												--substring(SE_Quota.SE_District_ID,1,18) = substring(AE_Quota.Territory_ID,1,18)
												SE_Quota.EmployeeID = SE_Oppt_Owner.EmployeeNumber
												
				
			) [Final]
			left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = [Final].TodayKey
--			where [Final].SE_Oppt_Owner = 'Brandon Grieve'			
		) A
--right join GPO_TSF_Dev.dbo.vSE_Org Org on cast(Org.EmployeeID as varchar) = [Final].SE_Oppt_Owner_EmployeeID

--right join #SE_Org Org on Org.EmployeeID = [Final].SE_Oppt_Owner_EmployeeID


where
--[Final].SE_Oppt_Owner = 'Kulvinder Mann'
--and [Final].[Close Quarter] = 'FY21 Q3'
A.SE_Oppt_Owner = 'Reid Moncrief'
--A.Id = '0060z00001zsGl9AAE'
--[Final].Acct_Exec in ('Chris Dopp')S
--A.SE_Oppt_Owner_EmployeeID= '101912'
--[Final].Id = '0060z000022wEVUAA2' 
--[Final].SE_Oppt_Owner_EmployeeID = '105632' -- Jeff Dunsbergen
--'102944' --Dean Brady
--'105136' -- Brad Janes
--'105406' -- Matthew Bednar
-- '105598'
--102855 Reid Moncrief
--Opportunity is null

-- join #Geo_Quota_Wide Geo_Quota on (Geo_Quota.Territory_ID = [Final].Acct_Exec_Territory_ID and Geo_Quota.Period = substring([Final].[Close Quarter], 6,2) and Geo_Quota.[Year] = [Final].[Close Year])
--full join #SE_Quota SE_Quota on SE_Quota.EmployeeID = [Final].SE_Oppt_Owner_EmployeeID and SE_Quota.Period = substring([Final].[Close Quarter], 6,2) -- [Final].[Close Quarter]--
--)b) a
 --Final.[Close Quarter] = 'FY21 Q3' and Final.SE_Oppt_Owner_EmployeeID = '102944'

-- or )
--where [Final].Id in ('0060z0000201jeGAAQ', '0060z0000204jEBAAY') 
--order by [Final].Id
--('0060z00001zsHt9AAE','0060z00001xkdnHAAQ','0060z00001z67qsAAA')




