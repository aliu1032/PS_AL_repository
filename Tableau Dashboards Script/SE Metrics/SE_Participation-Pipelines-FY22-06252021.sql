/** update to use the SalesOps_DM.dbo.Coverage_byName_ANA
 *  which is update monthly with SQL Server Job = SEOPS_Get_Coverage_byName
 * 
 */
WITH 

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
),


#SE_EmployeeID as (
	Select cast(EmployeeID as varchar) EmployeeID
	  from GPO_TSF_Dev.dbo.vSE_Org
	 where ((Role = 'SE' and Coverage = 'Direct') or Role in ('MSP', 'GSI')) and IC_MGR = 'IC'
	--	  and Level3_Name = 'Gabriel Ferreira'
),

#SE_Coverage as (
	Select Name, EmployeeID, Territory_ID
  	  from SalesOps_DM.dbo.Coverage_assignment_byName_FY22_ANA
  	where EmployeeID in (Select * from #SE_EmployeeID)
),

#SE_Quota as (
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], 'Q1' [Period],
		   [Measure 1 Q1 Assigned Quota] [SE Quota], [Measure 2 Q1 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota
	 
	 Union	 
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], 'Q2' [Period],
		   [Measure 1 Q2 Assigned Quota] [SE Quota], [Measure 2 Q2 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota
	 
	 Union
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], 'Q3' [Period],
		   [Measure 1 Q3 Assigned Quota] [SE Quota], [Measure 2 Q3 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota
	 
	 Union
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], 'Q4' [Period],
		   [Measure 1 Q4 Assigned Quota] [SE Quota], [Measure 2 Q4 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota

	  Union  
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], '1H' [Period],
		   [Measure 1 Q1 Assigned Quota] + [Measure 1 Q2 Assigned Quota] [SE Quota],
		   [Measure 2 Q1 Assigned Quota] + [Measure 2 Q2 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota
	    
	   Union
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], '2H' [Period],
		   [Measure 1 Q3 Assigned Quota] + [Measure 1 Q4 Assigned Quota] [SE Quota],
		   [Measure 2 Q3 Assigned Quota] + [Measure 2 Q4 Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota
	    
	    Union
	select [Time] [Report_Date], [Measure 1 Plan Effective Date] [Effective_Date],
		   [Workday Employees E1] Name, [Employee ID] [EmployeeID], 'FY22' [Year], 'FY' [Period],
		   [Measure 1 FY Assigned Quota] [SE Quota], [Measure 2 FY Assigned Quota] [FB Quota]
	    from Anaplan_DM.dbo.Employee_Territory_And_Quota	   
)


/******** Select FY22 Opportunities *********/


Select #SE_Quota.[SE Quota], #SE_Quota.[FB Quota], #SE_Quota.[Year], #SE_Quota.[Period],
	OC.*
from (
		/* Covered by SE */
		Select #SE_Coverage.Name, #SE_Coverage.Territory_ID [Covered_Territory_ID], #SE_Coverage.EmployeeID
			, case when #SE_Coverage.Territory_ID = O.Split_Territory_ID then 'T' else 'F' end [Credit_Oppt]
			, O.*
			, Case
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) = 0 then 'This quarter'
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) > 0 then 'Next ' + cast(datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) as varchar) + ' quarter'
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Today_FiscalMonth]) as varchar) + ' quarter'
			  end
			  as [Relative_closeqtr]
		  
			from (			
					select Deals.Id
						, Oppt.Name Opportunity
						, cast(Oppt.Opportunity_Account_Name__c as varchar) Account
											
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
						, Deals.Amount -- Splitted Amount
						, cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) Amount_in_USD
						
						, Oppt.Amount Oppt_Amount -- Original Amount
