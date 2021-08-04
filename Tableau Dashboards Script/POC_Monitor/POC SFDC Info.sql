/*****************************************/
/***                                   ***/
/***  Opportunity + POC header         ***/
/***  1 Oppt may have 0 or 1 POC__c    ***/ 
/***                                   ***/
/*****************************************/

with
#SFDC_Deal as (
	Select Id
	from PureDW_SFDC_staging.dbo.Opportunity
	where CloseDate >= '2021-02-01' -->= '2018-02-05'
)

/* Opportunity joined POC Header */
Select O.Id [Oppt_Id], O.Name [Opportunity], RecT.Name [Oppt RecordType] ,O.Transaction_Type__c [Transaction Type]
--	 , O.Product_Use_Type__c
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
	 
	 , case when cast(substring(O.StageName, 7, 1) as int) < 8 then 'Open'
	 		when O.StageName in ('Stage 8 - Closed/Won', 'Stage 8 - Credit') then 'Won'
			else 'Loss'
			end as StageGroup
	 , O.Sales_SFDC_Oppty_Link__c
	 	 
	 -- add the POC header
	 , POC.ID POC_Id, POC.Name POC_Name, POC.Customer_Site_POC__c [CustSite POC]
	 , POC.Eval_Stage__c [Eval Stage]
	 , cast(POC.Ship_Date__c as Date) [POC ShipDate]
	 , POC.PoC_Ship_Age__c [DB Ship Age]
	 , case when (POC.Ship_Date__c is not null and POC.Completed_Date__c is not null) then datediff(day, cast(POC.Ship_Date__c as Date), cast(POC.Completed_Date__c as Date))
	        when (POC.Ship_Date__c is not null and POC.Completed_Date__c is null) then datediff(day, cast(POC.Ship_Date__c as Date), getdate())
	        else null
	   end [POC ShipAge]
	 , cast(POC.PoC_Expiration_Date__c as Date) [POC ExpiredDate], cast(POC.Completed_Date__c as Date) [POC CompletedDate]
     , POC.Disposition__c [POC Disposition], POC.Initial_Term__c [Init Term], POC.Current_Term__c [Current Term],  POC.Extension_Count__c
	 , POCRecT.Name [POC RecT], POCRecT.Id [POC RecT_Id]

from PureDW_SFDC_Staging.dbo.Opportunity O
  left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = O.RecordTypeId
  left join PureDW_SFDC_Staging.dbo.Account Acc on Acc.Id = O.AccountId
  left join PureDW_SFDC_Staging.dbo.[User] AE on AE.Id = O.OwnerId
  left join PureDW_SFDC_Staging.dbo.[User] SE on SE.Id = O.SE_Opportunity_Owner__c
  left join PureDW_SFDC_Staging.dbo.POC__c POC on POC.Opportunity__c = O.Id
  left join PureDW_SFDC_staging.dbo.RecordType POCRecT on POCRecT.Id = POC.RecordTypeId

  left join NetSuite.dbo.DM_Date_445_With_Past CloseDate_445 on CloseDate_445.Date_ID = convert(varchar, CloseDate, 112)
  left join NetSuite.dbo.DM_Date_445_With_Past TodayDate_445 on TodayDate_445.Date_ID = convert(varchar, getDate(), 112)
where O.Id in (select * from #SFDC_Deal)
--  and RecT.Name = 'Internal System Request Opportunity'
;


/**********************************/
/***                            ***/
/***  POC Request + Contract    ***/
/***                            ***/
/**********************************/

with
#SFDC_Deal as (
		Select Id
		from PureDW_SFDC_staging.dbo.Opportunity
		where CloseDate >= '2021-02-05'
)

/* Look at status in SFDC */
/* Oppt with POC status fields,  */
select Oppt.Id [Oppt_Id]
	 --, Oppt.Name [Opportunity], Oppt.StageName [Stage], cast(Oppt.CloseDate as Date) CloseDate
	 --, OpptRecT.Name [Oppt RecT], Oppt.Transaction_Type__c [Transaction Type]
	 --, Oppt.Serial_Numbers__c [Oppt POC SN]
	 , POC.ID POC_Id, POC.Name POC_Name
	 , POC_Req.Id [POC_Req_Id], POC_Req.Name [POC_Req]
	 , EA.Name [Eval Agreement], POC_Req.Agreement__c [Agreement_Id], POC_Req.Agreement_term__c [Agreement Term]
	 , OpptRecT.Name [Oppt RecordType], OpptAcc.Name [Account], OpptAcc.[Type] [Account Type]
	 , Oppt.Transaction_Type__c, POC_Req.POC_Use_Case__c
	 , POC_Req.Ship_Eval_Agreement_Status__c [Eval Agreement Status]
	 , left(cast(POC_Req.Approval_Status__c as varchar),1)+lower(right(cast(POC_Req.Approval_Status__c as varchar), len(cast(POC_Req.Approval_Status__c as varchar))-1)) [Approval_Status__c]
	 --, POC_Req.ApprovalStatus__c
