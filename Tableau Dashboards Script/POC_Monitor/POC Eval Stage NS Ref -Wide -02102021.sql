

Declare @Lookup_Oppt_Id as nvarchar(20)
set @Lookup_Oppt_Id = '0060z000020EexfAAC'
;

with

/* Select a set of Opportunity that we would like to analyze on */
#SFDC_Deal as (
	Select Oppt.Id
	from PureDW_SFDC_Staging.dbo.Opportunity Oppt
	left join PureDW_SFDC_Staging.dbo.RecordType RecT on RecT.Id = Oppt.RecordTypeId
	--where RecT.Name in ('Sales Opportunity')-- ('ES2 Opportunity')
	--and Oppt.CloseDate >= '2020-05-01' and Oppt.CloseDate <= '2020-05-31'	
	where Oppt.Id = @Lookup_Oppt_Id
	),		

/* Outbound transfer order and the corresponding item fulfillment + item receipt, created for Opportunity POC */
#Outbound_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID, F.Created_From_ID
		 , Item.Item_Name, Item.Salesdescription [Item_Desc]
		 , Inv.inventory_number 
		 , TrnsO.TranId [Ship TO#], TrnsO.Memo [Ship TO Memo]
		 , F.TranID [OIF #], Loc.Name [Ship From], cast(F.TranDate as Date) [OIF Date]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	left join NetSuite.dbo.STG_NetSuite_Items Item on Item.Item_ID = FL.Item_ID
	
	where F.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Account_ID = 123 and FL.Location_ID in (1, 42)
	--and FL.Quantity_Received_In_Shipment is not null 
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#Outbound_Item_Receipt as (
	select TrnsO.SFDC_SYNC_ID, R.Created_From_ID
		 , R.TranID [OIR #], Loc.Name [Ship to]
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
	
#Inbound_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID, F.Created_From_ID
		 , TrnsO.TranId [Return TO#], TrnsO.Memo [Return TO Memo]
		 , F.TranID [RIF #], Loc.Name [Return from], cast(F.TranDate as Date) [RIF Date]
		 , Inv.inventory_number
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
		 , R.TranID [RIR #], Loc.Name [Return to] 
		 , Inv.inventory_number
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines RL 
	left join NetSuite.dbo.STG_NetSuite_Transactions R on RL.Transaction_ID = R.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = RL.Transaction_ID and Inv.transaction_line = RL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = R.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = RL.Location_ID
	
	where R.SFDC_SYNC_ID in (select * from #SFDC_Deal)
	and R.Transaction_Type = 'Item Receipt' and RL.Account_ID = 123 and RL.Location_ID in (1, 42)
	and TrnsO.Transaction_Type = 'Transfer Order'
	),

#NS_POC_TransferOrder_Return as (
	select RIF.SFDC_SYNC_ID
		 , RIF.inventory_number [Returned SN]
		 , RIF.[Return TO Memo]
		 , RIF.[Return TO#], RIF.[RIF #], RIF.[RIF Date], RIF.[Return from], RIR.[RIR #], RIR.[Return to]
	from #Inbound_Item_Fulfill RIF 
	left join #Inbound_Item_Receipt RIR on RIR.inventory_number = RIF.inventory_number and RIR.SFDC_SYNC_ID = RIF.SFDC_SYNC_ID and RIR.Created_From_ID = RIF.Created_From_ID
	where RIF.inventory_number is not null /*Can only reconcile ship and return of serialized parts */
),

#NS_POC_TransferOrder_Ship as (
	select OIF.SFDC_SYNC_ID
		 , OIF.[Item_Name], OIF.[Item_Desc], OIF.inventory_number [Ship SN]
		 , OIF.[Ship TO Memo]
		 , OIF.[Ship TO#], OIF.[OIF #], OIF.[OIF Date], OIF.[Ship From], OIR.[OIR #], OIR.[Ship to]
	from #Outbound_Item_Fulfill OIF 
	left join #Outbound_Item_Receipt OIR on OIR.inventory_number = OIF.inventory_number and OIR.SFDC_SYNC_ID = OIF.SFDC_SYNC_ID and OIR.Created_From_ID = OIF.Created_From_ID
),	

#NS_POC_Ship_and_Return as (
	select S.SFDC_SYNC_ID, S.Item_Name, S.Item_Desc
	     , S.[Ship SN], S.[Ship TO Memo], S.[Ship TO#], S.[OIF #], S.[OIF Date], S.[Ship From], S.[OIR #], S.[Ship to]
	     , R.[Returned SN], R.[Return TO Memo], R.[Return TO#], R.[RIF #], R.[RIF Date], R.[Return from], R.[RIR #], R.[Return to]
	from #NS_POC_TransferOrder_Ship S
	left join #NS_POC_TransferOrder_Return R on R.SFDC_SYNC_ID = S.SFDC_SYNC_ID and R.[Returned SN] = S.[Ship SN]
),

#SO_Item_Fulfill as (
	select TrnsO.SFDC_SYNC_ID
		 , Item.Item_Name, Item.Salesdescription [Item_Desc]
		 , Inv.inventory_number [Sold SN]
		 , TrnsO.TranId [SO #], TrnsO.Memo [SO Memo]
		 , F.TranID [IF #], cast(F.TranDate as date) [SO Date], Loc.Name [SO Ship From]
	from NetSuite.dbo.STG_NetSuite_Transaction_Lines FL 
	left join NetSuite.dbo.STG_NetSuite_Transactions F on FL.Transaction_ID = F.Transaction_ID
	left join NetSuite.dbo.STG_NetSuite_Transaction_Inventory_Number Inv on Inv.transaction_id = FL.Transaction_ID and Inv.transaction_line = FL.Transaction_Line_ID
	left join NetSuite.dbo.STG_NetSuite_Transactions TrnsO on TrnsO.Transaction_ID = F.Created_From_ID
	left join NetSuite.dbo.STG_NetSuite_Locations Loc on Loc.Location_ID = FL.Location_ID
	left join NetSuite.dbo.STG_NetSuite_Items Item on Item.Item_ID = FL.Item_ID
	
	where F.SFDC_SYNC_ID in ('0060z000023E2fCAAS') --(select * from #SFDC_Deal)
	and F.Transaction_Type = 'Item Fulfillment' and FL.Quantity_Received_In_Shipment is not null 
	and TrnsO.Transaction_Type = 'Sales Order'
	),
	

#Prod_Attribute as (
	select Item_Name, PROD_FAMILY, PROD_CATEGORY, PROD_TYPE, PROD_LINE, PROD_MODEL, PROD_GENERATION,  PROD_CAPACITY_TB, Serialized_Item
	from NetSuite.dbo.STG_NetSuite_Items
	where SFDC_ITEM = 'F'
),

#POC_Status as (
	select ID POC_Id, Name POC_Name, Opportunity__c, Eval_Stage__c, Initial_Term__c, Current_Term__c
		 , Ship_Date__c, PoC_Ship_Age__c, Disposition__c, Extension_Count__c
	 from PureDW_SFDC_Staging.dbo.POC__c
)
	

Select O.Id [Oppt_Id]

	 , NS_TO.SFDC_SYNC_ID, NS_TO.Item_Name, NS_TO.Item_Desc, Prod.PROD_FAMILY, Prod.PROD_CATEGORY, Prod.PROD_TYPE, Prod.PROD_MODEL, Prod.PROD_GENERATION,  Prod.PROD_CAPACITY_TB, Prod.Serialized_Item
	 , NS_TO.[Ship SN], NS_TO.[Ship TO Memo]
	 , NS_TO.[Ship TO#], NS_TO.[OIF #], NS_TO.[OIF Date], NS_TO.[Ship From], NS_TO.[OIR #], NS_TO.[Ship to]
	 , NS_TO.[Returned SN], NS_TO.[Return TO Memo]
	 , NS_TO.[Return TO#], NS_TO.[RIF #], NS_TO.[RIF Date], NS_TO.[Return from], NS_TO.[RIR #], NS_TO.[Return to]
	 , SO.[Sold SN], SO.[SO Memo]
	 , SO.[SO #], SO.[IF #], SO.[SO Date], SO.[SO Ship From]
  from PureDW_SFDC_Staging.dbo.Opportunity O
  left join #NS_POC_Ship_and_Return NS_TO on NS_TO.SFDC_SYNC_ID = O.Id
  left join #Prod_Attribute Prod on Prod.Item_Name = NS_TO.Item_Name
  left join #SO_Item_Fulfill SO on SO.SFDC_SYNC_ID = O.Id  /* will connected if the SN is converted to Sales Order */ --SO.inventory_number = NS_TO.[Ship SN] and 
  where O.Id in (Select * from #SFDC_Deal)
