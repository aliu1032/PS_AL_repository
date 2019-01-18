select startDate, EndDate, FullyQualifiedLabel, [Type]
from [PureDW_SFDC_staging].[dbo].[Period]
where StartDate >= '2018-02-01' and EndDate <= '2020-01-31'
and [Type] = 'Quarter'
