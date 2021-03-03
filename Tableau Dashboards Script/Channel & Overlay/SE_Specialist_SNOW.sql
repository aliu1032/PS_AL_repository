with

/* transform the Ticket to a long form, melt Assignee into a long form */
#assignee as (  
	select t.* from (
		select Number
		, case when AssignedTo_Name is null or AssignedTo_Name = '' then 'Unassigned' else substring(AssignedTo_Name, 1, charindex('(', AssignedTo_Name)-2) end AssignedTo_Name
		, AssignedTo_EmployeeNumber, 0 [hrs], 'C' [Assignment] -- C for current assignment
		from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets
		union 
		/* if Specialist 1 is blank, populate it with Assigned to
		   Assigned to is the current assignment. assume Specialist fill the time track when they fill the time */
		select Number,
		case when [SpecialistName_1] is null or [SpecialistName_1] = ''
			 then substring([AssignedTo_Name], 1, charindex('(', AssignedTo_Name)-2)
			 else substring([SpecialistName_1], 1, charindex('(', SpecialistName_1)-2) end [Assigned_to],
		case when [EmployeeNumber_1] is null or [EmployeeNumber_1] = '' then [AssignedTo_EmployeeNumber] else [EmployeeNumber_1] end [EmployeeNumber],
		case when [WorkHoursSpent_1] is null then 0 else[WorkHoursSpent_1] end [hrs], '1' [Assignment]
		from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets
		union
		select Number, substring([SpecialistName_2], 1, charindex('(',SpecialistName_2)-2) [Assigned_to], [EmployeeNumber_2] [EmployeeNumber], case when [WorkHoursSpent_2] is null then 0 else[WorkHoursSpent_2] end [hrs], '2' [Assignment]
		from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets where [EmployeeNumber_2] is not null and [EmployeeNumber_2] != ''
		union
		select Number, substring([SpecialistName_3], 1, charindex('(', SpecialistName_3)-2) [Assigned_to], [EmployeeNumber_3] [EmployeeNumber], case when [WorkHoursSpent_3] is null then 0 else[WorkHoursSpent_3] end [hrs], '3' [Assignment]
		from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets where [EmployeeNumber_3] is not null and [EmployeeNumber_3] != ''
	) t
	),

#service_oppt as (
	select  #assignee.Number, #assignee.AssignedTo_Name, #assignee.AssignedTo_EmployeeNumber, cast(#assignee.hrs as int) hrs, #assignee.Assignment, 
			SS.Requestor, SS.Account_Name,
			SS.Opportunity_ID Org_Oppt_ID,
			case
				when (SS.Opportunity_ID is null) or (SS.Opportunity_ID = '') or len(SS.Opportunity_ID) = 18 then SS.Opportunity_ID
				when charindex('https', SS.Opportunity_ID) > 0 and charindex('opportunity', lower(SS.Opportunity_ID)) > 0 then substring(SS.Opportunity_ID, charindex('opportunity', lower(SS.Opportunity_ID))+12, 18)
				else ''
			end Opportunity_ID,
			cast(SS.Opened as Date) Opened, cast(SS.Created as date) Created, cast(SS.Closed as Date) Closed, State,
			SS.Theater, SS.Short_Description, SS.Sum_WorkHoursSpent, SS.Sum_TravelTime
	from ServiceNow_DM.dbo.vw_SE_Specialist_Tickets SS
	left join #assignee on #assignee.Number = SS.Number
	),

