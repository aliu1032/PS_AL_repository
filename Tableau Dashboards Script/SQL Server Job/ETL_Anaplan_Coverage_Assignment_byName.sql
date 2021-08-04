
/* Use the Flatten table to find an Employee Territory Coverage
 * Resolve the overlay territory code into ww territory code
 * Use the Sales Group 4 + SE Org Role to standardize GTM_Role for SE Org.
 */


  DROP Table SalesOps_DM.dbo.Coverage_assignment_byName_FY22_ANA
  Select a.*
		, T.Hierarchy, T.Theater, T.Area, T.Region, T.District, T.Territory, T.[Level], T.[Type], T.Segment
  into SalesOps_DM.dbo.Coverage_assignment_byName_FY22_ANA
			 from 
			 (
					Select Emp_C.[Employee ID] [EmployeeID]
						   , Q.[Workday Employees E1] [Name], Q.[Email - Primary Work] [Email], Q.[Job Title] [Title], Q.[Hire Date]
						   , Q.[Plan Name]
						   , substring(Q.[Plan Name], CHARINDEX('(',Q.[Plan Name])+1, CHARINDEX(')', Q.[Plan Name]+')')-CHARINDEX('(', Q.[Plan Name]) -1) [Plan_Code]
						   , Q.[Measure 1 Coverage Assignment ID] [Territory_IDs] --, Q.[Measure 1 Coverage Crediting Instructions] [Credit Instructions]
						   , Q.[Manager], Q.[Manager ID]
						   , Emp_C.[Node] [Territory_ID]
						   , case when Emp_C.Ana_Node_Type is null and len(Emp_C.Node) = 10  then 'Area' else Emp_C.Ana_Node_Type end [Coverage Level]
						   , Emp_C.[Ana_Node_Id], Emp_C.[Ana_Node], Emp_C.Ana_Node_Type
						   , Q.[Sales Group 4]
						   , SE.Role [SEOrg_Role], SE.Level [SEOrg_Level], SE.IC_MGR, Q.[SFDC User Id] [SFDC_UserID]
			 			   , Case
								when [Sales Group 4] in ('Sales Mgmt','Sales Mgmt QBH','RSD','DM','ISR Mgmt','SDR Mgmt') then 'Sales Mgmt'
								when [Sales Group 4] in ('Global AE', 'GSI AE', 'ISO ISR', 'ISO SDR') then 'Sales AE'
								when [Sales Group 4] in ('GSI SE') then 'SE'
								when SE.Role in ('ISE', 'GSI','MSP') then 'SE' --SEs assigned to 'special' territories
								when SE.Role is not null and SE.Level = 'Standard' then SE.Role
								when SE.Role = 'SE' and SE.Level = 'PRINCIPAL' then 'PTS'
								when SE.Role = 'SE' and SE.Level != 'Standard' then 'SE Mgmt'
								when SE.Role = 'FSA' and SE.Level != 'Standard' then 'FSA Mgmt'
								when SE.Role = 'DA' and SE.Level != 'Standard' then 'DA Mgmt'
								when [Sales Group 4] = 'FB SE' then 'DA'
								when [Sales Group 4] = 'Direct SE' then 'SE'
								when [Sales Group 4] in ('Solutions Specialist IC') then 'FSA'
								when [Sales Group 4] in ('Solutions Specialist Mgmt') then 'FSA Mgmt'
								when Emp_C.[Employee ID] = '103058' then 'Sales Mgmt' -- overwrite for Brian Carpenter
								else [Sales Group 4]
							end as GTM_Role
					from (
							SELECT 
								  C.[Employee ID]
								  , C.[Node_Id] [Ana_Node_Id], C.[Node] Ana_Node, C.[Node_Type] Ana_Node_Type
								  , coalesce(O.WW_Node, C.[Node]) as [Node]
							FROM [Anaplan_DM].[dbo].[Employee_Sales_User_Hierarchy_Flattern] C
							left join [Anaplan_DM].[dbo].[Overlay_Territory_Mapping] O on O.FB_Node = C.[Node]
							where C.IsActive = 1 and [Employee ID] != '104591'
			
							Union
							/* need a workaround for Zach Duncan as his coverages do not have the overlay-ww mapping */
							/* not using the VIEW as it is missing some SE employees */
							Select [Employee_Id],
								   [Node_Id] [Ana_Node_Id], [Node] [Ana_Node], [Node_Type] [Ana_Node_Type], [Node]
							from Anaplan_DM.dbo.VIEW_Employee_Node
							where Employee_Id = '104591'
						) Emp_C
						left join [Anaplan_DM].[dbo].[Employee_Territory_And_Quota] Q on Q.[Employee ID] = Emp_C.[Employee ID]
						left join [GPO_TSF_Dev ].[dbo].vSE_org SE on SE.EmployeeID = Emp_C.[Employee ID]
						where len(Q.[Termination Date]) = 0
			  ) a
			  left join [SalesOps_DM].dbo.TerritoryID_Master_FY22 T on T.Territory_ID = a.[Territory_ID]
