


with
#SFDC_Deal as (
	Select Id
	from PureDW_SFDC_staging.dbo.Opportunity
	where CloseDate >= '2018-02-05'
)

/* Set of Opportuntiy with POC migration */
Select O.Id [Oppt_Id], O.Name [Opportunity], RecT.Name [Oppt RecordType] ,O.Transaction_Type__c [Transaction Type]
	 , Acc.Name [Account Name] , AE.Name [AE], SE.Name [SE]
	 , O.Theater__c Theater, O.Division__c Division, O.Sub_Division__c Sub_Division, O.Converted_Amount_USD__c [Amount in USD]
	 
	 , cast(O.CreatedDate as Date) CreatedDate
	 , cast(O.CloseDate as Date) CloseDate
	 , right(O.Close_Fiscal_Quarter__c, 4) + ' ' + left(O.Close_Fiscal_Quarter__c, 2) [Fiscal Close Quarter]
 	 , DateFromParts(cast(CloseDate_445.FiscalYear as int), cast(CloseDate_445.FiscalMonth as int), 1) [Fiscal Close Month]
	 , DateFromParts(cast(TodayDate_445.FiscalYear as int), cast(TodayDate_445.FiscalMonth as int), 1) [Current Fiscal Month]

	 , O.StageName [Stage]
	 , O.Serial_Numbers__c [POC Serial Number]

	 , case when O.Serial_Numbers__c is null then 'No' else 'Yes' end [POC SN Present]
	 , case when O.Serial_Numbers__c is not null then 
			len(cast(O.Serial_Numbers__c as varchar(5000))) - len(REPLACE(cast(O.Serial_Numbers__c as varchar(5000)), ',',''))+1
			else 0
	   end [POC SN Cnt]
	 , O.POC_System_Comments__c
	 , O.Eval_Stage__c [Old Eval Stage], O.POC_Ship_Date__c [Old POC Ship Date], O.POC_Ship_Age__c [Old POC Ship Age], O.POC_Completed__c [Old POC Completed Date]
	 
	 , case when cast(substring(O.StageName, 7, 1) as int) < 8 then 'Open'
	 		when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
			else 'Loss'
			end as StageGroup
	 , O.Sales_SFDC_Oppty_Link__c
	 , O.Secondary_POC_Status__c [ISR UseCase]
	 , O.Product_Use_Type__c [ISR UseType]

from PureDW_SFDC_Staging.dbo.Opportunity O
  left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
  left join PureDW_SFDC_Staging.dbo.Account Acc on Acc.Id = O.AccountId
  left join PureDW_SFDC_Staging.dbo.[User] AE on AE.Id = O.OwnerId
  left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
  left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, CloseDate, 112)
  left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
where O.Id in (select * from #SFDC_Deal)
;


with
#SFDC_Deal as (
		Select Id
		from PureDW_SFDC_staging.dbo.Opportunity
		where CloseDate >= '2018-02-05'
)

/* Look at status in SFDC */
/* Oppt with POC status fields,  */
select Oppt.Id [Oppt_Id]
	 --, Oppt.Name [Opportunity], Oppt.StageName [Stage], cast(Oppt.CloseDate as Date) CloseDate
	 --, OpptRecT.Name [Oppt RecT], Oppt.Transaction_Type__c [Transaction Type]
	 --, Oppt.Serial_Numbers__c [Oppt POC SN]
	 , POC.ID POC_Id, POC.Name POC_Name,  POC.Eval_Stage__c [Eval Stage]
	 , cast(POC.Ship_Date__c as Date) [POC ShipDate], POC.Current_Term__c [Eval Term]
	 , cast(POC.PoC_Expiration_Date__c as Date) [POC ExpiredDate], cast(POC.Completed_Date__c as Date) [POC CompletedDate]
     , POC.PoC_Ship_Age__c [POC ShipAge], POC.Disposition__c [POC Disposition], POC.Initial_Term__c, POC.Extension_Count__c
	 , POCRecT.Name [POC RecT], POCRecT.Id [POC RecT_Id]
	 , POC_Req.Id [POC_Req_Id], POC_Req.Name [POC_Req]
	 , EA.Name [Eval Agreement], POC_Req.Agreement__c, POC_Req.Agreement_term__c, POC_Req.Ship_Eval_Agreement_Status__c, POC_Req.Approval_Status__c
