/* LevelJump program assignment to User */
select U.Name [Name], U.EmployeeNumber [EmployeeID], LRN_P.LRN__Name__c [Assigned Program]
	 , LRN_PE.LRN__Status__c[Program Status], LRN_PE.LRN__Percent_Complete__c [Program Percent Complete]
	 , cast(LRN_PE.LRN__Start_Date__c as Date) Start_Date, FY_Start.FiscalYear, FY_Start.FiscalQuarter
	 , case
			when FY_Start.FiscalYear = FY_Today.FiscalYear then
				 case when FY_Start.FiscalQuarter = FY_Today.FiscalQuarter then 'This fiscal quarter'
					  when FY_Start.FiscalQuarter < FY_Today.FiscalQuarter
						   then 'Last ' + cast((cast(FY_Today.FiscalQuarter as int) - cast(FY_Start.FiscalQuarter as int)) as varchar(2)) + ' fiscal quarter'
					  else 'Next ' + cast((cast(FY_Start.FiscalQuarter as int) - cast(FY_Today.FiscalQuarter as int)) as varchar(2)) + ' fiscal quarter'
				 end
			when FY_Start.FiscalYear < FY_Today.FiscalYear then
					  'Last ' + cast((cast(FY_Today.FiscalQuarter as int) - cast(FY_Start.FiscalQuarter as int)
						              + (cast(FY_Today.FiscalYear as int) - cast(FY_Start.FiscalYear as Int))*4)
							    as varchar(2)) 
					  + ' fiscal quarter'
			when FY_Start.FiscalYear > FY_Today.FiscalYear then
					  'Next ' + cast((cast(FY_Start.FiscalQuarter as int) - cast(FY_Today.FiscalQuarter as int)
						              + (cast(FY_Start.FiscalYear as int) - cast(FY_Today.FiscalYear as Int))*4)
							    as varchar(2)) 
					  + ' fiscal quarter'
	   end [Rel_Quarter]
	 , FY_today.FiscalYear [Current FY], FY_today.FiscalQuarter [Current_Qtr]
	 , cast(LRN_PE.LRN__Max_Target_Date__c as Date) Target_Date
	 , case when LRN__Completion_Date__c is null then '' else convert(varchar, LRN__Completion_Date__c, 107) end Complete_Date
	 , count(LRN_P.LRN__Name__c) over (partition by U.EmployeeNumber order by U.EmployeeNumber) [Assigned LvlJump Programs]
	 , count(LRN__Completion_Date__c) over (partition by U.EmployeeNumber order by U.EmployeeNumber) [Completed LvlJump Programs]
	 , avg(LRN_PE.LRN__Percent_Complete__c) over (partition by U.EmployeeNumber order by U.EmployeeNumber) [Avg Percent Complete]
from PureDW_SFDC_staging.dbo.LRN__Program_Enrollment__c LRN_PE
left join PureDW_SFDC_staging.dbo.LRN__Program__c LRN_P on LRN_P.Id = LRN_PE.LRN__Program__c
left join PureDW_SFDC_staging.dbo.[User] U on U.Id = LRN_PE.LRN__User__c
left join NetSuite.dbo.DM_Date_445_With_Past FY_Start on FY_Start.Date_ID = convert(varchar(10), LRN_PE.LRN__Start_Date__c, 112)
left join NetSuite.dbo.DM_Date_445_With_Past FY_Today on FY_Today.Date_ID = convert(varchar(10), getdate(), 112)