;with x as (
	select 
		AdminUnit = case when grouping(AdminUnit) = 0 then AdminUnit else 'STATE' end -- set to STATE for group by rollup AdminUnit
		, Question = case when grouping(Question) = 0 then Question else 'Total' end 
		, LikertScore = avg(cast(LikertScore as float)) -- float for precise division
		, SortBit = grouping(AdminUnit) -- who needs a case statement??? !!!
	from x_DATATEAM.FamilySurveyMaster 
	where 
		OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID) AND
		(@language = 'All' or cast(Language as varchar(10)) = @language) AND
		(@disabMatch = 'All' or cast(DisabilityMatch as varchar(10)) = @disabMatch) 
	group by rollup (AdminUnit), Question -- Add 100 so we can sort alpha
)

select t.AdminUnit, TopQuestion = t.Question, TopLikert = t.LikertScore, BottomQuestion = t2.Question, BottomLikert = t2.LikertScore,  t.SortBit, t.Sequence
from (
	select x.AdminUnit, x.Question, LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit order by LikertScore desc)
	from x
) t
join  (
	select x.AdminUnit, x.Question, LikertScore = cast(round(cast(x.LikertScore as float), 2) as money), SortBit, Sequence = row_number() over (partition by AdminUnit order by LikertScore)
	from x
) t2 ON t.AdminUnit = t2.AdminUnit
where t.Sequence in (1,2,3) and t.Sequence = t2.Sequence
order by SortBit, AdminUnit, Sequence

