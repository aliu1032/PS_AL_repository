select IDM.Territory_ID, IDM.[Hierarchy], IDM.Theater, IDM.Area, IDM.Region, IDM.District, IDM.Territory, IDM.Segment, IDM.[Type],
       A2T.[Account ID], A2T.[Accounts A1], A2T.[Current Assigned Resource]
from SalesOps_DM.dbo.TerritoryID_Master_FY22 IDM
left join Anaplan_DM.dbo.Account_to_Territory A2T on A2T.[Current Territory ID] = IDM.Territory_ID