from PureDW_SFDC_staging.dbo.Opportunity Oppt
left join PureDW_SFDC_Staging.dbo.POC__c POC on POC.Opportunity__c = Oppt.Id
left join PureDW_SFDC_Staging.dbo.[Account] OpptAcc on OpptAcc.Id = Oppt.AccountId
left join PureDW_SFDC_staging.dbo.RecordType OpptRecT on OpptRecT.Id = Oppt.RecordTypeId
left join PureDW_SFDC_staging.dbo.RecordType POCRecT on POCRecT.Id = POC.RecordTypeId
left join PureDW_SFDC_staging.dbo.Ship_Request__c POC_Req on POC_Req.Poc__c = POC.Id
left join PureDW_SFDC_staging.dbo.CEFS__Contract__c EA on EA.Id = POC_Req.Agreement__c
where Oppt.Id in (select * from #SFDC_Deal)
--  and not (POC_Req.Ship_Eval_Agreement_Status__c is null and  POC_Req.Approval_Status__c is null and POC_Req.ApprovalStatus__c is null)
;

/**********************************/
/***                            ***/
/***  SFDC Pickup Request       ***/
/***                            ***/
/**********************************/
Select PUR.Name [PUR], PUR.Id [PUR_Id], PUR.Status__c, PUR.Cancel_Reason__c, PUR.Opportunity__c,
	cast(PUR.Pickup_Date__c as Date) [Actual Pickup Date], cast(PUR.Delivery_POD_Date__c as Date) [Delivery/POD Date], 
	PUR.Tracking_Number__c, PUR.Ship_Via__c,
	PUR.Returned_Serial_Numbers__c [Returing Serial Numbers],
	PUI.Alt_Netsuite_Order_Number__c [NS Transaction Ref ], PUI.Alt_Platform_PN__c [Product],
	PUI.Alt_Serial_Number__c [Pickup Serial Number]
from PureDW_SFDC_staging.dbo.Pickup_Item__c PUI
left join PureDW_SFDC_staging.dbo.Pickup_Request__c PUR on PUR.Id = PUI.Pickup_Request__c
where PUR.Name = 'PUR-08163'

/** Misc Receive PUR PUR-08163 */

/**********************************/
/***                            ***/
/***  SFDC Ship Assets          ***/
/***                            ***/
/**********************************/
with
#SFDC_Deal as (
	Select Id
	from PureDW_SFDC_staging.dbo.Opportunity
	where CloseDate >= '2021-02-01' -->= '2018-02-05'
)

/* SN in the POC SN field on Nov 14 2020, would have an entry
   SN shipped after POC Modernization launch, have an entry */
