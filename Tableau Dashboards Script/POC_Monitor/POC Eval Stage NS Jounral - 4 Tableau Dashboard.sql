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
	

/* Outbound transfer order and the corresponding item fulfillment + item receipt, created for Opportunity POC */
#Outbound_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID, F.Created_From_ID
		 , FL.Item_ID
		 , Inv.inventory_number 
		 , TrnsO.TranId [Ship TO#], TrnsO.Status, TrnsO.Memo [Ship TO Memo], TrnsO.SFDC_SHIPPICKUP_REQUEST_ID
		 , F.TranID [OIF #], Loc.Name [Ship From], F.TranDate [OIF Date]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	
	where F.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Account_ID = 123 and FL.Location_ID in (1, 42)
	--and FL.Quantity_Received_In_Shipment is not null 
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#Outbound_Item_Receipt as (
	select TrnsO.SFDC_SYNC_ID, R.Created_From_ID
		 , R.TranID [OIR #], Loc.Name [Ship to], R.TranDate [OIR Date]
		 , Inv.inventory_number
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines RL 
	left join NetSuite.dbo.STG_NetSuite_Transactions R on RL.Transaction_ID = R.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = RL.Transaction_ID and Inv.transaction_line = RL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = R.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = RL.Location_ID
	
	where R.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and R.Transaction_Type = 'Item Receipt' and RL.Account_ID = 123 and RL.Location_ID != 1 and RL.Location_ID != 42
	--and RL.Quantity_Received_In_Shipment is not null 
    and TrnsO.Transaction_Type = 'Transfer Order'
	),

#NS_POC_TransferOrder_Ship as (
	select OIF.SFDC_SYNC_ID
		 , 'Ship TO' as [Type]
		 , OIF.[Item_ID]
		 , OIF.inventory_number [Serial Number]
		 , OIF.[Ship TO#] [TranID], OIF.Status, OIF.[Ship TO Memo] [Memo], OIF.SFDC_SHIPPICKUP_REQUEST_ID
		 , OIF.[OIF #] [IF#], OIF.[OIF Date] [IF Date], OIF.[Ship From] [IF Location], OIR.[OIR #] [IR#], OIR.[OIR Date] [IR Date], OIR.[Ship to] [IR Location]
		 , case when OIF.Status = 'Received' then 1 else 0 end as [POC Shipped Qty], 0 as [POC Returned Qty], 0 as [POC Sold Qty]
	from #Outbound_Item_Fulfill OIF 
	left join #Outbound_Item_Receipt OIR on OIR.inventory_number = OIF.inventory_number and OIR.SFDC_SYNC_ID = OIF.SFDC_SYNC_ID and OIR.Created_From_ID = OIF.Created_From_ID
),	


#Inbound_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID, F.Created_From_ID
		 , FL.Item_ID
		 , Inv.inventory_number
		 , TrnsO.TranId [Return TO#], TrnsO.Status, TrnsO.Memo [Return TO Memo], TrnsO.SFDC_SHIPPICKUP_REQUEST_ID
		 , F.TranID [RIF #], Loc.Name [Return from], F.TranDate [RIF Date]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	
	where F.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Account_ID = 123 and FL.Location_ID != 1 and FL.Location_ID != 42
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#Inbound_Item_Receipt as (
	select TrnsO.SFDC_SYNC_ID, R.Created_From_ID
		 , R.TranID [RIR #], Loc.Name [Return to], R.TranDate [RIR Date]
		 , Inv.inventory_number
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines RL 
	left join NetSuite.dbo.STG_NetSuite_Transactions R on RL.Transaction_ID = R.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = RL.Transaction_ID and Inv.transaction_line = RL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = R.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = RL.Location_ID
	
	where R.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and R.Transaction_Type = 'Item Receipt' and RL.Account_ID = 123 --and RL.Location_ID in (1, 42)
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#NS_POC_TransferOrder_Return as (
	select RIF.SFDC_SYNC_ID
		 , 'Return TO' as [Type]
		 , RIF.Item_ID
		 , RIF.inventory_number [Serial Number]
		 , RIF.[Return TO#] [TranID], RIF.Status, RIF.[Return TO Memo] [Memo], RIF.SFDC_SHIPPICKUP_REQUEST_ID
		 , RIF.[RIF #] [IF#], RIF.[RIF Date] [IF Date], RIF.[Return from] [IF Location], RIR.[RIR #] [IR#], RIR.[RIR Date] [IR Date], RIR.[Return to] [IR Location]
		 , 0 as [POC Shipped Qty], case when RIF.Status = 'Received' then 1 else 0 end as [POC Returned Qty], 0 as [POC Sold Qty]
	from #Inbound_Item_Fulfill RIF 
	left join #Inbound_Item_Receipt RIR on RIR.inventory_number = RIF.inventory_number and RIR.SFDC_SYNC_ID = RIF.SFDC_SYNC_ID and RIR.Created_From_ID = RIF.Created_From_ID
	where RIF.inventory_number is not null /*Can only reconcile ship and return of serialized parts */
),

#SO_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID
		 , 'Sales Order' as [Type]
		 , FL.Item_ID
		 , Inv.inventory_number [Serial Number]
		 , TrnsO.TranId [TranID], TrnsO.Status, TrnsO.Memo [Memo], TrnsO.SFDC_SHIPPICKUP_REQUEST_ID
		 , F.TranID [IF#], F.TranDate [IF Date], Loc.Name [IF Location], '' [IR#], '' as [IR Date], '' [IR Location]
		 , 0 as [POC Shipped Qty], 0 as [POC Returned Qty], case when TrnsO.Status = 'Billed' then  1 else 0 end as [POC Sold Qty]
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
				#NS_POC_TransferOrder_Return 
			Union
			Select * from 
				#SO_Item_Fulfill
	) a
	left join #Prod_Attribute Prod on Prod.Item_Id = a.Item_ID
	where a.[Serial Number] is not null
)
--where len(SFDC_SYNC_ID) = 18
--order by [Serial Number]
Select * from #NS_Transactions_Journal

/*
select Oppt_Id, Item_Id, Item_Name, [Serial Number],
	   sum([POC Shipped Qty]) [POC Shipped Qty], sum([POC Returned Qty]) [POC Returned Qty], sum([POC Sold Qty]) [POC Sold Qty]
	   , case when sum([POC Sold Qty]) > 0 then 'Sold'
	   		  when sum([POC Returned Qty]) > 0 then 'Returned'
	   		  when sum([POC Shipped Qty]) > sum([POC Returned Qty]) then 'Shipped'
	   		  else 'Unknown'
	   	 end [Serial Number Status]
from #NS_Transactions_Journal
group by Oppt_Id, Item_Id, Item_Name, [Serial Number]
*/