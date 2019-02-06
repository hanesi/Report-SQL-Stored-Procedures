/***
This stored procedure counts the number of ratings for each Agency (based on 
specified criteria), pivots them, and adds rows for the percentages of each
rating type
***/
USE [Database Name]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[All_Avg]
	-- Add date parameters for the stored procedure here
	@POPStartDate datetime,
	@POPEndDate datetime

AS
BEGIN
SET NOCOUNT ON;

--initialize first variable table
declare @table table (Agency nvarchar(60), Average float, RatingWords nvarchar(60))
--insert values from AllAvgs table filtered with date parameters
insert into @table
	select AgencyGrp, Average, RatingWords from dbo.AllAvgs p
	where p.POPStartDate <= @POPEndDate and p.POPEndDate >= @POPStartDate and p.Average is not null
END

begin
--initialize second variable table with columns for each Agency
declare @table2 table (Rating nvarchar(60), Army int, Navy int, AirForce int, FEMA int, GSA int, VA int, Civilian int)
--insert sum of ratings for each agency, using 1 to create a "Total" row
insert into @table2
select case when grouping([Rating]) = 1 then 'Total' else [Rating] end as [Rating], 
Sum([Navy]) as Navy, 
sum([Army]) as Army, 
sum([Air Force]) as AirForce, 
sum([FEMA]) as FEMA, 
sum([GSA]) as GSA, 
sum([VA]) as VA, 
sum([Civilian]) as Civilian
from
--subquery here is to categorize the Average rating field based on the criteria below and assign them a 1 or a 0 to be used as a count
(select ratingwords as Rating, agency,
CASE WHEN Average BETWEEN 8.6 AND 10 THEN 1 else 0 end as Exceptional,
case WHEN Average BETWEEN 7.1 AND 8.5 THEN 1 else 0 end as VeryGood,
case WHEN Average BETWEEN 3.1 AND 7.0 THEN 1  else 0 end as Satisfactory,
case WHEN Average BETWEEN 0.1 AND 3.0 THEN 1 else 0 end as Marginal,
case WHEN Average = 0 THEN 1 ELSE 0 END as Unsatisfactory
from @table) as sourcetable
--pivot the resulting table so that the rating categories (Exceptional, VeryGood, etc) are in the first column and the Agency numbers are in each subsequent row
pivot
(
Count(exceptional)
for Agency in ([Navy], [Army], [Air Force],[FEMA],[GSA],[VA],[Civilian])
) as PivotTable
group by grouping sets ((Rating),())

--create separate tablee for percentages of each category (% Exceptional, % VeryGood, etc)
declare @army float, @navy float, @AirForce float, @FEMA float, @GSA float, @VA float, @Civilian float;
select @army = nullif([Army],0), @navy = nullif([Navy],0), @AirForce = nullif([AirForce],0), @FEMA = nullif([FEMA],0), @GSA = nullif([GSA],0), @VA = nullif([VA],0), @Civilian = nullif([Civilian],0) from @table2 where Rating = 'Total';

--combine the first table with the number of ratings and the percentages of each rating
Select * from @table2
union all
Select '% of '+Rating, Round(nullif((Army/@army)*100,0),2), Round(nullif((Navy/@navy)*100,0),2), Round(nullif((AirForce/@AirForce)*100,0),2), Round(nullif((FEMA/@FEMA)*100,0),2), Round(nullif((GSA/@GSA)*100,0),2), Round(nullif((VA/@VA)*100,0),2), Round(nullif((Civilian/@Civilian)*100,0),2) from @table2 
where Rating <> 'Total'

end
