--Declare @Lookup_Oppt_Id as nvarchar(20)
--set @Lookup_Oppt_Id ='0060z000022KsrbAAC'-- '0060z000021rIfAAAU'
--;

With
/* Select a set of Opportunity that we would like to analyze on */
#SFDC_Deal as (
	Select Oppt.Id
	from PureDW_SFDC_Staging.dbo.Opportunity Oppt
	left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = Oppt.RecordTypeId
	where Oppt.CloseDate >= '2021-02-05' and Oppt.CloseDate <= '2021-02-15'
	--RecT.Name in ('Sales Opportunity')-- ('ES2 Opportunity')
	--and Oppt.CloseDate >= '2018-02-05'-- and Oppt.CloseDate <= '2020-05-31'	
	--where Oppt.Id = @Lookup_Oppt_Id
	),		

#Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID, F.Created_From_ID
		 , FL.Item_ID
		 , Inv.inventory_number 
		 , TrnsO.TranId [TO#], TrnsO.Status, TrnsO.Memo [TO Memo], TrnsO.SFDC_SHIPPICKUP_REQUEST_ID, TO_Loc.Name [Transfer Location]
		 , F.TranID [IF #], Loc.Name [Ship From], F.TranDate [IF Date]
		 /* calucate the Transfer Order direction based on SFDC reference, and the Transfer Location */
		 , case 
				when TrnsO.SFDC_SHIPPICKUP_REQUEST_ID like 'PUR-' then 'Return'
				when len(TrnsO.SFDC_SHIPPICKUP_REQUEST_ID) = 18 then 'Ship'
				else
					case 
					when TO_Loc.Name like ('%POC%') then 'Ship'
					when TO_Loc.Name in ('Sales & Marketing DOM Inv', 'Sales & Marketing EMEA Inv','Sales & Marketing APAC Inv', 'Sales & Marketing Cust Sat Inv','Sales & Marketing COD Inv') then 'Ship'
					when TO_Loc.Name like ('%Cokeva%') then 'Return'
					when TO_Loc.Name like ('%Flextron%') then 'Return'
					when TO_Loc.Name like ('%Foxconn%') then 'Return'
					when TO_Loc.Name like ('%FCZ%') then 'Return'
					else 'Ship'
					end 
			end [Type]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	left join NetSuite.dbo.STG_NetSuite_Locations TO_Loc on TO_Loc.Location_ID = TrnsO.Transfer_Location
	
	where F.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Account_ID = 123 --and FL.Location_ID in (1, 42)
	--and FL.Quantity_Received_In_Shipment is not null 
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#Item_Receipt as (
	select TrnsO.SFDC_SYNC_ID, R.Created_From_ID
		 , R.TranID [IR #], Loc.Name [Ship to], R.TranDate [IR Date]
		 , Inv.inventory_number
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines RL 
	left join NetSuite.dbo.STG_NetSuite_Transactions R on RL.Transaction_ID = R.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = RL.Transaction_ID and Inv.transaction_line = RL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = R.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = RL.Location_ID
	
	where R.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and R.Transaction_Type = 'Item Receipt' and RL.Account_ID = 123 --and RL.Location_ID != 1 and RL.Location_ID != 42
	--and RL.Quantity_Received_In_Shipment is not null 
    and TrnsO.Transaction_Type = 'Transfer Order'
	),

#NS_POC_TransferOrder_Ship as (
	select OIF.SFDC_SYNC_ID
		 --, 'Ship TO' as [Type]
		 , OIF.[Type]
		 , OIF.[Item_ID]
		 , OIF.inventory_number [Serial Number]
		 , OIF.[TO#] [TranID], OIF.Status, OIF.[TO Memo] [Memo], OIF.SFDC_SHIPPICKUP_REQUEST_ID
		 , OIF.[Transfer Location]
		 , OIF.[IF #] [IF#], OIF.[IF Date] [IF Date], OIF.[Ship From] [IF Location], OIR.[IR #] [IR#], OIR.[IR Date] [IR Date], OIR.[Ship to] [IR Location]
		 , case when OIF.Type = 'Ship'  then 1 else 0 end as [POC Shipped Qty]
		 , case when OIF.Type = 'Return' then 1 else 0 end as [POC Returned Qty]
		 , 0 as [POC Sold Qty]
	from #Item_Fulfill OIF 
	left join #Item_Receipt OIR on OIR.inventory_number = OIF.inventory_number and OIR.SFDC_SYNC_ID = OIF.SFDC_SYNC_ID and OIR.Created_From_ID = OIF.Created_From_ID
),

#SO_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID
		 , 'Sales Order' as [Type]
		 , FL.Item_ID
		 , Inv.inventory_number [Serial Number]
		 , TrnsO.TranId [TranID], TrnsO.Status, TrnsO.Memo [Memo], TrnsO.SFDC_SHIPPICKUP_REQUEST_ID
		 , TrnsO.Transfer_Location
		 , F.TranID [IF#], F.TranDate [IF Date], Loc.Name [IF Location], '' [IR#], '' as [IR Date], '' [IR Location]
		 , 0 as [POC Shipped Qty], 0 as [POC Returned Qty], 1 AS [POC Sold Qty]
		 --, case when TrnsO.Status = 'Billed' then  1 else 0 end as [POC Sold Qty]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	
	where F.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Quantity_Received_In_Shipment is not null 
	and TrnsO.Transaction_Type = 'Sales Order'
	),

#Prod_Attribute as (
	select Item_Id, Item_Name, Salesdescription [Item_Desc], PROD_FAMILY, PROD_CATEGORY, PROD_TYPE, PROD_LINE, PROD_MODEL, PROD_GENERATION,  PROD_CAPACITY_TB, Serialized_Item
	from NetSuite.dbo.STG_NetSuite_Items
	where SFDC_ITEM = 'F'
),

/* pull all transactions related based on SFDC Opportunity */
#NS_Transactions_Journal as (
	Select a.SFDC_SYNC_ID [Oppt_Id]
		  , Prod.*
		  , a.[Serial Number], a.[Type], a.Status, a.[TranID], a.[Memo], a.SFDC_SHIPPICKUP_REQUEST_ID
		  , a.[IF#], a.[IF Date], a.[IF Location]
		  , a.[IR#], a.[IR Date], a.[IR Location]
		  , a.[POC Shipped Qty], a.[POC Returned Qty], a.[POC Sold Qty]
	--	  , max(a.[IF Date]) over (partition by a.SFDC_SYNC_ID) [Earliest Ship Date]
	--	  , min(a.[IR Date]) over (partition by a.SFDC_SYNC_ID) [Latest Returned Date]
	from (
			Select * from 
				#NS_POC_TransferOrder_Ship
			Union
			Select * from 
				#SO_Item_Fulfill
	) a
	left join #Prod_Attribute Prod on Prod.Item_Id = a.Item_ID
	where a.[Serial Number] is not null
)
--where len(SFDC_SYNC_ID) = 18
--order by [Serial Number]

/* bring a journal */
Select * from #NS_Transactions_Journal


/* pivot the journal and calculate the Serial Number status */
select Oppt_Id, Item_Id, Item_Name, [Serial Number],
	   sum([POC Shipped Qty]) [POC Shipped Qty], sum([POC Returned Qty]) [POC Returned Qty], sum([POC Sold Qty]) [POC Sold Qty]
	   , case when sum([POC Sold Qty]) > 0 then 'Sold'
	   		  when sum([POC Returned Qty]) > 0 then 'Returned'
	   		  when sum([POC Shipped Qty]) > sum([POC Returned Qty]) then 'Shipped'
	   		  else 'Unknown'
	   	 end [Serial Number Status]
from #NS_Transactions_Journal
group by Oppt_Id, Item_Id, Item_Name, [Serial Number]



/**********************************/
/* Inventory Adjustment           */
/**********************************/
select 'Inventory Adjustment' as [Type]
	, IA.TranID, IA.TranDate, IA.Status, IA.Memo
	, IAL.Item_ID, Inv.inventory_number [Serial Number], IAL.Memo
	, IAL.Account_ID, Acc.Accountnumber, Acc.Account_Name	
	, IAL.Location_ID, Loc.Name [Location]
from NetSuite.dbo.STG_NetSuite_Transaction_Lines IAL
left join NetSuite.dbo.STG_NetSuite_Transactions IA on IA.Transaction_ID = IAL.Transaction_ID
left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = IAL.Transaction_ID and Inv.transaction_line = IAL.Transaction_Line_ID
left join NetSuite.dbo.STG_NetSuite_Accounts Acc on Acc.Account_ID = IAL.Account_ID
left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = IAL.Location_ID
where IA.Transaction_Type = 'Inventory Adjustment'
and (IA.Memo like '%TO[0-9]%' or IA.Memo like '%PUR-[0-9]')
and Inv.inventory_number is not null
and IA.Create_Date >= '2021-02-01'