#assigned_group as (
	select Name, EmployeeNumber,
		case when Assigned_Subgroup = 'FlashBlade' then Assigned_Subgroup
			 when charindex('-', Assigned_Subgroup,1) > 0 then substring(Assigned_Subgroup, charindex('-', Assigned_Subgroup,1)+1, len(Assigned_Subgroup) - charindex('-', Assigned_Subgroup,1))
			 else 'ALL'
		end Assigned_Group_Theater,
		case when charindex('|', Assigned_Subgroup,1) > 0 then
				  substring(Assigned_Subgroup, charindex('|', Assigned_Subgroup) + 2, charindex('-', Assigned_Subgroup) - charindex('|', Assigned_Subgroup)-2) 
				  + ' ' + left(Assigned_Subgroup, charindex('|', Assigned_subgroup)-1)
			 when charindex('-', Assigned_Subgroup, 1) > 0 then substring(Assigned_Subgroup, 1, charindex('-', Assigned_Subgroup, 1)-1)
		     else Assigned_Subgroup 
		end Assigned_Group,
		Assigned_Subgroup
		from (
			/* Standardize the group name ti: Special Group| Resource-Theater*/
			select Name, EmployeeNumber, [Group], 
			case 
				when [Group] like '%FlashBlade%' then
					 case when [Group] = 'FlashBlade Specialist Managers' then 'Managers-FlashBlade'
					      else substring([Group], 28,9999)+'-FlashBlade'
					 end
				when [Group] like 'SE Specialist -%' then (substring([Group],17,10))
				when [Group] like 'SE Specialist SE%' then (substring([Group],18,3))
				when [Group] like 'SE-Specialist%' then (substring([Group],18,9999))
				when [Group] like 'Data%' then [Group]
				when [Group] like '%vTeam%' then
						'vTeam| '
						+ left(substring([Group],4,9999), len(substring([Group],4,9999)) - charindex('(vTeam)', substring([Group],4,9999))+2)
				else substring([Group],4,9999)
			end as [Assigned_Subgroup],
			ROW_NUMBER() OVER (PARTITION BY [User] ORDER BY Created desc) as rn
		from ServiceNow_DM.dbo.vw_SE_Group_Members 
		where [Group] not in ('Security Administrators','ServiceNow Support Services')
	) t where rn=1
)


----------------------------- SQL ------------------------------
select
	Number, AssignedTo_Name, 
	case when Assigned_Group_Theater is null or Assigned_Group_Theater = '' then 'Other' else Assigned_Group_Theater end Assigned_Group_Theater, 
	case when Assigned_Group is null or Assigned_Group = '' then 'Other' else Assigned_Group end Assigned_Group, 
	case when Assigned_Subgroup is null or Assigned_Subgroup = '' then 'Other' else Assigned_Subgroup end Assigned_Subgroup, 
	AssignedTo_EmployeeNumber, hrs, Assignment,
	Opened_445.FiscalYear + ' ' + Opened_445.FiscalQuarterName [Ticket Opened in Fiscal Quarter],  Opened, Created, Closed, [State], t.Short_Description, Requestor, Sum_WorkHoursSpent, Sum_TravelTime,
	Account, 
	Opportunity_ID, Opportunity, StageName,
	case
		when (StageName is null) or (StageName = '') then 'Prospect'
		when cast(substring(StageName, 7, 1) as int) <= 2 then 'Stage 0-2, Discovery'
		when cast(substring(StageName, 7, 1) as int) = 3 then 'Stage 3, Early Stage'
		when cast(substring(StageName, 7, 1) as int) <=5 then 'Stage 4 & 5, PoC, Eval'
		when cast(substring(StageName, 7, 1) as int) <= 7 then 'Stage 6 & 7, Adv. Stage'
		when StageName in ('Stage 8 - Closed/Won','Stage 8 - Credit') then 'Closed Won'
		when StageName in ('Stage 8 - Closed/Lost') then 'Closed Lost'
		else 'Closed Other'
	end Stage,

	Oppt_Owner, [Oppt Owner Territory], SE_Oppt_Owner,
	Amount_in_USD,

	Case when t.Theater like '%AMER%' or t.Theater like '%AMERICA%' or t.Theater like '%America%' or t.Theater like 'US%' then 'AMER'
		 when t.Theater in ('EMEA', 'Europe') then 'EMEA'
		 when (t.Theater is null or t.Theater = '') then 'Unknown' else t.Theater end Theater,
	
	Case when t.Division is null or t.Division = '' then 'Unknown' else t.Division end Division,
	 
	Case when (t.Theater = 'Renewals') and (Sub_Division is null or Sub_Division = '') then 'Renewals' 
		 when (Sub_Division is null or Sub_Division = '') then 'Unknown' 
		 else Sub_Division end Sub_Division,

	Geo,Super_Region, Region, District,
	case when (Segment is null) or Segment = '' then 'Unknown' else Segment end Segment,
	[Detail Use Case],
	Support_Target

 from 