from PureDW_SFDC_staging.dbo.Opportunity Oppt
left join PureDW_SFDC_Staging.dbo.POC__c POC on POC.Opportunity__c = Oppt.Id
left join PureDW_SFDC_staging.dbo.RecordType OpptRecT on OpptRecT.Id = Oppt.RecordTypeId
left join PureDW_SFDC_staging.dbo.RecordType POCRecT on POCRecT.Id = POC.RecordTypeId
left join PureDW_SFDC_staging.dbo.Ship_Request__c POC_Req on POC_Req.Poc__c = POC.Id
left join PureDW_SFDC_staging.dbo.CEFS__Contract__c EA on EA.Id = POC_Req.Agreement__c
--where Oppt.Id in ('0064W00000vrh7JQAQ', '0064W00000vrh6zQAA','0064W00000vrh8zQAA','0064W00000vrh8lQAA','0064W00000vrh7LQAQ')
where Oppt.Id in (select * from #SFDC_Deal)
;
--where Oppt.Id in ('0064W00000vsQwOQAU', '0060z000022R1AQAA0')
-- Cat1: POC.Eval_Stage__c is null - OnSite POC is not used
-- Cat2: POC.Eval_Stage__c is not null - OnSite POC is used
         -- is requested, shipped, in progress, completed


/* Goal: if Ship_Req is on a NetSuite TO, the Ship_Request is shipped
         TO created prior to launch are not linked to Ship_Request
   NetSuite TO created after Nov 16th, they should either have the Ship_Req or Pickup_Req value
*/

/* Transafer Order value & status in SFDC */
Select Oppt_TO.Opportunity__c [Oppt_Id]
	 , Oppt_TO.Id [TO_Id], Oppt_TO.Name [Transfer Order]
	 , cast(Oppt_TO.Transaction_Date__c as Date) [TO Transaction Date], Oppt_TO.Status__c [TO Status], cast(Oppt_TO.Ship_Date__c as date) [TO ShipDate]
	 , Oppt_TO.To_Location__c, Oppt_TO.Tracking_Numbers__c
     , Ship_Req.Name [Ship Req], Oppt_TO.Ship_Request__c
	 , Pick_Req.Name [Pickup Req], Oppt_TO.Pickup_Request__c, Pick_Req.RMA_Number__c, Pick_Req.Tracking_Number__c [Pick Tracking], cast(Pick_Req.Delivery_POD_Date__c as Date) [Pickup POD]
	 , case 
		   when Ship_Req.Name is not null and Pick_Req.Name is null then 'Ship'
		   when Ship_Req.Name is null and Pick_Req.Name is not null then 'Pickup'
		   else 'Unknown'
		end [TO direction]
from PureDW_SFDC_Staging.dbo.NetSuite_Transfer_Order__c Oppt_TO
left join PureDW_SFDC_staging.dbo.Ship_Request__c Ship_Req on Ship_Req.Id = Oppt_TO.Ship_Request__c
left join PureDW_SFDC_staging.dbo.Pickup_Request__c Pick_Req on Pick_Req.Id = Oppt_TO.Pickup_Request__c
where To_Location__c != 'Pure Stage 7 Ship'
  and  Oppt_TO.Opportunity__c in (select * from #SFDC_Deal)
--  and Oppt_TO.CreatedDate >= '2019-02-01'
--  and Oppt_TO.Opportunity__c is not null
--  and Oppt_TO.Opportunity__c = '0060z0000249oiPAAQ'
--where Oppt_TO.CreatedDate >= '2020-11-16' and To_Location__c != 'Pure Stage 7 Ship'
--where Oppt_TO.Opportunity__c in ('0064W00000vsQwOQAU', '0060z000022R1AQAA0')
-- Cat1: Ship Request and Pickup Request are both null
-- Cat2: Outbound: Ship Request is not null and Pickup Request is null
-- Cat3: Inbound:  Ship Request is null and Pickup Request is not null
-- Impossible: where Ship_Req.Name is not null and Pick_Req.Name is not null


/* SN in the POC SN field on Nov 14 2020, would have an entry
   SN shipped after POC Modernization launch, have an entry */
select POC_Asset.CreatedDate, POC_Asset.Id [Ship_Asset_Id], POC_Asset.Name [Ship Asset]
	, POC_Asset.Serial_Number__c [Serial Number], POC_Asset.Product_Number__c [Product]
	, POC_Asset.Disposition__c [Asset Disposition], POC_Asset.Asset_Status__c [Asset Status]
	, POC_Asset.Opportunity__c [Oppt_Id]
	, Oppt.Name [Opportuntiy], Acct.Name [Account]
	, POC_Asset.Shipped_Transfer_Order__c, Ship_TO.Name [Ship TO#]
	, POC_Asset.Return_Transfer_Order__c, Return_TO.Name [Return TO#]
	, POC_Asset.Order__c, Ord.netsuite_conn__NetSuite_Order_Number__c [SO#]
	, cast(Ord.netsuite_conn__NetSuite_Order_Date__c as Date) [SO Date], Ord.netsuite_conn__NetSuite_Order_Status__c [SO Status]
from PureDW_SFDC_staging.dbo.Shipped_Asset__c POC_Asset
left join PureDW_SFDC_Staging.dbo.NetSuite_Transfer_Order__c Ship_TO on Ship_TO.Id = POC_Asset.Shipped_Transfer_Order__c
left join PureDW_SFDC_staging.dbo.NetSuite_Transfer_Order__c Return_TO on Return_TO.Id = POC_Asset.Return_Transfer_Order__c
left join PureDW_SFDC_Staging.dbo.[Order] Ord on Ord.Id = POC_Asset.Order__c
left join PureDW_SFDC_staging.dbo.[Opportunity] Oppt on Oppt.Id = POC_Asset.Opportunity__c
left join PureDW_SFDC_staging.dbo.[Account] Acct on Acct.Id = Oppt.AccountId
where POC_Asset.Opportunity__c is not null
 AND POC_Asset.Serial_Number__c = 'SHG0997414G48XQ'

where POC_Asset.Serial_Number__c in ('PBZFL20310063', 'PSUFJ20310030')
where POC_Asset.Opportunity__c in ('0060z00001xwnXBAAY', '0064W00000vrIaBQAU')



Select Id, Name, Serial_Numbers__c, len(cast(Serial_Numbers__c as varchar(5000))) - len(REPLACE(cast(Serial_Numbers__c as varchar(5000)), ',',''))+1
from PureDW_SFDC_Staging.dbo.Opportunity
where CloseDate >= '2020-12-01' and CloseDate < '2020-12-31'
 and Serial_Numbers__c is not null




 Select distinct(Eval_Stage__c)
 from PureDW_SFDC_staging.dbo.POC__c

 select distinct(Disposition__c)
 from PureDW_SFDC_Staging_Dev.dbo.POC__c