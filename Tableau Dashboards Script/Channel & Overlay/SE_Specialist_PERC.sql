/**************************/
/*  PERC                  */
/**************************/
With
/* transform the Ticket to a long form, melt Assignee into a long form */
#assignee_perc as (  
		select sl_number [Number],
			   case when assigned_to_id is null then 'Unassigned' else assigned_to_id end assigned_to_id,
			   0 [hrs], 'C' [Assignment] -- C for current assignment
		from ServiceNow_DM.dbo.perc_ps_sales_eng
		
		UNION
		 
		select sl_number [Number],
			   CASE WHEN specialist_1_id IS NULL THEN assigned_to_id ELSE specialist_1_id END [assigned_to_id],
			   CASE WHEN work_hours_spent_1_new is null then 0 else work_hours_spent_1_new end [hrs], '1' [Assignment]
		from ServiceNow_DM.dbo.perc_ps_sales_eng
		
		UNION	  
		
		select sl_number [Number], specialist_2_id [assigned_to_id], 
			   case when  work_hours_spent_2_new is null then 0 else work_hours_spent_2_new end [hrs], '2' [Assignment]
		from ServiceNow_DM.dbo.perc_ps_sales_eng where specialist_2_id is not null
		
		UNION
		
		select sl_number [Number], specialist_3_id [assigned_to_id], 
			   case when  work_hours_spent_3_new is null then 0 else work_hours_spent_3_new end [hrs], '3' [Assignment]
		from ServiceNow_DM.dbo.perc_ps_sales_eng where specialist_3_id is not null
),

#service_ticket_perc as (
		select SS.sl_number [Number], OU.Name [Requestor], SS.account_name [Account_Name], SS.opportunity_id Org_Oppt_ID,
			   case
					when (SS.opportunity_id is null) or len(SS.opportunity_id) = 18 then SS.opportunity_id
					when charindex('https', SS.opportunity_id) > 0 and charindex('opportunity', lower(SS.opportunity_id)) > 0
					then substring(SS.opportunity_id, charindex('opportunity', lower(SS.opportunity_id))+12, 18)
			   end Opportunity_ID,
			   cast(SS.opened_at as Date) Opened, cast(SS.created_on as Date) Created, 
			   case when SS.closed_at is null or SS.closed_at = '' then null else cast(SS.closed_at as Date) end Closed, State,
			   SS.Theater, SS.short_description, SS.total_work_hours_spent_new [Sum_WorkHoursSpent], SS.total_travel_time_new [Sum_TravelTime]
		from ServiceNow_DM.dbo.perc_ps_sales_eng SS
		left join ServiceNow_DM.dbo.perc_sys_user OU on OU.user_id = SS.opened_by_id
),

#perc_user_group as (
		select U.Name, U.user_id,
			   case when charindex('-', G.Assigned_Subgroup) > 0 
			   		then substring(G.Assigned_Subgroup, charindex('-', G.Assigned_Subgroup,1)+1, len(G.Assigned_Subgroup) - charindex('-', G.Assigned_Subgroup,1))
			   		else 'All'
			   end [Assigned_Group_Theater],
			   
			   case when charindex('|', G.Assigned_Subgroup) > 0
			   		then substring(G.Assigned_Subgroup, charindex('|', G.Assigned_Subgroup,1)+2, charindex('-', G.Assigned_Subgroup) - charindex('|',G.Assigned_Subgroup)-2 ) + ' vTeam'
			   		when charindex('-', G.Assigned_Subgroup) > 0
			   		then substring (G.Assigned_Subgroup,1, charindex('-',G.Assigned_Subgroup)-1)
			   		else G.Assigned_Subgroup
			   end Assigned_Group,
			   
			   G.Assigned_Subgroup
		from 
		(
				/* Standardize group name to : Specialist Group-Theater */
					Select G.user_group_id, G.group_name,
						   case when G.group_name like '%FlashBlade%' then 
								case when G.group_name = 'FlashBlade Specialist Managers' then 'Managers-FlashBlade'
									 else substring(G.group_name, 28, 10) + '-FlashBlade'
								end
								when G.group_name like 'SE Specialist -%' then substring(G.group_name, 17,10)
								when G.group_name like 'SE Specialist SE%' then substring(G.group_name, 18,3)
								when G.group_name like 'SE-Specialist%' then substring(G.group_name,18,9999)
								when G.group_name like '%vTeam%' then 'vTeam| '
																	+ left(substring(G.group_name,4,9999), len(substring(G.group_name,4, 9999)) - charindex('(vTeam)', substring(G.group_name,4,9909))+2)
								else substring(G.group_name,4,9999)
							end [Assigned_Subgroup],
					M.user_id, ROW_Number() over (partition by M.user_id order by created_on desc) as rn
					from ServiceNow_DM.dbo.perc_sys_user_group G
					left join ServiceNow_DM.dbo.perc_sys_user_grmember M on M.group_id = G.user_group_id
					  where G.group_name like 'SE-%' or G.group_name like '[^HR]%Specialist%'
		) G
		left join ServiceNow_DM.dbo.perc_sys_user U on U.user_id = G.user_id
		where G.rn = 1
)

