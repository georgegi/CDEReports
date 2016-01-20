; with xCTE as (
select 
	Question
	, QuestionSequence
	, AdminUnit 
	, Score = m.LikertScore 
	, Weight = m.ResponseWeight
	, m.WeightedScore 
	, CASE WHEN m.LikertScore > 3 THEN 1 ELSE 0 END Score45
-- declare @userID uniqueidentifier, @language varchar(10), @disabMatch varchar(10), @rosterYearID uniqueidentifier ; select @userID = ID, @language = 'All', @disabMatch = 'All' from UserProfile where UserName = 'Enrich:julielott' ; select @rosterYearID = (select ID from RosterYear where StartYear = 2014) ; select *
from x_DATATEAM.FamilySurveyMaster m
where 
	OrgUnitID in (select OrgUnitID from UserProfileOrgUnit where UserProfileID = @userID) AND
	(@language = 'All' or cast(Language as varchar(10)) = @language) AND
	(@disabMatch = 'All' or cast(DisabilityMatch as varchar(10)) = @disabMatch) AND
	m.RosterYearID = @rosterYearID
)

select Question
	, QuestionSequence
	, AdminUnit
	, Score = sum(Score)
	, AvgScore = avg(1. * Score)
	, AvgScore45 = avg(1. * Score45)
from xCTE
group by Question, QuestionSequence, AdminUnit
order by QuestionSequence, AdminUnit