(
		/* Ticket to support Pure */
		select S.Number, S.AssignedTo_Name, AG.Assigned_Group_Theater, AG.Assigned_Group, AG.Assigned_Subgroup, S.AssignedTo_EmployeeNumber, S.hrs, S.Assignment,
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   S.Account_Name [Account],
			   Null Opportunity_ID, Null [Opportunity], Null StageName, Null [Oppt_Owner], Null [Oppt Owner Territory], Null [SE_Oppt_Owner],  
			   0.01 [Amount_in_USD],
			   S.Theater Theater, Null Division, Null Sub_Division,
			   S.Theater Geo, Null Super_Region, Null Region, Null District, Null Segment,
			   Null [Detail Use Case],
		 	   'PureStorage' as [Support_Target]
		from #service_oppt S
		left join #assigned_group AG on AG.EmployeeNumber = S.AssignedTo_EmployeeNumber
		where S.Opportunity_ID is null or S.Opportunity_ID = '' and S.Account_Name = ''

	Union

		/* Ticket for an Account */
		select S.Number, S.AssignedTo_Name, AG.Assigned_Group_Theater, AG.Assigned_Group, AG.Assigned_Subgroup,S.AssignedTo_EmployeeNumber, S.hrs, S.Assignment,
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   S.Account_Name [Account], 
			   Null Opportunity_ID, Null [Opportunity], Null StageName, Null [Oppt_Owner], Null [Oppt Owner Territory], Null [SE_Oppt_Owner],  
			   0.01 [Amount_in_USD],
			   S.Theater Theater, Null Division, Null Sub_Division,
			   S.Theater Geo, Null Super_Region, Null Region, Null District, Null Segment,
			   Null [Detail Use Case],
			   'Account' as [Support_Target]
		from #service_oppt S
		left join #assigned_group AG on AG.EmployeeNumber = S.AssignedTo_EmployeeNumber
		where S.Opportunity_ID is null or S.Opportunity_ID = '' and S.Account_Name != ''

	Union

		/* Ticket for an Opportunity */
		select S.Number, S.AssignedTo_Name, AG.Assigned_Group_Theater, AG.Assigned_Group, AG.Assigned_Subgroup, S.AssignedTo_EmployeeNumber, S.hrs, S.Assignment,
			   S.Opened, S.Created, S.Closed, S.State, S.Short_Description, S.Requestor, S.Sum_WorkHoursSpent, S.Sum_TravelTime,
			   A.Name [Account],
			   S.Opportunity_ID,
			   O.Name [Opportunity], StageName,
			   AE.Name [Oppt_Owner], AE.Territory_ID__c [Oppt Owner Territory],  SE.Name [SE_Oppt_Owner], 
			   case when O.Converted_Amount_USD__c is null then 0 else O.Converted_Amount_USD__c end [Amount_in_USD],
			   cast(O.Theater__c as varchar(50)) Theater, cast(O.Division__c as varchar(100)) Division, cast(O.Sub_Division__c as varchar(50)) Sub_Division,
			   T_ID.Theater [Geo], T_ID.Super_Region, T_ID.Region, T_ID.District, T_ID.Segment,
			   /* Opportunity AE's Territory mapping to Geo/Region/District/Segment */
			   O.Environment_detail__c [Detail Use Case],
			   'Opportunity' as [Support_Target]
		from #service_oppt S
		left join [PureDW_SFDC_Staging].[dbo].[Opportunity] O on O.Id = S.Opportunity_ID
		left join [PureDW_SFDC_Staging].[dbo].[Account] A on A.Id = O.AccountId
		left join [PureDW_SFDC_Staging].[dbo].[User] SE on SE.Id = O.SE_Opportunity_Owner__c
		left join [PureDW_SFDC_Staging].[dbo].[User] AE on AE.Id = O.OwnerId
		left join #assigned_group AG on AG.EmployeeNumber = S.AssignedTo_EmployeeNumber
		left join SalesOps_DM.dbo.TerritoryID_Master T_ID on T_ID.Territory_ID = AE.Territory_ID__c 
		where (S.Opportunity_ID is not null and S.Opportunity_ID != '')
) t
left join NetSuite.dbo.DM_Date_445_With_Past Opened_445 on Opened_445.Date_ID = convert(varchar, Opened, 112)

--where Support_Target != 'Opportunity'
--where t.Opened >= '2020-04-01'

/*
select *
from Netsuite.dbo.DM_Date_445_With_Past
where Date_ID = '20200505'
*/

select distinct([Group])
from ServiceNow_DM.dbo.vw_SE_Group_Members



select U.[user_name], g.group_name
from ServiceNow_DM.dbo.sys_user_grmember gm
left join ServiceNow_DM.dbo.[sys_user] U on U.[user_id] = gm.[user_id]
left join ServiceNow_DM.dbo.[sys_user_group] G on G.user_group_id = gm.group_id
where G.group_name like 'Data%'

select *
from ServiceNow_DM.dbo.sys_user_group
where group_name like 'Data%'
group_name like 'SE-%' or group_name like 'SE %' or group_name = 'FlashBlade Specialist Managers' or 

select User, Name, [Group]
from ServiceNow_DM.dbo.vw_SE_Group_Members
where [Group] = 'SE Specialist - FlashBlade CSA'
order by Name