/*********** SQL ***********/
Select
	Number, AssignedTo_Name,
	case when Assigned_Group_Theater is null or Assigned_Group_Theater = '' then 'Other' else Assigned_Group_Theater end Assigned_Group_Theater,
	case when Assigned_Group is null or Assigned_Group = '' then 'Other' else Assigned_Group end Assigned_Group,
	hrs, Assignment,
	
	/** need to convert date to fiscal date */
	Opened, Created, Closed, State, Short_Description, Requestor, Sum_WorkHoursSpent, Sum_TravelTime,
	Account,
	Opportunity_ID, Opportunity, StageName,
	case 
		when StageName is null or StageName = '' then 'Prospect'
		when cast(substring(StageName, 7, 1) as int) <= 2 then 'Stage 0-2, Discovery'
		when cast(substring(StageName, 7, 1) as int) = 3 then 'Stage 3, Early Stage'
		when cast(substring(StageName, 7, 1) as int) <=5 then 'Stage 4-5, POC, Eval'
		when cast(substring(StageName, 7, 1) as int) <= 7 then 'Stage 6 & 7, Adv. Stage'
		when StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Closed Won'
		when StageName in ('Stage 8 - Closed/Lost') then 'Closed Lost'
		else 'Closed Other'
	end Stage,
	
	Oppt_Owner, SE_Oppt_Owner,
	
	Amount_in_USD,
	
	Case when t.Theater like '%AMER%' or t.Theater like '%AMERICA%' or t.Theater like '%America%' or t.Theater like 'US%' then 'AMER'
		 when t.Theater in ('EMEA', 'Europe') then 'EMEA'
		 when (t.Theater is null or t.Theater = '') then 'Unknown' else t.Theater end Theater,
	
	Case when t.Division is null or t.Division = '' then 'Unknown' else t.Division end Division,
	 
	Case when (t.Theater = 'Renewals') and (Sub_Division is null or Sub_Division = '') then 'Renewals' 
		 when (Sub_Division is null or Sub_Division = '') then 'Unknown' 
		 else Sub_Division end Sub_Division,
		 
	[Detail Use Case], Support_Target
	

from (
		/* Ticket for Pure */
		SELECT S.Number, grp.Name [AssignedTo_Name], grp.Assigned_Group_Theater, grp.Assigned_Group, assign.hrs, assign.[Assignment],
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   null [Account],
			   null Opportunity_ID, null [Opportunity], null StageName,
			   null [Oppt_Owner], null [SE_Oppt_Owner],
			   0.01 [Amount_in_USD],
			   S.Theater, null Division, null Sub_Division,
			   null [Detail Use Case],
			   'PureStorage' as [Support_Target]
			   
		from #service_ticket_perc S
		left join #assignee_perc assign on assign.Number = S.Number
		left join #perc_user_group grp on grp.user_id = assign.assigned_to_id
		where (S.Opportunity_ID is null or S.Opportunity_ID = '') and (S.[Account_Name] is null or S.[Account_Name] != '')

		UNION		

		/* Ticket for Account */
		SELECT S.Number, grp.Name [AssignedTo_Name], grp.Assigned_Group_Theater, grp.Assigned_Group, assign.hrs, assign.[Assignment],
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   S.Account_Name [Account],
			   null Opportunity_ID, null [Opportunity], null StageName,
			   null [Oppt_Owner], null [SE_Oppt_Owner],
			   0.01 [Amount_in_USD],
			   S.Theater, null Division, null Sub_Division,
			   null [Detail Use Case],
			   'Account' as [Support_Target]
			   
		from #service_ticket_perc S
		left join #assignee_perc assign on assign.Number = S.Number
		left join #perc_user_group grp on grp.user_id = assign.assigned_to_id
		where S.Opportunity_ID is null and S.[Account_Name] is not null and S.[Account_Name] != ''

		UNION

		/* Ticket for Opportunity */
		SELECT S.Number, grp.Name [AssignedTo_Name], grp.Assigned_Group_Theater, grp.Assigned_Group, assign.hrs, assign.[Assignment],
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   A.Name [Account], S.Opportunity_ID, O.Name [Opportunity], O.StageName,
			   AE.Name [Oppt_Owner], SE.Name [SE_Oppt_Owner],
			   case when O.Converted_Amount_USD__c is null then 0 else O.Converted_Amount_USD__c end [Amount_in_USD],
			   cast(O.Theater__c as varchar(50)) Theater, cast(O.Division__c as varchar(50)) Division, cast(O.Sub_Division__c as varchar(50)) Sub_Division,
			   O.Environment_detail__c [Detail Use Case],
			   'Opportunity' as [Support_Target]
			   
		from #service_ticket_perc S
		left join #assignee_perc assign on assign.Number = S.Number
		left join #perc_user_group grp on grp.user_id = assign.assigned_to_id
		left join PureDW_SFDC_staging.dbo.Opportunity O on O.Id = S.Opportunity_ID
		left join PureDW_SFDC_staging.dbo.[Account] A on A.Id = O.AccountId
		left join PureDW_SFDC_staging.dbo.[User] AE on AE.Id = O.OwnerId
		left join PureDW_SFDC_staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
		where S.Opportunity_ID is not null and S.Opportunity_ID != ''
) t

---------  