/*						
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
*/											
						, Oppt.StageName
						, Left(Oppt.StageName, 7) Stage
				
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
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 and Oppt.Product_Type__c = 'FlashArray'
							   then Deals.Id else null end [FA Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
						       and Oppt.[Total_C_Amount__c] is not null and Oppt.[Total_C_Amount__c] > 0 
							   then Deals.Id else null end [FA-C Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6
						       and Oppt.[Total_X_Amount__c] is not null and Oppt.[Total_X_Amount__c] > 0
							   then Deals.Id else null end [FA-X Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Professional_Services_Amount__c] is not null and Oppt.[Total_Professional_Services_Amount__c] > 0
							   then Deals.Id else null end [PS Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Training_Amount__c] is not null and Oppt.[Total_Training_Amount__c] > 0
							   then Deals.Id else null end [Training Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Brocade_Amount__c] is not null and Oppt.[Total_Brocade_Amount__c] > 0
							   then Deals.Id else null end [Brocade Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Cisco_MDS_Amount__c] is not null and Oppt.[Total_Cisco_MDS_Amount__c] > 0
							   then Deals.Id else null end [Cisco MDS Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Cohesity_Amount__c] is not null and Oppt.[Total_Cohesity_Amount__c] > 0
							   then Deals.Id else null end [Cohesity Oppt in Stage 2-6]
							   
						, convert(date, oppt.CreatedDate) CreatedDate
						, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
						
						, cast(Oppt.CloseDate as Date) [Close Date]
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
				
							where Oppt.CloseDate >= '2021-02-01' and Oppt.CloseDate < '2022-02-07'
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
					
					where Deals.[Temp_Coverage] = 'F'
		) O
	right join #SE_Coverage on #SE_Coverage.Territory_ID = O.Split_Territory_ID
	
	UNION
	/********** Temp Coverage **************/
	
		Select 
			O.SE_Oppt_Owner Name, 'Temp Coverage' Covered_Territory_ID, O.SE_Oppt_Owner_EmployeeID EmployeeID
			, 'F' as [Credit_Oppt]
			, O.*
			, Case
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) = 0 then 'This quarter'
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) > 0 then 'Next ' + cast(datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month]) as varchar) + ' quarter'
				when datediff(quarter, [Today_FiscalMonth], [Fiscal Close Month] ) < 0 then 'Last ' + cast(datediff(quarter, [Fiscal Close Month], [Today_FiscalMonth]) as varchar) + ' quarter'
			  end
			  as [Relative_closeqtr]
		  
			from (			
					select Deals.Id
						, Oppt.Name Opportunity
						, cast(Oppt.Opportunity_Account_Name__c as varchar) Account
											
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
						, Deals.Amount -- Splitted Amount
						, cast(Oppt.Converted_Amount_USD__c * Deals.Split / 100 as decimal(15,2)) Amount_in_USD
						
						, Oppt.Amount Oppt_Amount -- Original Amount
/*						
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
*/											
						, Oppt.StageName
						, Left(Oppt.StageName, 7) Stage

				
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
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 and Oppt.Product_Type__c = 'FlashArray'
							   then Deals.Id else null end [FA Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
						       and Oppt.[Total_C_Amount__c] is not null and Oppt.[Total_C_Amount__c] > 0 
							   then Deals.Id else null end [FA-C Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
						       and Oppt.[Total_X_Amount__c] is not null and Oppt.[Total_X_Amount__c] > 0
							   then Deals.Id else null end [FA-X Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Professional_Services_Amount__c] is not null and Oppt.[Total_Professional_Services_Amount__c] > 0
							   then Deals.Id else null end [PS Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Training_Amount__c] is not null and Oppt.[Total_Training_Amount__c] > 0
							   then Deals.Id else null end [Training Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Brocade_Amount__c] is not null and Oppt.[Total_Brocade_Amount__c] > 0
							   then Deals.Id else null end [Brocade Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Cisco_MDS_Amount__c] is not null and Oppt.[Total_Cisco_MDS_Amount__c] > 0
							   then Deals.Id else null end [Cisco MDS Oppt in Stage 2-6]
						, case when cast(substring(Oppt.StageName,7,1) as int) >= 2 and cast(substring(Oppt.StageName,7,1) as int) <= 6 
								and Oppt.[Total_Cohesity_Amount__c] is not null and Oppt.[Total_Cohesity_Amount__c] > 0
							   then Deals.Id else null end [Cohesity Oppt in Stage 2-6]
						
						, convert(date, oppt.CreatedDate) CreatedDate
						, DateFromParts(cast(CreateDate_445.FiscalYear as int), cast(CreateDate_445.FiscalMonth as int), 1) [Fiscal Create Month]
						
						, cast(Oppt.CloseDate as Date) [Close Date]
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
				
							where Oppt.CloseDate >= '2021-02-01' and Oppt.CloseDate < '2022-02-07'
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
					
					where Deals.[Temp_Coverage] = 'T'

		) O
--	right join #SE_Coverage on #SE_Coverage.Territory_ID = O.Split_Territory_ID
	
) OC
left join #SE_Quota on #SE_Quota.EmployeeID = OC.EmployeeID and 
					   #SE_Quota.[Year] + ' ' + #SE_Quota.Period = OC.[Fiscal Close Quarter]
--	where OC.SE_Oppt_Owner in('Inge De Maere', 'Ricardo Lopes')



/*** RBAC 
	#Permit_Oppt as (
 		select User_Email, OpportunityId
 		  from Anaplan_DM.dbo.Security_RBAC_Opportunity
 		  where User_Email in (
 							Select Email
							  from GPO_TSF_Dev.dbo.vSE_Org
						     where [Role] = 'SE' and Coverage = 'Direct' and IC_MGR = 'IC'
			  				  and Level5_Name = 'Jan Fuellmann'   -- 'Gabriel Ferreira'
			  				  )
	) 
	  
	Select Permit.[User_Email], Oppt.*
	
	from #Select_Oppt Oppt 
	left join #Permit_Oppt Permit on Permit.OpportunityId = Oppt.Id
	where Permit.[User_Email] is not null
	
	order by Permit.[User_Email]
***/	
	