select POC_Asset.CreatedDate, POC_Asset.Id [Ship_Asset_Id], POC_Asset.Name [Ship Asset]
	, POC_Asset.Serial_Number__c [Serial Number], POC_Asset.Product_Number__c [Product]
	, POC_Asset.Disposition__c [Asset Disposition], POC_Asset.Asset_Status__c [Asset Status]
	, POC_Asset.Opportunity__c [Oppt_Id]
	, Oppt.Name [Opportuntiy], Acct.Name [Account]
	, POC_Asset.Shipped_Transfer_Order__c
	, case when POC_Asset.Shipped_Transfer_Order__c is null then '' else Ship_TO.Name end [Ship TO#]
	, case when POC_Asset.Shipped_Transfer_Order__c is null then '' else Ship_TO.Status__c end [Ship TO Status]
	, POC_Asset.Return_Transfer_Order__c
	, case when POC_Asset.Return_Transfer_Order__c is null then '' else Return_TO.Name end [Return TO#]
	, case when POC_Asset.Return_Transfer_Order__c is null then '' else Return_TO.Status__c end [Return TO Status]
	, POC_Asset.Order__c
	, case when POC_Asset.Order__c is null then '' else Ord.netsuite_conn__NetSuite_Order_Number__c end [SO#]
	, case when POC_Asset.Order__c is null then '' else Ord.netsuite_conn__NetSuite_Order_Status__c end [SO Status]
	, case when POC_Asset.Order__c is null then '' else cast(Ord.netsuite_conn__NetSuite_Order_Date__c as Date) end [SO Date]
from PureDW_SFDC_staging.dbo.Shipped_Asset__c POC_Asset
left join PureDW_SFDC_Staging.dbo.NetSuite_Transfer_Order__c Ship_TO on Ship_TO.Id = POC_Asset.Shipped_Transfer_Order__c
left join PureDW_SFDC_staging.dbo.NetSuite_Transfer_Order__c Return_TO on Return_TO.Id = POC_Asset.Return_Transfer_Order__c
left join PureDW_SFDC_Staging.dbo.[Order] Ord on Ord.Id = POC_Asset.Order__c
left join PureDW_SFDC_staging.dbo.[Opportunity] Oppt on Oppt.Id = POC_Asset.Opportunity__c
left join PureDW_SFDC_staging.dbo.[Account] Acct on Acct.Id = Oppt.AccountId
where POC_Asset.Opportunity__c in (select * from #SFDC_Deal)


---!! Opportunity may be null in Ship Asset table
 -- Error & Exceptions 
-- AND POC_Asset.Serial_Number__c = 'FP00902246' -- POC on Oppt A and Sold under Oppt B
-- 'PCHFJ20110063' - Clearly an error, same SN sold twice
/** a serial number could be used for multiple deals */
select * from (
	select POC_Asset.Product_Number__c, POC_Asset.Serial_Number__c, count(*) Cnt
	from PureDW_SFDC_staging.dbo.Shipped_Asset__c POC_Asset
	group by POC_Asset.Product_Number__c, POC_Asset.Serial_Number__c
) T
where T.Cnt =2 -->2



/*** Product Information ***/

SELECT distinct s.Name
			, s.Family --, s.MDM_PROD_FAMILY__c
			, s.MDM_PROD_MODEL__c [PROD_MODEL]
			, n.PROD_CATEGORY, s.CPQ_Product_Category__c
			, s.CPQ_Platform__c, s.CPQ_Support_Level__c, s.CPQ_Support_Tier__c
			, s.CPQ_Product_Filter__c "CPQ Prod Filter", s.SKU_Type__c --, s.MDM_SKU_Type__c
			, n.Capacity
			, n.Item_Name [Parent Item], n.PROD_TYPE [Parent Prod_Type]
			, c.Item_Name [Member Item], c.PROD_TYPE [Member Prod_Type] --, s.MDM_PROD_TYPE__c
			, g.quantity,
			(select Record_Type__c
		     from PureDW_SFDC_Staging.dbo.IB_Staging_Part_Attribute__c
		     where Name=c.Item_Name and Exclude_from_IB_Processing__c='false') "Record"--s.SBQQ__Component__c,s.Is_Hardware__c,

FROM PureDW_SFDC_Staging.dbo.Product2 s
    ,NetSuite.dbo.STG_NetSuite_Items n
    ,NetSuite.dbo.STG_NetSuite_Items c
    ,NetSuite.dbo.STG_NetSuite_Item_Group g
where n.Salesforece_ID is not null
and s.Name = n.Item_Name
--and s.name='FA-X50R3-FC-109TB-91/18-EMEZZ'--'SS-DFM-SHELF-add SH0 to SH1'
and s.isSupport__c='false'
and s.IsActive = 'True'
and g.Parent_ID = n.Item_ID
and g.Member_ID = c.Item_ID
--and s.Family = 'FlashArray' --and n.PROD_CATEGORY != 'Hardware'
--order by 1,3,7,8;
order by s.Name, s.SKU_Type__c, n.PROD_TYPE


select distinct(CPQ_Product_Category__c)
FROM PureDW_SFDC_Staging.dbo.Product2


Select Id, Name, Serial_Numbers__c, len(cast(Serial_Numbers__c as varchar(5000))) - len(REPLACE(cast(Serial_Numbers__c as varchar(5000)), ',',''))+1
from PureDW_SFDC_Staging.dbo.Opportunity
where CloseDate >= '2020-12-01' and CloseDate < '2020-12-31'
 and Serial_Numbers__c is not null

/***********************/
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




 Select distinct(Eval_Stage__c)
 from PureDW_SFDC_staging.dbo.POC__c

 select distinct(Disposition__c)
 from PureDW_SFDC_Staging_Dev.dbo.POC__c